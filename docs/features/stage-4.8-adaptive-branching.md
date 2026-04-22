# Stage 4.8 — Adaptive Assessment Branching (Conditional Visibility)

> Full brief. Builds on Stage 4.7 (Guided Assessment Runner) by adding
> declarative, deterministic conditional visibility to the assessment schema.
> Questions and sections can appear or hide based on prior answers, without
> introducing any LLM dependency or new persistent models.
>
> This is the first of the "Adaptive Assessment" stack. Future stages layer
> option-level follow-ups (4.9), salience-based section ordering (4.10), and
> LLM-assisted synthesis / runner planning on top of the mechanism established
> here.

---

## Goal

Let assessment templates declare when a question or section should be asked,
so the onboarding and authenticated assessment flows feel like a guided
conversation that adapts to the parent's answers instead of a static
questionnaire, while remaining fully deterministic and versionable.

## User value

A parent filling out the onboarding assessment only sees follow-up questions
that are relevant to what they just said. If they indicate "immediate
emotional collapse" on transitions, they get a recovery-time follow-up; if
they indicate "high flexibility," they skip deeper rigidity probes entirely.
The flow feels shorter, more attentive, and less clinical — without any
change in the meaning of submitted data.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action calls `authorize` (Pundit)
- [ ] Keep controllers thin; predicate evaluation, runner filtering, and
      validation of the active question set live in POROs/services
- [ ] Preserve the current schema-driven architecture centered on
      `AssessmentTemplate`, `Assessment`, `AssessmentResponse`, and
      `OnboardingSession`
- [ ] Do not introduce a separate `Question` model; `visible_if` metadata
      lives inside `AssessmentTemplate#schema`
- [ ] Preserve response-level provenance and template snapshotting on
      submitted responses; branching predicates are captured in the per-response
      template snapshot exactly like the rest of the schema
- [ ] Preserve both onboarding and authenticated assessment flows — branching
      must work identically in `OnboardingSession` drafts and authenticated
      `AssessmentResponse` drafts
- [ ] Preserve template immutability on published templates; `visible_if`
      becomes part of the immutable schema surface
- [ ] Use Tailwind CSS 4 + daisyUI 5 for any touched views; follow
      `docs/CONVENTIONS.md`
- [ ] Use `form_with` for forms
- [ ] Use Active Job + Solid Queue for any async work (none expected in this
      stage)
- [ ] Runner changes must remain server-rendered with Turbo Frames; no
      client-side predicate evaluation
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean

## Reference implementation

- Model pattern: `app/models/assessment_template.rb` (schema validation,
  `REQUIRED_QUESTION_FIELDS`, `OPTIONAL_STRING_QUESTION_FIELDS`,
  `validate_question`, `published_templates_are_immutable`)
- Validator pattern: `app/models/assessment_answer_validator.rb`
- Service pattern: `app/services/assessment_runner.rb` (steps, sections,
  step navigation)
- Extractor pattern: `app/services/assessment_evidence_extractor.rb`
- Controller pattern:
  `app/controllers/child_profiles/assessment_responses_controller.rb`,
  `app/controllers/onboarding/assessments_controller.rb`
- View pattern: `app/views/child_profiles/assessment_responses/edit.html.erb`,
  `app/views/child_profiles/assessment_responses/_question_field.html.erb`
- Seed pattern: `db/seeds/assessment_templates/anchor_initial_profile.rb`
- Admin editor pattern:
  `app/controllers/admin/assessment_templates_controller.rb`,
  `AssessmentTemplate#apply_schema_editor_attributes!`

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| None | — | — | — |

### New services / POROs

| Object | Location | Purpose |
|--------|----------|---------|
| `AssessmentSchema::PredicateEvaluator` | `app/services/assessment_schema/predicate_evaluator.rb` | Evaluate a `visible_if` predicate against a given answers hash. Returns `true`/`false`. Pure function, no state. |
| `AssessmentSchema::SchemaPredicate` | `app/services/assessment_schema/schema_predicate.rb` | Validate predicate shape and collect referenced question ids for cross-checking at template publish time. |

