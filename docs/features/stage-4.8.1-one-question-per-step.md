# Stage 4.8.1 — One Question Per Step (Conversational Runner)

> Light brief. Follows Stage 4.8 (Adaptive Assessment Branching). No new
> models, controllers, routes, policies, or migrations. Pure runner + view
> refactor, plus a small seed cleanup.
>
> Purpose: make the adaptive assessment feel like a conversation by showing
> one question per screen, so that the branching introduced in Stage 4.8
> is immediately visible the moment a triggering answer is given.

---

## Goal

Display exactly one question per runner step in both the onboarding and
authenticated assessment flows, so that each answer produces an immediate,
visible branch transition and the flow feels like a guided conversation
instead of a sectioned form.

## User value

A parent answering *"Becomes frustrated or upset"* to `expression_of_needs`
immediately lands on the follow-up *"When frustration builds because they
can't express what they need, what helps most?"* on the very next screen —
not bundled below an unrelated question they were already being asked.
Single-question pages lower cognitive load, make branching feel alive, and
set up richer per-question UX (acknowledgements, helper copy) in later
stages.

## Changes

### Runner

- `AssessmentRunner#grouped_questions` (`app/services/assessment_runner.rb:131`)
  currently groups by `step_group` (falling back to question id). Change it
  to always produce one-question groups so each question becomes its own
  step. The existing `q-<question_id>` step-id scheme (introduced in Stage
  4.8) already assumes one leading question per step; under the new grouping
  it becomes literal rather than conventional.

### Schema field `step_group`

- `AssessmentTemplate::OPTIONAL_STRING_QUESTION_FIELDS`
  (`app/models/assessment_template.rb:44`) keeps `step_group` in the
  allow-list so the already-published `anchor_functional_profile_v1` and
  `anchor_functional_profile_v2` schemas remain valid. The field becomes a
  no-op at runtime; we do not mutate published schemas.
- Annotate `step_group` as deprecated/reserved in a schema comment (or in
  `docs/modules/assessments.md` if that page exists) so authors stop using
  it. A later stage may reintroduce it as purely thematic metadata (e.g. for
  cross-question analytics) without affecting runner grouping.

### Seeds

- Extend `db/seeds/assessment_templates/anchor_initial_profile.rb` to
  publish a new immutable version **`anchor_functional_profile_v3`** that
  omits the `step_group` field on every question. `v2` stays untouched so
  any in-flight `AssessmentResponse` / `OnboardingSession` drafts tied to
  `v2` keep validating and rendering.
- Update `AppSettings.onboarding_assessment_template_id` to point to `v3`.
- Archive `v2` (same pattern used when we archived `v1`) so admin dropdowns
  show only the current published version.

### Views

- `app/views/child_profiles/assessment_responses/edit.html.erb` and
  `app/views/onboarding/assessments/show.html.erb` already iterate over
  `@current_step["questions"]`, which after the runner change will always
  contain exactly one question. No structural view change is required.
- Tighten the per-step breadcrumbs so single-question pages feel intentional
  rather than noisy:
  - Keep the section title as a soft contextual label above the question.
  - Replace `Step X of N` with a section-scoped counter (e.g.
    `Communication — question 2 of 4`) derived from the runner.
  - Keep the overall `X of N answered` progress line.
- If helpful, expose a small `AssessmentRunner#section_progress_for(step)`
  helper returning `{ index:, total: }` within the step's section to keep
  the view DRY. Optional; inline computation from `steps` is also fine.

### Specs

- `spec/services/assessment_runner_spec.rb` — update cases that rely on
  `step_group` to flatten to one-per-step (e.g. the `"grouped"` step_group
  fixture at `spec/services/assessment_runner_spec.rb:194`). Add a spec
  asserting that two questions with the same `step_group` now produce two
  separate steps with stable ids `q-<id>`.
- `spec/models/assessment_template_spec.rb` — keep the `step_group`
  allow-list assertion; add a note that it is a runtime no-op.
- `spec/requests/child_profiles/assessments_spec.rb` and
  `spec/requests/onboarding_flow_spec.rb` — adjust any assertions that
  expect two questions to co-occur on a single step.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action calls `authorize` (Pundit) — unchanged
- [ ] Controllers remain thin; grouping change is isolated to the runner
- [ ] `AssessmentTemplate`, `Assessment`, `AssessmentResponse`,
      `OnboardingSession` contracts unchanged
- [ ] Published template immutability preserved; we add a `v3` instead of
      mutating `v2`
- [ ] Response-level template snapshotting still captures the full schema,
      including any preserved `step_group` values on historical `v2`
      responses
- [ ] Runner remains server-rendered via Turbo Frames; no client-side
      grouping logic
- [ ] Existing specs stay green; RuboCop clean
- [ ] Use Tailwind CSS 4 + daisyUI 5 for any view copy/layout tweaks

## Out of scope

- Option-level acknowledgements / per-option helper copy (Stage 4.9).
- Section salience / screener-driven ordering (Stage 4.10).
- Removing `step_group` from the schema allow-list. We keep the field
  tolerated to protect historical schemas.
- Inline "question N of N" live updates over Turbo Streams when a branch
  reveals a new question; the server-rendered counter after each
  `submit_action=next` is sufficient.
- Client-side transitions/animations between questions.
- Migration of historical `AssessmentResponse` rows tied to `v1` or `v2`.

## Open questions

> **Gate rule:** If any questions remain here, do not start building.

