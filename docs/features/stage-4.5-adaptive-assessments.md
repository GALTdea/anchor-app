# Stage 4.5 — Onboarding Assessment UX + Second Brain Foundation

> Full brief. Builds on Stage 4 by improving the onboarding assessment experience
> for MVP, then adds the first persistent AI-facing profile layer on top of
> submitted assessment data. Adaptive assessment behavior is explicitly deferred to
> post-MVP.

---

## Goal

Upgrade the initial child onboarding assessment from a basic static questionnaire
flow into a more modern and intuitive MVP experience, while adding the living,
evidence-backed child profile foundation behind it.

## User value

After this stage, a parent can complete a more modern and intuitive onboarding
assessment, while the app turns the submitted
answers into a continuously updated profile of the child and evidence-backed
recommendations. The onboarding flow becomes the first high-signal input into the
child's long-term "second brain."

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action calls `authorize` (Pundit)
- [ ] Use `policy_scope` for index queries where records can span a space
- [ ] Keep controllers thin — onboarding flow logic, extraction, profiling, and
      recommendation generation live in services/jobs
- [ ] Use Tailwind CSS 4 + daisyUI 5 for all new and rebuilt views
- [ ] Use `form_with` for forms
- [ ] Follow `docs/CONVENTIONS.md` daisyUI 5 fieldset/label/input patterns when
      rebuilding the assessment runner; do not reuse daisyUI 4-era form markup
- [ ] Use Active Job + Solid Queue for extraction/profile/recommendation work
- [ ] Existing assessments remain the immutable audit trail of submitted inputs
- [ ] Do not introduce a separate `Question` model in this stage; question and
      display metadata remain inside `AssessmentTemplate#schema`
- [ ] Do not overload `Observation` with AI-extracted facts; use a distinct model
- [ ] Adaptive / branching assessment logic is out of scope for MVP and should not
      block the second-brain foundation work
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean

## Reference implementation

- Model pattern: `app/models/assessment_template.rb`, `app/models/assessment.rb`,
  `app/models/assessment_response.rb`
- Controller pattern: `app/controllers/child_profiles/assessments_controller.rb`,
  `app/controllers/child_profiles/assessment_responses_controller.rb`
- View pattern: `app/views/child_profiles/assessment_responses/`,
  `app/views/spaces/child_profiles/`, plus `docs/CONVENTIONS.md` for daisyUI 5 form
  structure
- Policy pattern: `app/policies/assessment_policy.rb`,
  `app/policies/assessment_response_policy.rb`,
  `app/policies/child_profile_policy.rb`

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| `ProfileEvidence` | `profile_evidences` | `child_profile_id`, `source_type`, `source_id`, `dimension_key`, `concept_key`, `value`, `value_type`, `confidence`, `respondent_kind`, `recorded_at`, `metadata` (jsonb), `inferred` | `ChildProfile`; polymorphic source (`AssessmentResponse` initially) |
| `CurrentProfile` | `current_profiles` | `child_profile_id`, `summary` (jsonb), `narrative`, `generated_at`, `profile_version` | `ChildProfile` |
| `ProfileSnapshot` | `profile_snapshots` | `child_profile_id`, `summary` (jsonb), `narrative`, `generated_at`, `trigger_source_type`, `trigger_source_id` | `ChildProfile`; optional polymorphic trigger source |
| `Recommendation` | `recommendations` | `child_profile_id`, `status`, `category`, `title`, `body`, `rationale` (jsonb), `generated_at`, `source_profile_snapshot_id` | `ChildProfile`, `ProfileSnapshot` |

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `AssessmentTemplate` | Expand `schema` contract with onboarding UI metadata and AI-facing semantics (`dimension_key`, `concept_key`, `time_window`, `evidence_weight`, help/extraction hints, etc.); add explicit versioning fields such as `template_key` and `version`; treat published templates as immutable | Keep questions schema-driven, preserve historical meaning, and create new versions instead of editing published templates |
| `AssessmentResponse` | Add immutable template snapshot fields such as `template_slug_snapshot`, `template_version_snapshot`, `template_schema_snapshot`, plus async processing status fields such as `processing_status`, `last_processed_at`, and `last_processing_error` | Preserve historical meaning of old responses even if a newer template version is published later, while making the second-brain pipeline retryable and observable |
| `ChildProfile` | Add `has_one :current_profile`, `has_many :profile_evidences`, `has_many :profile_snapshots`, `has_many :recommendations` | Child profile becomes the anchor for the living second-brain layer |

