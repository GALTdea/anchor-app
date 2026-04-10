# Stage 4.6 — First-Time Parent Onboarding Funnel

> **Status: COMPLETED**
> Full brief. Builds on Stage 4.5 by adding a much simpler first-time parent
> journey in front of the existing assessment + second-brain system. The parent
> should feel like they are starting help for their child, not configuring a
> workspace app.

---

## Goal

Replace the current setup-heavy first-visit flow with a guided child-first funnel
that lets a new parent start the onboarding assessment immediately, while the app
quietly creates the required `Space`, `ChildProfile`, `Assessment`, and related
records behind the scenes at the right moment.

## Status

- [x] Brief defaults resolved and build gate cleared
- [x] `OnboardingSession` model + migration added
- [x] Public onboarding foundation added: landing CTA, session start/resume,
      child-basics step, and assessment handoff placeholder
- [x] Public assessment step now saves draft answers into `OnboardingSession`
      and advances to an account-step placeholder
- [x] Account step now creates or claims a parent account and finalizes durable
      records
- [x] Results step now renders the first profile and recommendations from the
      Stage 4.5 pipeline
- [x] Dedicated `OnboardingSessionPolicy` added for browser-session access
- [x] Finalization into `User` / `Space` / `ChildProfile` / `Assessment` /
      `AssessmentResponse`
- [x] Account creation / claim step
- [x] Results screen backed by Stage 4.5 profile and recommendation records
- [x] Post-build audit completed for authorization, completed-session behavior,
      and onboarding edge cases

## User value

A first-time parent can land on the site, click a clear CTA like `Start your child's
profile`, answer a few child basics, complete the onboarding assessment, and see an
initial profile and recommendations without first learning the app's internal
concepts like spaces, roles, or child profiles.

The system still ends up with the same durable domain objects, but the parent
experiences one guided path instead of multiple setup steps.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action calls `authorize` (Pundit or explicit policy class)
- [ ] Keep controllers thin — funnel orchestration lives in services/form objects
- [ ] Use Tailwind CSS 4 + daisyUI 5 for all new views
- [ ] Use `form_with` for forms
- [ ] Do not expose `Space` creation as a required first-time user action
- [ ] Do not require a parent to manually create a `ChildProfile` before starting
      the onboarding assessment
- [ ] Do not create permanent abandoned records just because a visitor clicked a CTA
- [ ] Existing Stage 4.5 assessment/profile/recommendation pipeline remains the
      downstream system of record
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean

## Reference implementation

- Public/app entry pattern: `app/controllers/application_controller.rb`,
  `app/views/application/landing.html.erb`
- Child/assessment pattern: `app/controllers/child_profiles/assessments_controller.rb`,
  `app/controllers/child_profiles/assessment_responses_controller.rb`
- Child profile read surfaces: `app/views/spaces/child_profiles/show.html.erb`,
  `app/views/child_profiles/current_profiles/show.html.erb`
- UI conventions: `docs/CONVENTIONS.md`
- Existing brief dependency: `docs/features/stage-4.5-adaptive-assessments.md`

## Product framing

### Parent mental model

The first-time parent is trying to:

- get help understanding their child
- answer a guided onboarding assessment
- receive a first personalized profile
- receive useful next steps

They are **not** trying to:

- create a workspace
- pick a tenant structure
- learn the app's data model
- manually create internal records before getting help

### UX principle

Use child-first language everywhere in the public funnel:

- `Start your child's profile`
- `Answer a few questions`
- `Build your child's first support profile`
- `See recommendations`

Avoid public setup language like:

- `Create space`
- `Add child profile`
- `Open assessment library`

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| `OnboardingSession` | `onboarding_sessions` | `status`, `email`, `parent_name`, `child_first_name`, `child_last_name`, `child_date_of_birth`, `draft_answers` (jsonb), `started_at`, `completed_at`, `assessment_template_id`, optional foreign keys to `user`, `space`, `child_profile`, `assessment`, `assessment_response` | Optional `belongs_to` links to finalized records |

**Intent:** `OnboardingSession` is a temporary funnel record, not the long-term
source of truth for the child. It exists to:

- keep first-time onboarding simple
- preserve progress for partial completions
- avoid immediately creating permanent records for abandoned visits
- bridge the public funnel into the existing Stage 4.5 system

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `Space` | May be auto-created from funnel finalization instead of manual UI setup | Hide tenant concepts from first-time parents |
| `ChildProfile` | May be auto-created from onboarding finalization | The child-first flow should not require a separate setup screen |
| `Assessment` / `AssessmentResponse` | Created or attached automatically during funnel finalization/start | Reuse the existing Stage 4.5 assessment + second-brain pipeline |

## Recommended creation strategy

### Recommended approach

Use a **session-first, finalize-later** flow.

```text
visitor clicks CTA
-> OnboardingSession created
-> child basics captured
-> assessment answers captured into session / linked draft response
-> account created or claimed
-> app finalizes:
   Space
   ChildProfile
   Assessment
   AssessmentResponse
-> Stage 4.5 pipeline runs
-> parent sees profile + recommendations
```

### Why this is preferred

- avoids abandoned empty spaces and child records
- supports simpler public UX
- gives flexibility on when account creation happens
- preserves the existing domain model as the durable write path

### Alternative explicitly not recommended

Do **not** create a real `Space` and `ChildProfile` immediately on CTA click. That
creates too much abandoned data and makes analytics/cleanup harder.

## Routes and controllers