Namespace the new files under `app/services/assessment_schema/` and
`app/models/assessment_schema/` to start consolidating the family of
schema/runner helpers. We use `AssessmentSchema` rather than `Assessment`
because the latter is already an ActiveRecord model class; using a dedicated
namespace avoids re-opening the model and leaves room for future schema
utilities (e.g. a schema validator, a runner builder).

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `AssessmentTemplate` | Allow optional `visible_if` hash on both questions and sections in the schema. Validate its shape and that every referenced `question_id` exists in the same template. Include `visible_if` in the immutable schema surface for published templates. | Introduce branching as a first-class, versionable schema concept without adding a `Question` model. |
| `AssessmentAnswerValidator` | Accept an optional `active_question_ids:` argument. When provided, only validate questions whose id is in that set (required-when-hidden no longer fails). When not provided, preserve current behavior. | Let callers submit a branching-aware active set without breaking the default contract used by existing callers. |
| `AssessmentRunner` | Filter `questions` and `sections` by `visible_if` against the current answers. Derive stable step IDs from the first question id of each step group instead of positional indices. Expose `active_question_ids`. | Honor branching at display time, and avoid step-id drift when hidden questions shift positions. |
| `AssessmentEvidenceExtractor` | On submit, skip questions that are inactive for the final answer set (in addition to the existing "skip blank answers" rule). | Prevent stale evidence from being extracted for questions the parent branched away from before submit. |

### Changed services / controllers

| Object | Change | Reason |
|--------|--------|--------|
| `ChildProfiles::AssessmentResponsesController#update` | Compute `active_question_ids` from the runner and pass into the response's `submitting` validation path. | Make submit branching-aware without leaking logic into the controller. |
| `Onboarding::AssessmentsController#update` (and any step helpers it uses) | Same treatment for the onboarding draft submit path via `OnboardingSession#draft_answers_must_match_schema`. | Parity between onboarding and authenticated flows. |
| `OnboardingSession#draft_answers_must_match_schema` | Accept / compute an active-set and pass it to `AssessmentAnswerValidator`. | Same. |

### Seed data

- Extend `db/seeds/assessment_templates/anchor_initial_profile.rb` with 2–3
  follow-up questions gated on strong signals already in the template, to
  demonstrate and test branching end-to-end. Proposed additions:
  - `transition_recovery_time` (scale 1–5) — visible only when
    `stop_start_friction == "emotional_collapse"`
  - `rigidity_predictability_depth` (select) — visible only when
    `routine_predictability == "high_rigidity"`
  - `aac_exposure` (select) — visible only when `expression_of_needs` is in
    `["frustration_based", "hand_leading"]`
- Because `anchor_functional_profile_v1` is already published, the seed must
  create a **new template version** via `build_next_version_draft`-style
  logic and publish `v2`. Update the `onboarding_assessment_template_id`
  app setting to point at `v2`. `v1` stays untouched to protect historical
  `AssessmentResponse` records.

## Routes and controllers

No route changes. No new controllers.

Touched existing controllers:

| Controller | Actions | Notes |
|-----------|---------|-------|
| `ChildProfiles::AssessmentResponsesController` | `edit`, `update` | Pass `active_question_ids` from the runner into validation and extraction paths. Still authorize every action. |
| `Onboarding::AssessmentsController` | `show`, `update` | Same treatment against the onboarding draft path. |
| `Admin::AssessmentTemplatesController` | `update`, `publish` (or equivalent) | Accept a `visible_if` JSON field per question and per section; surface shape errors via existing model validations. |

## Authorization

No changes. Existing policies continue to apply:

| Policy | Actions | Rule summary |
|--------|---------|--------------|
| `AssessmentPolicy` | existing | Unchanged |
| `AssessmentResponsePolicy` | existing | Unchanged |
| `OnboardingSessionPolicy` | existing | Unchanged |
| `AssessmentTemplatePolicy` | existing | Unchanged |