### Seed data

- Replace the basic onboarding/dev snapshot seed with a richer published onboarding
  template that demonstrates:
  - semantic dimension tags
  - evidence-weight metadata
  - free-text extraction hints
  - a mix of deterministic and free-text extraction paths
  - improved onboarding copy and section structure suitable for a friendlier MVP UX
- Seed data should demonstrate the versioning policy:
  published templates are append-only; template changes create a new version rather
  than mutating an existing published record

## Routes and controllers

```ruby
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles" do
    resources :assessments, controller: "child_profiles/assessments" do
      resource :response, only: %i[show edit update],
        controller: "child_profiles/assessment_responses",
        as: :assessment_response
    end

    resource :current_profile, only: %i[show],
      controller: "child_profiles/current_profiles"

    resources :recommendations, only: %i[index show],
      controller: "child_profiles/recommendations"
  end
end
```

| Controller | Actions | Notes |
|-----------|---------|-------|
| `ChildProfiles::AssessmentsController` | `index`, `new`, `create`, `show`, `destroy` | Reuse existing structure; `new` and `create` focus on starting the onboarding template cleanly |
| `ChildProfiles::AssessmentResponsesController` | `show`, `edit`, `update` | `edit` becomes a more polished onboarding flow; `update` saves draft progress and final submit |
| `ChildProfiles::CurrentProfilesController` | `show` | Read-only living profile view for the child |
| `ChildProfiles::RecommendationsController` | `index`, `show` | Read-only generated recommendations with rationale/evidence links |

### Service / job layer

- `AssessmentTemplateSnapshotter` or equivalent model/service logic — captures the
  exact template definition used at submission time
- `AssessmentEvidenceExtractorJob` — translates a submitted response into
  `ProfileEvidence`
- `CurrentProfileRebuilderJob` — recomputes `CurrentProfile` from accumulated
  evidence
- `ProfileSnapshotBuilderJob` — saves a snapshot when the profile materially changes
- `RecommendationGeneratorJob` — creates or refreshes recommendations from the
  latest profile

### Processing contract

- Assessment submission is the synchronous success boundary
- Evidence extraction, profile rebuild, snapshot generation, and recommendation
  generation run asynchronously after submit
- Async jobs must be idempotent and retryable
- Processing failures do not invalidate the submitted `AssessmentResponse`
- Per-response processing status/error fields should make pipeline state visible for
  operations and future UI messaging

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|--------------|
| `AssessmentPolicy` | existing actions | Keep Stage 4 rules (`read_assessment`, `create_assessment`, `delete_assessment`) |
| `AssessmentResponsePolicy` | existing actions | Keep Stage 4 rules; submitted assessments remain read-only for normal users |
| `CurrentProfilePolicy` | `show?` | For MVP, `read_child_profile?` in the child's space, or admin |
| `RecommendationPolicy` | `index?`, `show?` | For MVP, `read_child_profile?` in the child's space, or admin |

**Note:** AI-generated profile and recommendation artifacts are child-level data, so
their read policy should align with child-profile access rather than assessment-create
permissions. A dedicated permission for second-brain artifacts can be added in a
later access-control stage if collaborator visibility needs to diverge.

## UI

- **Layout:** dashboard
- **Turbo:** optional frames for progressive sections; full-page fallback OK
- **New views:**
  - `child_profiles/current_profiles/show`
  - `child_profiles/recommendations/index`
  - `child_profiles/recommendations/show`
- **Changed views:**
  - `child_profiles/assessment_responses/edit` — rebuild as a more modern and supportive onboarding flow
  - `child_profiles/assessment_responses/show` — surface snapshot metadata and evidence summary
  - `child_profiles/assessments/show` — link to current profile/recommendations after submit
  - `spaces/child_profiles/show` — add second-brain entry points