```ruby
scope :onboarding do
  resource :session, only: %i[new create show update],
    controller: "onboarding/sessions"

  resource :child, only: %i[show update],
    controller: "onboarding/children"

  resource :assessment, only: %i[show update],
    controller: "onboarding/assessments"

  resource :account, only: %i[show create],
    controller: "onboarding/accounts"

  resource :results, only: %i[show],
    controller: "onboarding/results"
end
```

### Controller responsibilities

| Controller | Actions | Notes |
|-----------|---------|-------|
| `Onboarding::SessionsController` | `new`, `create`, `show`, `update` | Starts/resumes the funnel and owns the session token |
| `Onboarding::ChildrenController` | `show`, `update` | Collects minimal child basics |
| `Onboarding::AssessmentsController` | `show`, `update` | Runs the onboarding assessment in the simplified public flow |
| `Onboarding::AccountsController` | `show`, `create` | Creates or claims the parent account before revealing results |
| `Onboarding::ResultsController` | `show` | Shows initial profile/recommendations once finalization has completed |

## Service layer

- `OnboardingSessionStarter` — creates the initial session and selects the onboarding template
- `OnboardingProgressUpdater` — saves draft child fields and assessment progress
- `OnboardingFinalizer` — creates the real `Space`, `ChildProfile`, `Assessment`,
  and `AssessmentResponse`, then hands off to the Stage 4.5 pipeline
- `OnboardingSpaceNamer` — chooses default family/workspace naming without exposing
  the concept publicly
- `OnboardingResultsPresenter` — assembles the first results screen after finalization

## Data ownership

### During funnel

`OnboardingSession` owns:

- temporary child basics
- draft assessment progress
- public-session state
- resumability

### After finalization

The durable records remain:

- `User`
- `Space`
- `ChildProfile`
- `Assessment`
- `AssessmentResponse`
- `ProfileEvidence`
- `CurrentProfile`
- `ProfileSnapshot`
- `Recommendation`

`OnboardingSession` becomes an audit/logistics record, not the canonical child data
model.

## Finalization rules

- The app must create a default `Space` automatically when finalizing a brand-new
  parent onboarding
- The parent should not choose a role during first onboarding; they become the owner
  by default
- The app should create the first `ChildProfile` automatically from the funnel data
- The app should start or finalize the onboarding `Assessment` automatically
- Stage 4.5 jobs should run exactly as they do for an in-app assessment submission
- Results should only be shown after finalization is complete enough to render the
  current profile and recommendations

## UI

- **Layout:** likely `application` until account handoff, then `dashboard` once the
  parent is authenticated
- **Turbo:** optional; full-page funnel is acceptable for MVP
- **Primary CTA:** `Start your child's profile`
- **Changed views:**
  - public landing page CTA/hero
  - new first-time onboarding funnel pages
- **New views:**
  - public child-basics step
  - public onboarding assessment step
  - account creation / claim step
  - first results step

### Proposed funnel steps

1. **Landing CTA**
   - clear promise
   - one primary action

2. **Child basics**
   - first name
   - age or date of birth
   - optional last name

3. **Onboarding assessment**
   - the friendlier Stage 4.5 assessment experience
   - no app setup concepts exposed

4. **Account creation**
   - just enough to save and return
   - positioned as "save your child's profile"

5. **Results**
   - current profile summary
   - recommendations
   - next step into the full app

## Copy direction

Use warm, outcome-oriented copy:

- `Start your child's profile`
- `Answer a few questions to build a clearer picture`
- `We'll turn this into your child's first support profile`
- `Save your progress so you can come back anytime`

Avoid operational/internal copy:

- `Create a family workspace`
- `Add a child profile before continuing`
- `Choose an assessment template`

## Authorization

Public onboarding introduces a special case:

- anonymous visitors need a controlled way to access only their funnel state
- authenticated app records still use the existing Pundit child/assessment/profile policies

Recommended rule:

- use a dedicated `OnboardingSessionPolicy` for public funnel steps
- gate access by signed session token or equivalent secure session identifier
- once finalized, all regular child/profile/recommendation pages use standard Pundit rules

## Acceptance criteria

- [ ] A first-time visitor can start onboarding from one clear public CTA
- [ ] A parent does not need to manually create a `Space` before taking the onboarding assessment
- [ ] A parent does not need to manually create a `ChildProfile` before taking the onboarding assessment
- [ ] The app stores partial funnel progress without creating unnecessary permanent records on the first click
- [ ] Completing the funnel creates the necessary durable records automatically
- [ ] The finalized onboarding still uses the Stage 4.5 second-brain pipeline
- [ ] The first results screen shows the child's current profile and recommendations
- [ ] The language in the public funnel is child-first and does not expose internal app jargon
- [ ] Existing signed-in flows still work
- [ ] Specs cover public funnel flow, finalization, and authorization

## Out of scope

- Adaptive branching in the public funnel
- Inviting second caregivers during first onboarding
- Multiple children during first onboarding
- Billing / paywall decisions during first onboarding
- Email-based resume links unless explicitly prioritized
- A/B testing the landing page

## Resolved decisions

- **Account timing:** account creation is required immediately before showing the
  first personalized results screen
- **Temporary storage boundary:** `OnboardingSession` owns all draft child fields
  and draft assessment answers until finalization creates the durable assessment
  records
- **Resume behavior:** anonymous resume is browser-session based for MVP
- **Space naming:** auto-created spaces use the default format
  `"#{child_first_name}'s Family"`

## Open questions

None. Phase 3 build is unblocked.