## UI

- **Layout:** dashboard (authenticated flow), application (onboarding flow)
- **Turbo:** existing Turbo Frame (`assessment_runner_step`) reused
  unchanged; branching happens server-side on each step transition
- **New views:** none
- **Changed views:**
  - `app/views/child_profiles/assessment_responses/edit.html.erb` — no copy
    changes; the runner now resolves `@current_step`, `@next_step`, and
    `@previous_step` against the filtered step list, so the existing
    template renders the active set automatically.
  - `app/views/onboarding/assessments/show.html.erb` — same.
  - `app/views/admin/assessment_templates/_question_fields.html.erb` (or
    equivalent editor partial) — add a `visible_if` textarea field that
    accepts raw JSON for MVP. Section editor partial gets the same field.
    Human-friendly DSL is deferred.

## Predicate DSL (schema contract)

A `visible_if` value is a hash with exactly one of the following shapes:

```json
{ "question_id": "expression_of_needs", "equals": "frustration_based" }
{ "question_id": "expression_of_needs", "in": ["frustration_based", "hand_leading"] }
{ "question_id": "expression_of_needs", "answered": true }
{ "all": [ <predicate>, <predicate>, ... ] }
{ "any": [ <predicate>, <predicate>, ... ] }
{ "not": <predicate> }
```

Rules:

- `equals` compares by string after both sides are coerced to string.
- `in` accepts an array of strings; membership is string-compared.
- `answered: true` is satisfied when the referenced answer is non-blank
  (same rule the extractor already uses).
- `answered: false` is the negation.
- `all` and `any` take a non-empty array of predicates.
- `not` takes exactly one predicate.
- Referenced `question_id`s must exist in the same template. Validated at
  publish time; unknown ids make the template invalid.
- Predicates are AND-composed across question-level and section-level
  `visible_if`: a question is visible iff its section's `visible_if` (if
  any) is satisfied **and** its own `visible_if` (if any) is satisfied.
- No numeric comparisons (`gt`/`lt`) in this stage. If needed later, add
  them with the same allow-listed operator pattern. Out of scope now.

## Stable step IDs

Today `AssessmentRunner#build_question_step` produces ids like
`"section-#{section_id}-step-#{group_index + 1}"` (`app/services/assessment_runner.rb:118`).
Under branching, `group_index` shifts when earlier groups become hidden, so
a resume URL (`?step=section-X-step-2`) may land on the wrong step after a
predicate flips.

**Resolved design decision:** step ids are derived from the first question
id in each step group, prefixed with `q-`:

```ruby
"id" => "q-#{question_group.first['id']}"
```

This id is stable under insertion/hiding of other steps. `current_step`
should tolerate legacy ids gracefully: if a passed id does not resolve,
fall back to the existing default (first unanswered step), which is already
the behavior of `AssessmentRunner#current_step`.

## Orphaned answers on hidden branches

**Resolved design decision:** stored answers for currently-hidden questions
are **preserved** in `AssessmentResponse#answers` / `OnboardingSession#draft_answers`
but **ignored** on submit:

- The validator only requires questions in the active set.
- The evidence extractor only extracts evidence for questions in the active
  set.
- If the parent flips an earlier answer back so the branch becomes visible
  again, the previously-entered answer for the follow-up is restored
  automatically (no destructive behavior).

Rationale: non-destructive by default, avoids surprising parents who toggle
back and forth, and keeps draft persistence predictable. A later stage can
add explicit "clear stale branch" UX if needed.

## Acceptance criteria

- [ ] An `anchor_functional_profile_v2` template is seeded, published, and
      referenced by `AppSettings.onboarding_assessment_template_id`.
- [ ] `v1` remains untouched; existing `AssessmentResponse` records still
      validate and render.
- [ ] A parent completing onboarding who picks `emotional_collapse` sees the
      `transition_recovery_time` question; a parent who doesn't, doesn't.
