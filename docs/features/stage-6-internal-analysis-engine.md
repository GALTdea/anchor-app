# Stage 6 - Internal Analysis Engine

> Full brief. Introduces Anchor's own rubric and deterministic analysis system.
> This stage deliberately does not call external AI. The goal is to make the app
> capable of producing evidence-backed, testable analysis before adding AI
> synthesis in a later stage.

---

## Goal

Create a testable, evidence-backed analysis engine that evaluates a child
profile using Anchor-owned rubrics and produces structured findings with scores,
confidence, summaries, and evidence references.

## User value

Parents receive clearer profile insights and next steps grounded in what Anchor
has actually collected. The app can explain what it noticed, what evidence
informed the analysis, how confident it is, and what may help next without
depending on opaque AI judgment.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action must call `authorize` through Pundit.
- [ ] Keep controllers thin; rubric evaluation and analysis generation belong in
      services/jobs.
- [ ] Use Active Job with Solid Queue for asynchronous analysis work.
- [ ] Existing submitted caregiver data remains the audit trail:
      `AssessmentResponse` and future `Observation` records are not rewritten by
      analysis.
- [ ] Preserve the existing second-brain pipeline:
      `ProfileEvidence` remains the normalized signal layer,
      `CurrentProfile` remains the latest child portrait,
      `ProfileSnapshot` remains a point-in-time profile record, and
      `Recommendation` remains the action layer.
- [ ] The deterministic analysis engine owns rubric scoring, confidence,
      thresholds, evidence mapping, and support/risk flags.
- [ ] Avoid diagnostic language. Outputs are support guidance and working
      hypotheses, not clinical determinations.
- [ ] Use Tailwind CSS 4 + daisyUI 5 for any new profile or audit views.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## Reference implementation

- Model pattern: `app/models/profile_evidence.rb`,
  `app/models/current_profile.rb`, `app/models/profile_snapshot.rb`,
  `app/models/recommendation.rb`
- Service pattern: `app/services/assessment_evidence_extractor.rb`,
  `app/services/current_profile_builder.rb`,
  `app/services/recommendation_builder.rb`,
  `app/services/child_profile_results_presenter.rb`
- Job pattern: `app/jobs/assessment_evidence_extractor_job.rb`,
  `app/jobs/current_profile_rebuilder_job.rb`,
  `app/jobs/profile_snapshot_builder_job.rb`,
  `app/jobs/recommendation_generator_job.rb`
- Controller pattern: `app/controllers/child_profiles/current_profiles_controller.rb`,
  `app/controllers/child_profiles/recommendations_controller.rb`,
  `app/controllers/spaces/child_profiles_controller.rb`
- View pattern: `app/views/spaces/child_profiles/show.html.erb`,
  `app/views/child_profiles/current_profiles/show.html.erb`,
  `app/views/child_profiles/recommendations/`
- Policy pattern: `app/policies/current_profile_policy.rb`,
  `app/policies/recommendation_policy.rb`, `app/policies/child_profile_policy.rb`

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| `AnalysisRubric` | `analysis_rubrics` | `name`, `rubric_key`, `version`, `status`, `description`, `schema` (jsonb), `published_at` | has many `AnalysisRuns` |
| `AnalysisRun` | `analysis_runs` | `child_profile_id`, `analysis_rubric_id`, `profile_snapshot_id`, `status`, `started_at`, `completed_at`, `error_message`, `input_digest`, `engine_version` | belongs to `ChildProfile`, `AnalysisRubric`, optional `ProfileSnapshot`; has many `AnalysisFindings` |
| `AnalysisFinding` | `analysis_findings` | `analysis_run_id`, `dimension_key`, `finding_key`, `score`, `confidence`, `severity`, `label`, `summary`, `evidence_refs` (jsonb), `metadata` (jsonb) | belongs to `AnalysisRun` |

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `ChildProfile` | Add `has_many :analysis_runs` | Child profile owns the longitudinal analysis history. |
| `ProfileSnapshot` | Optionally link latest analysis output through `AnalysisRun` rather than embedding all analysis details in snapshot summary | Keeps profile snapshots compact while preserving traceable analysis history. |
| `Recommendation` | Optionally reference `analysis_run_id` or include analysis finding refs in `rationale` | Recommendations should be grounded in deterministic findings, not only profile summary text. |
| `CurrentProfile` | May read from latest completed `AnalysisRun` when building richer summaries | Keeps current profile parent-readable while analysis details remain separately inspectable. |

### Seed data

Add a first published rubric for MVP profile interpretation. Seed data should be
versioned and append-only once published.

Initial rubric domains should align with existing assessment/profile dimensions:

