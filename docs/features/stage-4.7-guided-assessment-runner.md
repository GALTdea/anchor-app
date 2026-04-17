# Stage 4.7 — Guided Assessment Runner

> Full brief. Builds on Stages 4.5 and 4.6 by redesigning the assessment
> experience into a progressive, guided runner while preserving the current
> schema-driven backend and downstream second-brain pipeline.

---

## Goal

Redesign the assessment experience so it feels like a guided conversation without
becoming a chat UI.

## User value

Parents and caregivers can move through onboarding and in-app assessments with
less cognitive load, one focused prompt at a time, while the app feels more
present, supportive, and modern. The experience becomes calmer and easier to
complete without changing the underlying meaning of submitted assessment data.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action calls `authorize` (Pundit)
- [ ] Keep controllers thin; step building, runner progression, autosave merge
      behavior, and reflective summaries live in helpers/services/presenters
- [ ] Preserve the current schema-driven assessment architecture centered on
      `AssessmentTemplate`, `Assessment`, `AssessmentResponse`, and
      `OnboardingSession`
- [ ] Do not introduce a separate `Question` model in this stage
- [ ] Preserve both onboarding and authenticated assessment flows
- [ ] Preserve response-level provenance so old submissions remain interpretable
      even if template/question content changes later
- [ ] Preserve the existing template snapshot/provenance behavior on submitted
      responses in this stage; do not redesign or remove it while rebuilding the
      runner
- [ ] Do not let broader formal template versioning debates block this stage
- [ ] Use Tailwind CSS 4 + daisyUI 5 for rebuilt assessment views
- [ ] Use `form_with` for forms and stay aligned with `docs/CONVENTIONS.md`
- [ ] Prefer server-rendered Rails flows enhanced with Turbo Frames/Streams over
      a client-heavy SPA-style runner
- [ ] Autosave must feel invisible to the user and must not require manual “save
      draft” behavior as the primary interaction model
- [ ] Reflective summaries should feel supportive and lightweight, not
      diagnostic or chatbot-like
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean

## Reference implementation

- Model pattern: `app/models/assessment_template.rb`,
  `app/models/assessment_response.rb`, `app/models/onboarding_session.rb`
- Controller pattern: `app/controllers/onboarding/assessments_controller.rb`,
  `app/controllers/child_profiles/assessment_responses_controller.rb`
- View pattern: `app/views/onboarding/assessments/`,
  `app/views/child_profiles/assessment_responses/`
- Helper pattern: `app/helpers/assessment_responses_helper.rb`
- Policy pattern: `app/policies/onboarding_session_policy.rb`,
  `app/policies/assessment_response_policy.rb`

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| None | — | — | — |

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `AssessmentTemplate` | Extend `schema` with optional runner/presentation metadata for progressive delivery, small question grouping, optional deeper-detail prompts, and section transition/summary content | Support a guided runner without introducing a `Question` model |
| `AssessmentResponse` | Support partial per-step answer persistence; derive runner progress/resume position from saved answers for MVP rather than introducing persisted runner state by default | Enable one-question-at-a-time saving and resume in authenticated flows while keeping the domain model light |
| `OnboardingSession` | Support partial per-step draft persistence; derive runner progress/resume position from saved draft answers for MVP rather than introducing persisted runner state by default | Enable the same progressive runner behavior in public onboarding while preserving the session-first architecture |

### Seed data

- Update the onboarding assessment seed/template content only as needed to
  demonstrate progressive runner metadata with generic placeholder transitions
  and section summaries
- Do not block this stage on final content design; use generic copy where needed

## Routes and controllers

```ruby
resource :assessment, only: %i[show update], controller: "onboarding/assessments"

resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles" do
    resources :assessments, controller: "child_profiles/assessments" do
      resource :assessment_response, only: %i[show edit update],
        controller: "child_profiles/assessment_responses",
        as: :assessment_response
    end
  end
end
```

| Controller | Actions | Notes |
|-----------|---------|-------|
| `Onboarding::AssessmentsController` | `show`, `update` | Reuse the existing route; `show` renders the current runner step and `update` merges/saves the current step payload before advancing |
| `ChildProfiles::AssessmentResponsesController` | `edit`, `update`, `show` | Reuse the existing route; `edit` becomes the progressive runner and `update` saves one step at a time, with final submit remaining the synchronous completion boundary |

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|--------------|
| `OnboardingSessionPolicy` | `show?`, `update?` | Keep the current session-based access rules for the public onboarding runner |
| `AssessmentResponsePolicy` | `show?`, `update?`, `edit?` | Keep current child-profile/space authorization rules; draft responses remain editable, submitted responses remain read-only |
| `AssessmentPolicy` | `show?` | Keep the existing rules for assessment container visibility after submit |

