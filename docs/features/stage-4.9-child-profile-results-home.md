# Stage 4.9 — Child Profile Results Home

> Full brief. Consolidates the post-assessment results experience into the
> durable child profile page so a parent lands on a useful support profile after
> onboarding instead of a directory of internal app links.

---

## Goal

Turn the child profile show page into the primary post-assessment results home, combining child basics, the current support profile, strengths, profile signals, recommendations, and assessment provenance in one parent-readable view.

## User value

After completing the onboarding assessment, a parent should immediately see a clear first support profile for their child: what Anchor understands so far, what strengths and needs were signaled, and what practical next steps may help. The parent should not need to understand app concepts like current profiles, snapshots, recommendations, or assessments before getting value.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [x] Every controller action must call `authorize` through the existing Pundit policies.
- [x] Keep controllers thin; profile/result assembly belongs in presenters/helpers, not controller actions.
- [x] Preserve the existing Stage 4.5 second-brain architecture: `AssessmentResponse` remains the raw audit trail, `ProfileEvidence` remains the normalized signal layer, `CurrentProfile` remains the latest portrait, and `Recommendation` remains the action layer.
- [x] Do not introduce a separate `AutismProfile` model in this stage.
- [x] Use Tailwind CSS 4 + daisyUI 5 for rebuilt views.
- [x] Use the shared `page_header` partial where it fits the authenticated dashboard pattern.
- [x] Avoid diagnostic language. The UI should frame output as a working support profile, not as a diagnosis or clinical determination.
- [x] Existing specs must stay green.
- [x] RuboCop must stay clean.

## Reference implementation

- Model pattern: `app/models/child_profile.rb`, `app/models/current_profile.rb`, `app/models/recommendation.rb`
- Controller pattern: `app/controllers/spaces/child_profiles_controller.rb`, `app/controllers/onboarding/results_controller.rb`, `app/controllers/child_profiles/current_profiles_controller.rb`
- Presenter pattern: `app/services/child_profile_results_presenter.rb`, `app/services/onboarding_results_presenter.rb`
- View pattern: `app/views/onboarding/results/show.html.erb`, `app/views/child_profiles/current_profiles/show.html.erb`, `app/views/spaces/child_profiles/show.html.erb`
- Policy pattern: `app/policies/child_profile_policy.rb`, `app/policies/current_profile_policy.rb`, `app/policies/recommendation_policy.rb`

## Domain changes

### New models

None.

### Changed models

None expected.

The product language may refer to a child's "support profile" or "profile results," but the durable domain model remains:

```text
ChildProfile
-> Assessment / AssessmentResponse
-> ProfileEvidence
-> CurrentProfile
-> ProfileSnapshot
-> Recommendation
```

### Seed data

No new seed records are expected.

The existing onboarding template already captures the main domains needed for the first profile:

- Getting started
- Communication
- Social connection
- Flexibility
- Sensory experience
- Regulation
- Daily life
- Other important factors
- Strengths and priorities

## Routes and controllers

No new routes are expected.

Existing routes remain the source of truth:

```ruby
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles" do
    resources :assessments, controller: "child_profiles/assessments"

    resource :current_profile, only: %i[show],
      controller: "child_profiles/current_profiles"

    resources :recommendations, only: %i[index show],
      controller: "child_profiles/recommendations"
  end
end

scope :onboarding do
  resource :results, only: %i[show],
    controller: "onboarding/results"
end
```

| Controller | Actions | Notes |
|-----------|---------|-------|
| `Spaces::ChildProfilesController` | `show` | Becomes the richer results/home surface for an authenticated child profile. Should assemble current profile, recommendations, latest assessment response, and processing state through a presenter or small query helpers. |
| `Onboarding::ResultsController` | `show` | Redirects directly to `space_child_profile_path(@space, @child_profile)` once finalization/profile generation has completed. |
| `ChildProfiles::CurrentProfilesController` | `show` | Remains as an optional detail/deep-dive page. Do not remove unless a later brief explicitly consolidates routes. |
| `ChildProfiles::RecommendationsController` | `index`, `show` | Remains as the recommendation detail/history surface. |

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|-------------|
| `ChildProfilePolicy` | `show?` | User can read child profile in the child's space. |
| `CurrentProfilePolicy` | `show?` | User can read child-level profile artifacts in the child's space. |
| `RecommendationPolicy` | `index?`, `show?` | User can read child-level recommendation artifacts in the child's space. |
| `AssessmentPolicy` | `show?`, `index?` | User can read assessment history for the child if assessment summary/provenance is shown. |
| `AssessmentResponsePolicy` | `show?` | User can read submitted answers if the page links to the raw response. |