- communication
- social connection
- flexibility
- sensory experience
- regulation
- daily life
- strengths and motivators
- family priorities

Each rubric domain should define:

- accepted `dimension_key` / `concept_key` inputs
- scoring rules or thresholds
- confidence rules
- evidence minimums
- parent-facing labels
- recommended support categories
- safety/non-diagnostic wording constraints

## Routes and controllers

Initial implementation should avoid parent-facing route sprawl. Analysis runs are
created by jobs after profile evidence changes and surfaced inside existing child
profile/current profile pages.

Optional read-only routes can be added if useful for review:

```ruby
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles" do
    resources :analysis_runs, only: %i[index show],
      controller: "child_profiles/analysis_runs"
  end
end
```

| Controller | Actions | Notes |
|-----------|---------|-------|
| `ChildProfiles::AnalysisRunsController` | `index`, `show` | Optional read-only audit/history surface for authorized users. Not required for MVP parent results if latest analysis is embedded in the profile presenter. |
| `Spaces::ChildProfilesController` | `show` | May display latest completed analysis findings through presenter methods. |
| `ChildProfiles::CurrentProfilesController` | `show` | May display analysis detail/deep-dive for the current profile. |

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|-------------|
| `AnalysisRunPolicy` | `index?`, `show?` | User can read child-level analysis if they can read the child profile in the child's space, or admin. |
| `ChildProfilePolicy` | `show?` | Existing child profile read access continues to govern embedded analysis display. |
| `CurrentProfilePolicy` | `show?` | Existing current profile read access continues to govern profile detail display. |

## UI

- **Layout:** dashboard for child/profile analysis surfaces.
- **Turbo:** optional. Full-page rendering is acceptable for the first pass.
- **New views:**
  - Optional `app/views/child_profiles/analysis_runs/index.html.erb`
  - Optional `app/views/child_profiles/analysis_runs/show.html.erb`
- **Changed views:**
  - `app/views/spaces/child_profiles/show.html.erb`
  - `app/views/child_profiles/current_profiles/show.html.erb`
  - Optional recommendation partials to show analysis grounding

### Parent-facing presentation

Parent-facing output should prioritize:

- what Anchor is noticing
- what evidence it is based on
- how confident the app is
- what may help next
- what to keep observing
- strengths before friction-heavy needs where possible

Prefer:

- "profile pattern"
- "support signal"
- "what may be happening"
- "what may help"
- "based on your answers and saved observations"
- "confidence"

Avoid:

- "diagnosis"
- "severity score"
- "autism score"
- "deficit"
- "clinically indicates"

## Service / job layer

- `Analysis::InputBuilder` - collects normalized evidence, current profile,
  profile snapshot, assessment provenance, and child metadata needed for analysis.
- `Analysis::RubricEvaluator` - deterministic evaluator that applies rubric rules
  to structured inputs and returns findings, scores, confidence, and evidence refs.
- `Analysis::RunCreator` - creates an `AnalysisRun`, persists findings, and marks
  status.
- `Analysis::CurrentProfileIntegrator` - updates or enriches `CurrentProfile`
  summary from completed analysis output if needed.
- `AnalysisRunJob` - starts deterministic analysis after profile evidence/profile
  snapshots change.

### Processing contract

```text
AssessmentResponse / Observation submitted
-> ProfileEvidence extracted
-> CurrentProfile rebuilt
-> ProfileSnapshot created when materially changed
-> AnalysisRun evaluates rubric against structured evidence
-> AnalysisFinding records deterministic findings
-> Current profile / recommendations display deterministic analysis output
```

Processing rules:

- The completed `AnalysisRun` is the success boundary for app-owned reasoning.
- Jobs must be idempotent and retryable.
- Re-running the same rubric version against the same input digest should not
  create duplicate completed runs unless explicitly requested.
- Analysis input and output should be stable enough for regression specs.
- The child profile remains usable even if analysis is queued or failed.

## Acceptance criteria

- [ ] A published `AnalysisRubric` can define versioned domains, dimensions,
      scoring rules, confidence rules, labels, and safety wording constraints.
- [ ] A child profile can produce an `AnalysisRun` from existing
      `ProfileEvidence`, `CurrentProfile`, and latest relevant `ProfileSnapshot`.
- [ ] The deterministic evaluator creates `AnalysisFinding` records with scores,
      confidence, severity, summaries, and evidence references.
- [ ] Analysis runs are idempotent for the same child, rubric version, and input
      digest.
- [ ] The profile page can display useful deterministic analysis output without
      any external AI dependency.