## UI

- **Layout:** `application` for onboarding, `dashboard` for authenticated flow
- **Turbo:** prefer Turbo Frames for current-step replacement and Turbo Streams
  only when multiple UI regions need to update together; keep full-page fallback
  intact
- **New views:** optional shared runner partials/components if needed for step
  chrome, section transition cards, and reflective summaries
- **Changed views:**
  - `onboarding/assessments/show`
  - `child_profiles/assessment_responses/edit`
  - any shared assessment partials/helpers needed to support the new runner

### MVP UX goals

- Show one focused question at a time, or one very small related group at a time
- Replace long crowded forms with a cleaner single-task layout
- Use warm section transitions inline with the question flow rather than as
  standalone intro pages
- Keep reflection/supportive framing lightweight and inline rather than as
  standalone summary pages between sections
- Keep the question area visually dominant; repeated explanatory chrome should be
  minimized after the first assessment screen
- Use lighter answer controls that still follow Rails `form_with` + daisyUI 5
  fieldset/input/select/textarea patterns from `docs/CONVENTIONS.md`
- Offer optional deeper detail instead of forcing long-form answers upfront
- Make autosave effectively invisible and reassuring
- Add reflective summaries between sections so the app feels present during the
  assessment
- Keep progress visible but lightweight
- Support pause/resume naturally in both flows

### Post-MVP UX deferral

- Full chat-style assessment delivery
- Rich adaptive branching across the full assessment graph
- AI-generated freeform follow-up questions
- Multimodal inputs such as voice/video uploads
- Advanced review/edit screen for reordering or editing any prior answer from a
  single summary page

## Recommended architecture

```text
AssessmentTemplate schema
-> runtime runner/step builder derives ordered steps
-> current step renders in onboarding or authenticated flow
-> user answers one step
-> current step payload is posted to the existing server-side update boundary
-> server merges it into saved answers immediately
-> next step is rendered
-> section summary/transition step reflects back captured signal
-> final submission uses the existing assessment completion pipeline
```

### Architecture notes

- The primary implementation change is the runner/orchestration layer, not the
  domain model
- The app should derive a linear sequence of runner steps from schema-defined
  sections and questions; for MVP, a step should be a question, a very small
  grouped set, or the final completion/submit step
- The runner should remain server-driven: controller update actions remain the
  source of truth for persistence, validation, and next-step progression
- Keep answers stored by stable schema question IDs
- Save only the current step payload on each advance, then merge it into the
  saved response/session answer hash
- For MVP, derive resume position from saved answers rather than persisting
  explicit runner state fields unless implementation friction proves that
  lightweight state is necessary
- Validate incrementally where helpful, but reserve full required-question
  validation for final submit
- Reflective summaries should start with deterministic/template-guided behavior
  for MVP; AI-generated summaries are post-MVP unless a tightly scoped,
  low-risk implementation is explicitly approved later
- Preserve response-level provenance on submit so the app can still interpret old
  answers against the template/question structure the user saw at the time
- A separate `Question` model is explicitly deferred; this stage should instead
  strengthen runtime step/question objects in code so a future migration remains
  possible if adaptive logic later justifies it

## Acceptance criteria

- [ ] The assessment runner in both onboarding and authenticated flows presents
      one question at a time or one very small related group at a time
- [ ] The rebuilt UI feels materially cleaner and less crowded than the current
      long-form assessment pages
- [ ] Section introduction copy, when present, is embedded into the first
      question step of the section instead of rendered as its own standalone page
- [ ] Section reflection/summary copy, when present, is embedded inline or
      omitted rather than rendered as its own standalone page between sections
- [ ] Large intro/context cards are shown only where they are actually helpful
      and are not repeated on every assessment step
- [ ] The app saves each step as the user progresses without requiring explicit
      draft-save behavior as the main interaction
- [ ] Users can leave and return without losing previously entered answers
- [ ] For MVP, resume/progression works by deriving the next step from saved
      answers rather than depending on new persisted runner-state fields