- None

## Acceptance criteria

- [ ] Every runner step in `v3` contains exactly one question.
- [ ] Answering a question whose value flips a `visible_if` predicate causes
      the very next step (after `submit_action=next`) to be the newly-visible
      follow-up question, with stable `q-<question_id>` in the URL.
- [ ] Two questions that previously shared `step_group` in `v1`/`v2` now
      render on separate steps when those templates are loaded (runtime
      behavior change is backwards-compatible for drafts in-flight).
- [ ] `AppSettings.onboarding_assessment_template_id` resolves to
      `anchor_functional_profile_v3`.
- [ ] `v1` and `v2` remain in the database but are not published in admin
      pickers.
- [ ] Breadcrumbs read cleanly on single-question pages (e.g. "Communication
      — question 2 of 4"); no `Step 1 of 1` noise.
- [ ] `AssessmentTemplate` still accepts the `step_group` field on question
      definitions (backwards-compatible).
- [ ] RuboCop clean; full spec suite green.

## Steps

### Step 0 — Pre-flight

```
bundle exec rspec
bundle exec rubocop
bin/rails db:migrate:status
git status
```

**Revert:** n/a

### Step 1 — Runner: one-question-per-step grouping

Change `AssessmentRunner#grouped_questions` to return `[[question], ...]`
(i.e. always one-per-group, ignoring `step_group`). Keep sort order by
`position`. Keep `build_question_step` as-is; its `question_ids` and
`questions` arrays will now have length 1.

**Verify:** `bundle exec rspec spec/services/assessment_runner_spec.rb`
**Revert:** `git checkout -- app/services/assessment_runner.rb`

### Step 2 — Section-scoped progress helper (optional)

Add `AssessmentRunner#section_progress_for(step)` returning
`{ index:, total: }` within the step's section. Cover with a spec.

**Verify:** `bundle exec rspec spec/services/assessment_runner_spec.rb`
**Revert:** `git checkout -- app/services/assessment_runner.rb spec/services/assessment_runner_spec.rb`

### Step 3 — View breadcrumbs

Update `app/views/child_profiles/assessment_responses/edit.html.erb` and
`app/views/onboarding/assessments/show.html.erb` to use the section-scoped
counter and drop the `Step 1 of 1` line when there's only one step in the
section. Keep the overall answered counter.

**Verify:** Manual QA on both flows; existing request specs must still
pass.
**Revert:** `git checkout -- app/views`

### Step 4 — Seed `anchor_functional_profile_v3`

- Add a `v3` block in `db/seeds/assessment_templates/anchor_initial_profile.rb`
  mirroring `v2` but with `step_group` removed from every question.
- Use the same "save! unless persisted?" idempotency pattern already in use.
- Update `AppSettings.onboarding_assessment_template_id` to the new `v3` id.
- Archive `v2` in the same seed run (idempotent: only if currently
  `published`).

**Verify:** `bin/rails db:seed` runs cleanly twice in a row; admin dropdown
shows only `v3`; onboarding link resolves to `v3`.
**Revert:** Archive `v3` and re-publish `v2`; reset `AppSettings` via
console.

### Step 5 — Update runner + request specs

- Update `spec/services/assessment_runner_spec.rb` to expect one-per-step
  grouping; add coverage for the new behavior when `step_group` is present
  (it is ignored).
- Update any affected request specs
  (`spec/requests/child_profiles/assessments_spec.rb`,
  `spec/requests/onboarding_flow_spec.rb`) whose assertions assumed two
  questions on the same step.

**Verify:** `bundle exec rspec spec/services spec/requests`
**Revert:** `git checkout -- spec`

### Step 6 — Full-stack branching spec under one-question-per-step

Add (or extend) a request spec that:

1. Loads the `v3` onboarding template.
2. Posts an answer that triggers a `visible_if` follow-up.
3. Asserts the **very next** step rendered contains exactly one question
   and that it is the follow-up question, with `q-<follow_up_id>` in the
   hidden `current_step_id` field.

**Verify:** `bundle exec rspec spec/requests/onboarding_flow_spec.rb spec/requests/child_profiles/assessments_spec.rb`
**Revert:** `git checkout -- spec`

### Step 7 — Full verification

```
bundle exec rspec
bundle exec rubocop
```

Manual QA:

- Start a fresh onboarding run against `v3`.
- Confirm every screen shows exactly one question.
- Flip `expression_of_needs` between its branching and non-branching
  values; confirm `frustration_deescalation` appears/disappears on the very
  next step.
- Confirm `ProfileEvidence` rows after submit match the active set
  (inherited guarantee from Stage 4.8; this stage should not regress it).

---

## Status

- [ ] Step 0 — Pre-flight
- [ ] Step 1 — Runner one-question-per-step grouping
- [ ] Step 2 — Section-scoped progress helper (optional)
- [ ] Step 3 — View breadcrumbs
- [ ] Step 4 — Seed `anchor_functional_profile_v3`
- [ ] Step 5 — Spec updates for new grouping
- [ ] Step 6 — Full-stack branching spec
- [ ] Step 7 — Full verification

**Last updated:** 2026-04-18
**Handoff note:** Follow-up to Stage 4.8. Delivery vehicle is a new
published template version (`v3`) so `v2` stays immutable and any in-flight
responses remain valid. `step_group` is retained in the schema allow-list
as a deprecated no-op; removal (if ever) should be its own stage.