### MVP onboarding UX goals

- Smaller, progressive question groups instead of one long form
- Supportive help text and examples where useful
- Clear progress indicator
- Save draft and resume without losing place
- Friendly empty/error states that do not feel clinical or overwhelming
- Onboarding-specific framing that helps parents feel they are building a portrait
  of their child, not filling out a cold intake form

### Post-MVP UX deferral

- Conditional branching / adaptive follow-up questions
- Persisted runner-state specific to adaptive logic
- Dynamic question visibility driven by prior answers
- Conversational or AI-led assessment delivery

## Recommended architecture

```text
Child onboarding / assessment response submitted
-> raw response stored as immutable audit trail
-> template schema/version snapshotted
-> extractor job runs
-> normalized evidence records created
-> current child profile recomputed
-> profile snapshot saved
-> recommendations and next-step prompts generated
```

### Architecture notes

- `AssessmentResponse.answers` remains the exact caregiver-entered record
- `AssessmentTemplate` should be versioned and treated as immutable once published;
  changes produce a new template version rather than editing a live published record
- `ProfileEvidence` is the normalized AI-facing layer; do not reuse `Observation`
  for this purpose
- `CurrentProfile` is the latest synthesized child portrait
- `ProfileSnapshot` preserves how the profile changed over time
- `Recommendation` stores actionable output as first-class data
- Assessment submission succeeds even if downstream second-brain processing fails;
  async processing state is tracked separately on the submitted response
- When Stage 3 observations ship, they should feed the same `ProfileEvidence`
  pipeline so the profile becomes cumulative across onboarding + daily life

## Rollout phases

1. **AI-ready onboarding assessments**
   Add richer schema semantics and response snapshotting while keeping the current
   assessment model intact.

2. **Improved onboarding runner**
   Rebuild the assessment experience into a more modern, progressive MVP flow
   without adaptive branching logic.

3. **Evidence layer**
   Add `ProfileEvidence` and extraction from submitted onboarding assessments.

4. **Living profile**
   Add `CurrentProfile` and `ProfileSnapshot`, then surface the evolving child
   portrait in the UI.

5. **Recommendations loop**
   Add recommendation generation, storage, and next-step prompts; later stages can
   add caregiver feedback/outcomes.

## Acceptance criteria

- [ ] A published onboarding assessment template can express the display metadata
      needed for MVP sectioning/help text without introducing a separate `Question`
      model
- [ ] A published onboarding assessment template can express AI-facing semantics
      such as `dimension_key`, `concept_key`, `time_window`, `units`, `polarity`,
      `evidence_weight`, and optional free-text extraction hints
- [ ] Published assessment templates are versioned and treated as immutable; changing
      a live onboarding assessment creates a new template version rather than editing
      the published record in place
- [ ] Parents complete the onboarding flow in a progressive, more intuitive runner
      rather than a flat long-form screen
- [ ] The MVP onboarding runner does not require adaptive branching logic to deliver
      a more polished experience
- [ ] Submitted assessment responses store immutable template snapshot data needed
      for future interpretation
- [ ] Submitting an assessment enqueues evidence extraction and profile rebuild jobs
- [ ] If downstream second-brain processing fails, the submitted assessment remains
      valid and retryable without rewriting the original submission
- [ ] Deterministic answers produce normalized `ProfileEvidence` records tied back to
      the submitted response
- [ ] The app can render a read-only current child profile synthesized from evidence
- [ ] The app can render AI-generated recommendations tied to the current profile
- [ ] Existing `AssessmentResponse.answers` remains the audit trail and source-of-truth
      for what the caregiver actually entered
- [ ] `Observation` remains reserved for human-authored daily logs; extracted evidence
      uses a distinct model
- [ ] Policies correctly gate profile and recommendation views by the child's space
- [ ] Specs cover schema validation changes, extractor logic, profile generation, and
      request-level authorization

## Out of scope

- A reusable admin-managed question bank with first-class `Question` records
- Real-time conversational AI chat in the assessment runner
- Adaptive / branching assessments and dynamic follow-up logic
- Full observations integration; Stage 3/next stage can feed the same evidence layer later
- Recommendation feedback loops / outcome tracking beyond initial storage model
- External therapist/teacher portals
- Final scoring engines for standardized instruments

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Steps