- [ ] Same branching behavior in authenticated assessment drafts.
- [ ] Submitting a response in which a required-but-hidden question has no
      answer **succeeds** (the validator treats it as inactive).
- [ ] Submitting a response in which a required-and-visible question has no
      answer **fails** with the existing required-field error.
- [ ] After submit, `ProfileEvidence` is created for active questions only;
      no evidence is created for stale answers on hidden branches.
- [ ] Resume URLs using the new `q-<question_id>` step ids round-trip
      correctly across branch changes.
- [ ] `AssessmentTemplate` publish fails when a `visible_if` references an
      unknown `question_id`.
- [ ] `AssessmentTemplate` publish fails on unknown predicate operators.
- [ ] Admin editor accepts a JSON `visible_if` value per question and per
      section and surfaces model validation errors.
- [ ] `AssessmentAnswerValidator` continues to work with its existing
      two-argument API (backwards-compatible).
- [ ] RuboCop clean, full spec suite green.

## Out of scope

- Option-level `follow_up_question_ids` sugar (will compile down to
  `visible_if` in Stage 4.9).
- Acknowledgement strings / per-option copy.
- Section salience / screener-driven ordering (Stage 4.10).
- Numeric predicate operators (`gt`/`lt`), regex, range.
- LLM-generated questions, LLM-ordered runner, synthesis layer. Those are
  independent stages.
- Human-friendly DSL for authoring predicates; JSON is the MVP surface.
- UI indication of "this question was skipped" in read-only views; the
  snapshot is sufficient for MVP.
- Migration of historical `AssessmentResponse` rows tied to `v1`.

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Steps

### Step 0 — Pre-flight

Verify foundation is clean (per `docs/process/ai-dev-flow.md`):

```
bundle exec rspec
bundle exec rubocop
bin/rails db:migrate:status
git status
```

**Revert:** n/a

### Step 1 — `AssessmentSchema::PredicateEvaluator` PORO + spec

Implement the evaluator against a truth table of predicate shapes and a
given answers hash. Pure function, no AR access.

**Verify:** `bundle exec rspec spec/services/assessment_schema/predicate_evaluator_spec.rb`
**Revert:** `git checkout -- app/services/assessment spec/services/assessment`

### Step 2 — Schema validation: `visible_if` shape + reference check

Extend `AssessmentTemplate#validate_question` (and the section validator
introduced alongside it) to accept optional `visible_if` values, validate
their shape via the new `SchemaPredicate` helper, and verify every
referenced `question_id` exists in the same template at publish time.

Add `visible_if` to the immutable schema surface for published templates
via `IMMUTABLE_FIELDS` semantics (schema is already immutable in full; this
is a no-op for the outer list but confirm `published_templates_are_immutable`
still catches schema mutation tests that include `visible_if`).

**Verify:** `bundle exec rspec spec/models/assessment_template_spec.rb`
**Revert:** `git checkout -- app/models`

### Step 3 — `AssessmentAnswerValidator` active-set support

Add an optional `active_question_ids:` keyword to `#initialize`; when
provided, `validate_question` skips any question whose id is not in the set.
Existing callers continue to work unchanged.

**Verify:** `bundle exec rspec spec/models/assessment_answer_validator_spec.rb`
**Revert:** `git checkout -- app/models/assessment_answer_validator.rb`

### Step 4 — `AssessmentRunner` filtering + stable step ids + `active_question_ids`

- Filter `questions` and `sections` by `visible_if` against `@answers`
  using `PredicateEvaluator`.
- Switch step ids to `"q-#{first_question_id}"`.
- Expose `active_question_ids` (flat list of visible question ids).
- Ensure `current_step(step_id)` tolerates unknown ids (legacy URLs).

**Verify:** `bundle exec rspec spec/services/assessment_runner_spec.rb`
**Revert:** `git checkout -- app/services/assessment_runner.rb`

### Step 5 — Wire validator active set into submit paths

- `ChildProfiles::AssessmentResponsesController#update`: on submit, build a
  runner with the final merged answers, pass its `active_question_ids` into
  the validation path.