Authorization should remain explicit. If the child profile page displays current profile and recommendations inline, the controller should authorize those records or equivalent policy objects before rendering their data.

## UI

- **Layout:** dashboard for authenticated child profile; onboarding results continues to use the normal signed-in layout after account creation.
- **Turbo:** neither required for MVP; full-page render is acceptable.
- **New views:** optional partials under `app/views/spaces/child_profiles/` for profile sections if the show page becomes too large.
- **Changed views:**
  - `app/views/spaces/child_profiles/show.html.erb`
  - `app/views/onboarding/results/show.html.erb`
  - Optional shared partials for profile summary, domain cards, recommendation cards, or processing state.

### Desired information architecture

The child profile home should read as one coherent result, not as separate app modules.

1. **Header / status**
   - Child name
   - Page title should be "`[Child's name]` Profile"
   - Generated date if available
   - Processing state if profile generation is still queued or failed

2. **Profile narrative**
   - Parent-readable `CurrentProfile#narrative`
   - Empty state if evidence is still processing
   - Smaller contextual copy that this profile is a support guide, not a diagnosis

3. **Strengths and motivators**
   - Pull from dimensions such as `strengths.interests`, `strengths.profile`, `strengths.support_fit`, and `strengths.support_history`
   - This should appear before deficit/friction-heavy domains when present

4. **Profile domains**
   - Group current profile dimensions into parent-readable sections:
     - Communication
     - Social connection
     - Flexibility
     - Sensory experience
     - Regulation
     - Daily life
     - Other important factors
     - Priorities
   - Each domain should show latest value, evidence count, confidence where useful, and plain-language context.

5. **Recommended next steps**
   - Show the latest active recommendations inline.
   - Each recommendation should include title, practical body copy, and a lightweight "based on" signal from rationale where useful.

6. **Assessment provenance**
   - Show which assessment informed the profile, who responded, and when it was submitted.
   - Link to view submitted answers or assessment history.

### Product language

Prefer:

- "`[Child's name]` Profile"
- "support profile"
- "profile signals"
- "what may help"
- "based on your answers"

Avoid:

- "diagnosis"
- "severity score"
- "autism score"
- "deficits"
- "symptoms prove"

Internally, this feature can support autism-related care needs, but the parent-facing page should not imply clinical diagnosis.

## Acceptance criteria

- [x] After onboarding finalization, the parent can reach a child profile page that shows the first support profile without needing to navigate through separate Current Profile and Recommendations cards.
- [x] The child profile show page displays the current profile narrative when available.
- [x] The page displays strengths/motivators from profile dimensions when available.
- [x] The page groups profile signals into parent-readable domains instead of exposing raw dimension keys as the primary structure.
- [x] The page displays active recommendations inline with enough rationale to feel grounded in the assessment.
- [x] The page shows a clear empty/processing state when profile evidence or recommendations are not ready yet.
- [x] The page includes assessment provenance and links to assessment history or submitted answers where authorized.
- [x] The old current profile and recommendations pages still work as detail/history surfaces.
- [x] The page avoids diagnostic claims and frames output as a working support profile.
- [x] Request specs cover the child profile show page with and without generated profile data.
- [x] Existing onboarding results specs are updated to match the chosen redirect or transitional results behavior.

## Out of scope

- No new `AutismProfile` model.
- No new database tables or migrations.
- No clinical scoring engine.
- No standardized diagnostic interpretation.
- No AI-generated narrative rewrite unless a later brief explicitly scopes it.
- No redesign of the assessment runner.
- No recommendation feedback/outcome tracking.
- No external therapist/teacher portal changes.

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Decisions

- `/onboarding/results` redirects directly to `space_child_profile_path(@space, @child_profile)`.
- Parent-facing page title should be "`[Child's name]` Profile".
- Non-diagnostic framing should appear as smaller contextual text, not a large visible disclaimer block.

## Steps

### Step 1 — Decide result destination and page language

Resolved before build:

- `/onboarding/results` redirects directly to `space_child_profile_path(@space, @child_profile)`.
- Parent-facing page title should be "`[Child's name]` Profile".
- Non-diagnostic framing should appear as smaller contextual text.