### Step 1 — Expand assessment template schema contract

Document and validate richer schema fields for onboarding UX + extraction semantics.
Add explicit template versioning rules (`template_key` + `version`, immutable once
published). Update seeds to include one realistic onboarding template using the new
contract.

**Verify:** `bundle exec rspec spec/models/assessment_template_spec.rb`
**Revert:** revert template model/spec/seed changes

### Step 2 — Add immutable response snapshot fields

Add migration(s) and model logic so submitted responses preserve the template slug,
version, and schema used at submission time. Snapshots remain a safeguard even though
published templates are versioned and immutable.

**Verify:** `bundle exec rspec spec/models/assessment_response_spec.rb`
**Revert:** `bin/rails db:rollback`

### Step 3 — Rebuild the onboarding assessment runner for a better MVP UX

Refactor the response edit/update flow so the UI is more polished, progressive, and
supportive, with better sectioning, draft/resume ergonomics, and onboarding copy
that feels less clinical. Do not add adaptive branching in this stage.

**Verify:** `bundle exec rspec spec/requests/child_profiles/assessments_spec.rb`
**Revert:** revert controller/view changes

### Step 4 — Add `ProfileEvidence` and extraction pipeline

Create the evidence model plus extraction service/job that translates submitted
assessment data into normalized child evidence. Add async processing-state tracking
to submitted responses and ensure extraction/profile jobs are idempotent.

**Verify:** `bundle exec rspec spec/models/profile_evidence_spec.rb spec/jobs/assessment_evidence_extractor_job_spec.rb`
**Revert:** `bin/rails db:rollback`

### Step 5 — Add current profile + snapshots

Create `CurrentProfile` and `ProfileSnapshot`, then implement the rebuild/snapshot jobs.

**Verify:** `bundle exec rspec spec/models/current_profile_spec.rb spec/models/profile_snapshot_spec.rb`
**Revert:** `bin/rails db:rollback`

### Step 6 — Add recommendation generation and read-only surfaces

Create `Recommendation`, wire generation jobs, policies, controllers, and views for
displaying the living profile and recommendations under a child profile using the
same MVP read gate as `ChildProfile`.

**Verify:** `bundle exec rspec spec/requests/child_profiles/current_profiles_spec.rb spec/requests/child_profiles/recommendations_spec.rb spec/policies/current_profile_policy_spec.rb spec/policies/recommendation_policy_spec.rb`
**Revert:** `bin/rails db:rollback`

### Step 7 — Document observation integration path

Update the docs to state clearly that future human-authored observations should feed
the same evidence pipeline.

**Verify:** read the brief and confirm the integration path is explicit
**Revert:** revert doc/status changes if needed

### Step 8 — Full verification and doc sync

Run full verification, then update this brief and `docs/ARCHITECTURE.md` if the
implemented domain model differs materially from current planning docs.

**Verify:** `bundle exec rspec`, `bundle exec rubocop`
**Revert:** revert doc/status changes if needed

---

## Status

- [x] Step 1 — Expand schema contract
- [x] Step 2 — Add response snapshots
- [ ] Step 3 — Rebuild onboarding runner
- [ ] Step 4 — Add evidence pipeline
- [ ] Step 5 — Add current profile + snapshots
- [ ] Step 6 — Add recommendations + surfaces
- [ ] Step 7 — Document observation integration path
- [ ] Step 8 — Full verification and doc sync

**Last updated:** 2026-04-04
**Handoff note:** Stage 4 remains the shipped assessment baseline. Stage 4.5 is now
under active implementation as the next evolution: a more polished onboarding
assessment UX plus the first second-brain foundation layer built on top of submitted
assessment data. Adaptive assessments remain deferred to a later stage. Step 1 is
complete with stronger `AssessmentTemplate` schema/versioning rules and richer seeded
templates. Step 2 is complete with immutable template snapshot fields and async
processing-state tracking added to `AssessmentResponse`, and the current draft/submit
assessment flow remains green under RSpec and RuboCop verification.