- `OnboardingSession#draft_answers_must_match_schema`: same; compute active
  set from the draft answers and pass to the validator.
- `AssessmentResponse#answers_must_match_schema_when_submitting`: accept /
  read an active set injected by the caller (via `attr_accessor` or a
  `validation_context`).

**Verify:** `bundle exec rspec spec/requests/child_profiles/assessments_spec.rb spec/models/onboarding_session_spec.rb`
**Revert:** `git checkout -- app/controllers app/models`

### Step 6 — `AssessmentEvidenceExtractor` active-set filter

Compute the active set from the response's submitted answers and template
snapshot, and skip inactive questions in `build_evidences`. Keep the
"blank answer → skip" rule unchanged.

**Verify:** `bundle exec rspec spec/services/assessment_evidence_extractor_spec.rb`
**Revert:** `git checkout -- app/services/assessment_evidence_extractor.rb`

### Step 7 — Seed `anchor_functional_profile_v2` with branching follow-ups

- Add a new published template record via the existing versioning helper
  (don't mutate v1).
- Add the three proposed follow-up questions with `visible_if` predicates.
- Update `AppSettings.onboarding_assessment_template_id` to point at v2.
- Keep v1 published for historical integrity; existing responses are
  unaffected.

**Verify:** `bin/rails db:seed` (idempotent); manual `show` of a new
onboarding run.
**Revert:** re-seed; or delete the v2 row + reset the setting.

### Step 8 — Admin editor: accept `visible_if` JSON

- Extend `AssessmentTemplate#normalize_editor_question` (and the section
  normalizer) to accept a `visible_if` field, parse it as JSON, and store
  it in the schema.
- Surface parse errors via model validations (`errors.add(:schema, ...)`).
- Add a textarea to the question and section editor partials.
- Delivery brief: `docs/features/stage-4.8.2-admin-visible-if-editor.md`.

**Verify:** `bundle exec rspec spec/requests/admin/assessment_templates_spec.rb`; manual QA.
**Revert:** `git checkout -- app/models/assessment_template.rb app/views/admin`

### Step 9 — Full-stack specs for branching onboarding + authenticated flows

- Request specs:
  - Onboarding: a draft with `stop_start_friction = "emotional_collapse"`
    exposes `transition_recovery_time`; without it, the follow-up is not
    shown and is not required on submit.
  - Authenticated: same shape, via `AssessmentResponsesController#edit` /
    `update`.
- Model + service specs for the active-set submit paths and evidence
  extraction.

**Verify:** `bundle exec rspec`
**Revert:** `git checkout -- spec`

### Step 10 — Full verification

```
bundle exec rspec
bundle exec rubocop
```

Manual QA: run the onboarding flow end-to-end with two different first
answers and confirm the follow-up shows in one and not the other; confirm
submit succeeds in both cases; confirm `ProfileEvidence` rows match the
active set.

---

## Status

- [x] Step 0 — Pre-flight
- [x] Step 1 — `PredicateEvaluator`
- [x] Step 2 — Schema validation for `visible_if`
- [x] Step 3 — `AssessmentAnswerValidator` active-set support
- [x] Step 4 — `AssessmentRunner` filtering + stable step ids
- [x] Step 5 — Wire validator active set into submit paths
- [x] Step 6 — Evidence extractor active-set filter
- [x] Step 7 — Seed `anchor_functional_profile_v2`
- [ ] Step 8 — Admin editor `visible_if` field
- [ ] Step 9 — Full-stack branching specs
- [ ] Step 10 — Full verification

**Last updated:** 2026-04-18
**Handoff note:** Stage brief authored against the Stage 4.5 / 4.7 schema
contract. No new models or migrations. New template version (`v2`) is the
delivery vehicle so published `v1` stays immutable and historical
`AssessmentResponse` rows remain valid. Stage 4.9 (option-level follow-up
sugar) and 4.10 (section salience / screener-driven ordering) build on this
stage without altering its contract.