- [ ] Parent-facing analysis copy avoids diagnostic claims and makes uncertainty
      visible where confidence is low.
- [ ] Recommendations can be grounded in analysis findings, not only raw profile
      dimensions.
- [ ] Specs cover rubric validation, deterministic evaluation, idempotent jobs,
      and parent-facing presentation.

## Out of scope

- No external AI provider calls.
- No AI-generated copy.
- No AI-led diagnosis or clinical classification.
- No conversational AI chat.
- No autonomous AI changes to rubrics.
- No admin rubric management UI.
- No provider/therapist portal.
- No medication, treatment-plan, or crisis-management engine.
- No automatic external sharing of analysis results.
- No replacement of `ProfileEvidence`, `CurrentProfile`, `ProfileSnapshot`, or
  `Recommendation`.

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Decisions

- Anchor will build its own rubric and deterministic analysis engine.
- The deterministic analysis engine is the app-owned reasoning layer.
- External AI synthesis is deferred to Stage 7.
- Published rubric versions are append-only for auditability.
- Parent-facing language must remain support-oriented and non-diagnostic.
- Rubric authoring UI is deferred; the first rubric can be seed-driven.

## Steps

### Step 1 - Model the rubric and deterministic analysis records

Add `AnalysisRubric`, `AnalysisRun`, and `AnalysisFinding` with validations,
associations, statuses, and versioning rules. Add model specs and factories.

**Verify:** `bundle exec rspec spec/models/analysis_rubric_spec.rb spec/models/analysis_run_spec.rb spec/models/analysis_finding_spec.rb`
**Revert:** Roll back the migration and remove the models/specs/factories.

### Step 2 - Seed the first Anchor rubric

Create the first published rubric aligned to the existing child profile domains.
Keep the rubric schema explicit enough for deterministic evaluation and future
admin editing.

**Verify:** `bin/rails runner "puts AnalysisRubric.find_by!(rubric_key: 'anchor_child_profile_v1').version"`
**Revert:** Remove the seed entry or add a cleanup migration if already deployed.

### Step 3 - Build the deterministic evaluator

Implement `Analysis::InputBuilder`, `Analysis::RubricEvaluator`, and
`Analysis::RunCreator`. The evaluator should use rubric rules to create stable
findings with scores, confidence, labels, summaries, and evidence refs.

**Verify:** `bundle exec rspec spec/services/analysis/input_builder_spec.rb spec/services/analysis/rubric_evaluator_spec.rb spec/services/analysis/run_creator_spec.rb`
**Revert:** Remove the services and specs.

### Step 4 - Add the analysis job

Add `AnalysisRunJob` and trigger it after profile rebuild/snapshot creation at
the narrowest reliable point in the existing pipeline. Ensure idempotency through
rubric version and input digest.

**Verify:** `bundle exec rspec spec/jobs/analysis_run_job_spec.rb spec/jobs/profile_snapshot_builder_job_spec.rb`
**Revert:** Remove the job and trigger change.

### Step 5 - Surface deterministic findings in the profile experience

Update presenters and views so the child profile/current profile can show the
latest completed analysis findings with confidence and evidence grounding.

**Verify:** `bundle exec rspec spec/services/child_profile_results_presenter_spec.rb spec/requests/spaces/child_profiles_spec.rb`
**Revert:** Remove presenter/view changes.

### Step 6 - Ground recommendations in analysis findings

Update recommendation generation so recommendations can reference
`AnalysisFinding` records or finding refs in `rationale`, while preserving
existing recommendation behavior when no completed analysis exists.

**Verify:** `bundle exec rspec spec/services/recommendation_builder_spec.rb spec/jobs/recommendation_generator_job_spec.rb`
**Revert:** Remove recommendation grounding changes.

---

## Status

- [x] Step 1 — `AnalysisRubric`, `AnalysisRun`, `AnalysisFinding` models, migration, associations, idempotency index, model specs, factories
- [x] Step 2 — Published seed rubric `anchor_child_profile_v1` (`db/seeds/analysis_rubrics/anchor_child_profile_v1.rb`), loaded from `db/seeds.rb`, seed spec
- [x] Step 3 — `Analysis::InputBuilder` (canonical payload + SHA-256 digest), `Analysis::RubricEvaluator` (domain findings from evidence + rubric schema), `Analysis::RunCreator` (persist run + findings, idempotent completed), service specs
- [ ] Step 4
- [ ] Step 4
- [ ] Step 5
- [ ] Step 6

**Last updated:** 2026-04-27
**Handoff note:** Brief split from the original AI-assisted analysis proposal.
This stage builds only Anchor's deterministic rubric and analysis engine. No
external AI integration is included.