- [ ] Required-question enforcement still happens before final submission
- [ ] Optional deeper-detail inputs do not block forward progress
- [ ] Section transition moments exist and can use generic placeholder copy
- [ ] Reflective section summaries make the app feel present without becoming a
      chat transcript and use deterministic/template-guided behavior in MVP
- [ ] Internal/system wording such as "prompt" is not shown in the user-facing
      assessment UI
- [ ] Repeated right-rail utility cards such as respondent/help text are removed,
      collapsed, or greatly minimized for MVP so the runner feels minimalistic
- [ ] After the first screen, the runner can present as a mostly single-column,
      low-chrome question flow
- [ ] The implementation preserves the current schema-driven architecture and does
      not require a new `Question` model
- [ ] The implementation preserves both onboarding and authenticated assessment
      flows
- [ ] Submitted responses continue to retain enough template/question provenance
      to interpret historical answers later
- [ ] Existing downstream second-brain processing continues to work without a
      domain-model rewrite

## Out of scope

- Introducing a DB-backed `Question` model
- Replacing the existing assessment domain model
- Full adaptive branching engine
- Content-design/final copywriting for the assessment prompts
- Reworking the assessment template manager beyond the minimal schema metadata
      needed for the runner
- Replacing the downstream profile/recommendation pipeline

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## UX issues found during live walkthrough

- Standalone section intro pages add an extra click before the user reaches the
  first actual question and should be removed for MVP
- Section transition framing should be folded into the first question screen of a
  section rather than rendered as its own step
- Standalone section summary/reflection pages add friction between sections and
  should be removed for MVP
- After the user completes a section, the runner should advance directly to the
  next section's first question step rather than stopping on a section-summary page
- The label showing grouped-question counts as "prompts" is internal language and
  should be removed or replaced with plain user-facing wording
- The large assessment intro/context card should not repeat on every step; it is
  better suited to the first screen only
- The right-rail cards for progress, respondent, and "what to expect" create too
  much repeated chrome and should be removed, collapsed, or greatly minimized
- The visual direction should feel more minimalistic and single-task, with the
  question area as the dominant focus on each step

## Steps

### Step 1 — Define runner metadata and runtime step builder

Add the minimal schema/presenter/service support needed to derive a progressive
runner from the existing assessment template structure. Keep the model
schema-driven and avoid introducing a `Question` model. Keep step progression
derivable from saved answers for MVP.

**Verify:** `bundle exec rspec spec/models/assessment_template_spec.rb spec/helpers/assessment_responses_helper_spec.rb`
**Revert:** Remove the added schema metadata/supporting step-builder code and
restore existing helper/model behavior

### Step 2 — Rebuild the authenticated assessment flow as a progressive runner

Update the authenticated assessment response edit/update flow so users answer one
step at a time, with per-step persistence, lightweight progress, Turbo-frame
step replacement, and section transition/summary behavior.

**Verify:** `bundle exec rspec spec/requests/child_profiles/assessments_spec.rb`
**Revert:** Restore the previous edit/update view/controller behavior for
`ChildProfiles::AssessmentResponsesController`

### Step 3 — Apply the same runner pattern to public onboarding

Update the onboarding assessment flow to use the same progressive runner pattern
while preserving the current onboarding session/draft-finalization architecture.
Keep the onboarding runner server-driven and aligned with the authenticated
implementation shape.

**Verify:** `bundle exec rspec spec/requests/onboarding_flow_spec.rb`
**Revert:** Restore the previous onboarding assessment show/update behavior

### Step 4 — Polish autosave, resume, and reflective summaries

Tighten the interaction model so autosave feels invisible, resume behavior is
reliable from saved answers, and reflective summaries/section transitions feel
cohesive across both flows.

**Verify:** `bundle exec rspec spec/requests/child_profiles/assessments_spec.rb spec/requests/onboarding_flow_spec.rb`
**Revert:** Remove the progressive runner enhancements that are not required for
basic step rendering/persistence

---

## Status

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3
- [ ] Step 4

**Last updated:** 2026-04-14
**Handoff note:** Brief created. The current recommendation is to preserve the
schema-driven architecture, defer a DB-backed `Question` model, and focus this
stage on a progressive runner with per-step persistence, lightweight runner
state if needed, and submission-time provenance instead of expanding formal
versioning requirements.