**Verify:** Open questions are empty.
**Revert:** Documentation-only; revert this brief if direction changes.

### Step 2 — Add a child profile results presenter

Create a presenter or service that assembles the child profile show data without putting query and grouping logic in `Spaces::ChildProfilesController#show`.

The presenter should expose:

- child basics
- current profile or empty current profile object
- grouped strengths dimensions
- grouped profile domains
- active recommendations
- latest submitted assessment/response provenance
- processing status

**Verify:** `bundle exec rspec spec/services/child_profile_results_presenter_spec.rb`
**Revert:** Remove the presenter and spec.

### Step 3 — Rebuild the child profile show page as the results home

Update `app/views/spaces/child_profiles/show.html.erb` so the primary screen shows the support profile, domains, strengths, recommendations, and provenance. Keep edit/archive/profile-history actions available but secondary.

**Verify:** `bundle exec rspec spec/requests/spaces/child_profiles_spec.rb`
**Revert:** Revert the child profile show view and controller/presenter wiring.

### Step 4 — Update onboarding results handoff

Redirect `/onboarding/results` to the durable child profile show page once finalization is complete. Avoid duplicate long-term results surfaces.

**Verify:** `bundle exec rspec spec/requests/onboarding/results_spec.rb spec/services/onboarding_results_presenter_spec.rb`
**Revert:** Revert onboarding results controller/view/presenter changes.

### Step 5 — Add focused empty, processing, and authorization coverage

Add or update specs for:

- child with no current profile yet
- child with current profile but no recommendations
- child with failed or queued assessment processing status
- unauthorized user cannot see another space's child profile/results

**Verify:** `bundle exec rspec spec/requests/spaces/child_profiles_spec.rb spec/requests/onboarding/results_spec.rb`
**Revert:** Revert specs and related implementation changes.

### Step 6 — Post-build audit and docs

Audit the finished stage against the brief:

- controller authorization
- tenant scoping
- N+1 risks
- daisyUI 5 conventions
- diagnostic-language guardrails
- empty states

Update the `## Status` section and update `docs/ARCHITECTURE.md` only if the implementation changes architectural patterns.

**Verify:** `bundle exec rspec && bundle exec rubocop`
**Revert:** Revert doc/status updates if the build is rolled back.

---

## Post-build audit (Step 6)

| Area | Finding |
|------|---------|
| **Controller authorization** | `Spaces::ChildProfilesController#show` calls `authorize` on `@child_profile`, `@current_profile`, and `Recommendation.new(child_profile: …)` for `:index?`. `Onboarding::ResultsController` scopes the session with `current_user.onboarding_sessions.find(…)` and authorizes on the non-redirect path. |
| **Tenant scoping** | Child records are loaded only via `@space.child_profiles.friendly.find`; policies use `user.get_role_in_space(record.space)`. |
| **N+1 risks** | `ChildProfileResultsPresenter#latest_assessment_response` uses `includes(assessment: :assessment_template)`. Recommendations are a single query; the show template does not traverse unloaded associations per row. |
| **daisyUI 5** | Show view uses `card`, `badge`, `btn`, `rounded-box`, and dashboard layout; consistent with existing authenticated UI. |
| **Diagnostic language** | Page frames content as a support profile; explicit non-diagnostic disclaimer in small body copy on the show page. |
| **Empty states** | Covered in UI (dashed placeholders) and in request specs (no profile, no recommendations, queued/failed processing). |

`docs/ARCHITECTURE.md` updated: onboarding funnel end state, new **Child profile results home (Stage 4.9)** subsection, feature stages row for 4.9.

---

## Status

- [x] Step 1 — Decide result destination and page language
- [x] Step 2 — Add a child profile results presenter
- [x] Step 3 — Rebuild the child profile show page as the results home
- [x] Step 4 — Update onboarding results handoff
- [x] Step 5 — Add focused empty, processing, and authorization coverage
- [x] Step 6 — Post-build audit and docs

**Last updated:** 2026-04-24
**Handoff note:** Stage 4.9 build and audit are complete. Optional follow-ups: remove or repurpose the legacy `app/views/onboarding/results/show.html.erb` if the non-redirect path is never product-supported; add `authorize @space` if product policy later requires explicit workspace checks before `Space.find`.
