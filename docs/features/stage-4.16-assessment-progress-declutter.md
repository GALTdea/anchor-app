# Stage 4.16 — Assessment Progress Declutter

> Light brief. Simplifies the guided assessment progress UI in the onboarding
> and authenticated assessment flows. No new models, controllers, routes,
> policies, migrations, or schema changes.
>
> Purpose: reduce visual clutter and avoid competing progress signals while a
> parent is answering one question at a time.

---

## Goal

Show one clear assessment progress indicator by keeping the global answered
counter and removing the section-local `Question X of Y` counter from the
question card header.

## User value

Parents completing onboarding should not have to interpret two nearby counters
that both appear to describe progress. The global `5 of 10 answered` counter
answers the most useful question: "How much of the assessment have I completed?"
Removing `Question 2 of 2` makes the card quieter and keeps attention on the
current question.

## Changes

- Update `app/views/onboarding/assessments/show.html.erb`:
  - Keep the top progress row with `Section X of Y` and
    `X of Y answered`.
  - Remove the in-card `Question X of Y` display.
  - Keep the current section title in the card header.
- Update `app/views/child_profiles/assessment_responses/edit.html.erb`:
  - Remove the in-card `Question X of Y` display for the authenticated
    assessment runner as well.
  - Keep the current section title in the card header.
- Leave `AssessmentRunner#section_progress_for` in place for now. It may still
  be useful for future UX, and removing it would broaden this from a view
  cleanup into a runner/API cleanup.
- Update or add focused request/view specs if any existing assertions expect
  the `Question X of Y` text to appear.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Use Tailwind CSS 4 + daisyUI 5 for any view layout changes.
- [ ] Keep the runner server-rendered; do not add client-side progress logic.
- [ ] Do not change assessment navigation, branching, autosave, submission, or
      validation behavior.
- [ ] Do not change controller authorization, routes, policies, models, or
      database schema.
- [ ] Keep onboarding and authenticated assessment runner UI behavior aligned.
- [ ] Existing specs stay green; RuboCop clean.

## Out of scope

- Replacing the global answered counter with a progress bar.
- Changing `Section X of Y` behavior.
- Recalculating global progress against answer-dependent visible questions.
- Removing `AssessmentRunner#section_progress_for`.
- Redesigning the assessment card, question field partials, or navigation
  buttons.

## Open questions

> **Gate rule:** If any questions remain here, do not start building.

- None

## Acceptance criteria

- [x] The onboarding assessment screen no longer renders `Question X of Y`
      inside the question card.
- [x] The authenticated child-profile assessment edit screen no longer renders
      `Question X of Y` inside the question card.
- [x] The global `X of Y answered` counter still renders near the top of the
      assessment flow.
- [x] The current section title, such as `Regulation & Transitions`, still
      renders in the card header.
- [x] Answering, autosaving, moving back, moving forward, and submitting are
      unchanged.
- [x] Targeted specs pass; RuboCop is clean for changed files.

## Steps

### Step 0 — Pre-flight

```
bundle exec rspec
bundle exec rubocop
bin/rails db:migrate:status
git status
```

**Verify:** Record whether the foundation is clean or list known existing
failures before making changes.
**Revert:** n/a

### Step 1 — Remove section-local question counter from views

Remove the `@section_progress` conditional block that renders
`Question X of Y` from:

- `app/views/onboarding/assessments/show.html.erb`
- `app/views/child_profiles/assessment_responses/edit.html.erb`

Keep the section title and global answered counter intact.

**Verify:** Render both assessment flows and confirm only one progress counter
is visible.
**Revert:** `git checkout -- app/views/onboarding/assessments/show.html.erb app/views/child_profiles/assessment_responses/edit.html.erb`

### Step 2 — Update focused specs

Search for specs that assert `Question X of Y` and update them to reflect the
simplified UI. Add coverage if needed to assert the global answered counter
still appears and the section title remains visible.

**Verify:** `bundle exec rspec spec/requests/onboarding_flow_spec.rb spec/requests/child_profiles/assessments_spec.rb spec/helpers/assessment_responses_helper_spec.rb`
**Revert:** `git checkout -- spec/requests/onboarding_flow_spec.rb spec/requests/child_profiles/assessments_spec.rb spec/helpers/assessment_responses_helper_spec.rb`

### Step 3 — Final verification

Run style and targeted regression checks for the changed surface.

**Verify:**

```
bundle exec rubocop app/views/onboarding/assessments/show.html.erb app/views/child_profiles/assessment_responses/edit.html.erb
bundle exec rspec spec/requests/onboarding_flow_spec.rb spec/requests/child_profiles/assessments_spec.rb
```

**Revert:** Revert the changed view/spec files from this brief.

---

## Status

- [x] Step 0 — Pre-flight
- [x] Step 1 — Remove section-local question counter from views
- [x] Step 2 — Update focused specs
- [x] Step 3 — Final verification

**Last updated:** 2026-05-20
**Handoff note:** Brief created from UI review of the onboarding assessment
screen. Decision: keep the global `X of Y answered` counter and remove the
in-card `Question X of Y` counter to reduce clutter and avoid redundant
progress signals.
