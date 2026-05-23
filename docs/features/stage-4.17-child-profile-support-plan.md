# Stage 4.17 - Child Profile Support Plan

> Full brief. Adds a dedicated Support Plan page for preparation and support
> style guidance, while simplifying the child profile overview into a lighter
> current-state and next-action surface.

---

## Goal

Move the "When Things Get Hard", "What to Plan Around", and "Best Support
Style" guidance out of the profile overview and into a dedicated Support Plan
page.

## User value

A caregiver can use the child profile overview to quickly understand the
feedback loop health, what Anchor understands right now, and what to do next.
When they want a more durable day-to-day playbook, they can open Support Plan
and find preparation cues, planning reminders, and support style guidance in one
place.

This keeps the overview from becoming a long mixed dashboard while preserving
the valuable guidance that helps parents prepare for harder moments.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action calls `authorize` (Pundit)
- [ ] Keep controllers thin; page assembly belongs in presenters/helpers, not
      controller actions
- [ ] Use RESTful routes where practical
- [ ] Always respect tenant scoping through `Space` and nested `ChildProfile`
- [ ] Use `friendly_id` child profile lookup where existing nested profile pages
      do
- [ ] Use Tailwind CSS 4 + daisyUI 5 for all new views
- [ ] Use `render "shared/page_header"` where it fits the dashboard pattern
- [ ] Avoid diagnostic certainty; phrase guidance as support-oriented working
      hypotheses
- [ ] Do not require parents to understand internal concepts like evidence,
      snapshots, confidence, profile versions, or analysis runs
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean

## Reference implementation

- Controller pattern: `app/controllers/child_profiles/current_profiles_controller.rb`
- Controller pattern: `app/controllers/child_profiles/recommendations_controller.rb`
- Overview view to simplify: `app/views/spaces/child_profiles/show.html.erb`
- Presenter pattern: `app/services/child_profile_results_presenter.rb`
- Policy pattern: `app/policies/child_profile_policy.rb`,
  `app/policies/current_profile_policy.rb`, `app/policies/recommendation_policy.rb`
- Navigation pattern: profile segmented nav in
  `app/views/spaces/child_profiles/show.html.erb`
- Product framing: `docs/features/stage-4.10-child-profile-parent-guidance-ux.md`

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| None | - | - | - |

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| None | - | - |

### Seed data

No seed changes.

## Routes and controllers

```ruby
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles" do
    resource :support_plan, only: %i[show], controller: "child_profiles/support_plans"
  end
end
```

| Controller | Actions | Notes |
|-----------|---------|-------|
| `ChildProfiles::SupportPlansController` | `show` | Tenant-scoped support playbook for one child profile |

### Controller notes

The controller should follow existing nested profile pages:

- `set_space`
- `set_child_profile`
- build `ChildProfileResultsPresenter`
- authorize access explicitly

Preferred authorization is to authorize the child profile for `show?` and, if
the view uses current profile or recommendation-derived guidance, preserve the
same authorization intent as the overview page by authorizing the relevant
current profile and recommendation index context.

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|-------------|
| `ChildProfilePolicy` | `show?` | User can view profiles in spaces they can access; admins retain existing broader access |
| `CurrentProfilePolicy` | `show?` | Reuse existing current profile visibility rules if current profile data is rendered |
| `RecommendationPolicy` | `index?` | Reuse existing recommendation visibility rules if recommendation-derived guidance is rendered |

No new role or permission model should be introduced.

## UI

- **Layout:** `dashboard`
- **Turbo:** neither
- **New views:** `app/views/child_profiles/support_plans/show.html.erb`
- **Changed views:** `app/views/spaces/child_profiles/show.html.erb`
- **Changed navigation:** profile segmented nav should include `Support Plan`

### Overview page changes

Remove these sections from the child profile overview:

- `When Things Get Hard`
- `What to Plan Around`
- `Best Support Style`

The overview should stay focused on:

- feedback loop health monitor
- compact child/profile identity strip
- current understanding
- immediate focus/next-action sections
- learning areas, if still useful as a lightweight prompt

Remove local assignments from the overview when they become unused:

- `hard_moment_cards`
- `planning_areas`
- `support_style_lines`

### Support Plan page

Create a dedicated Support Plan page that uses the existing presenter data:

- `hard_moment_guide_cards`
- `planning_focus_areas`
- `best_support_style_lines`

Recommended page structure:

1. Page header:
   - Title: "`[Child]'s Support Plan`"
   - Subtitle: "A practical playbook for preparing, supporting, and adjusting
     when the day gets harder."
2. "When Things Get Hard"
   - Keep the current three-card structure
   - Preserve uncertainty language like "may", "might", and "could"
3. "What to Plan Around"
   - Keep concise planning tags
   - Consider a quiet explanatory line that these are reminders, not homework
4. "Best Support Style"
   - Keep strengths-first support guidance
   - Make this section feel like a parent playbook, not a clinical report

The page should feel useful as a reusable reference. It should not become a
second dashboard or duplicate the overview's loop health CTA.

### Profile sub-navigation

Add `Support Plan` to the profile segmented nav.

Recommended order:

- Overview
- Support Plan
- Recommendations
- Assessments
- Edit child details

The active segment should reflect the current page. If this creates duplicated
nav markup across profile views, extract a small shared partial rather than
copying a growing tab bar into every template.

## Acceptance criteria

- [ ] `/spaces/:space_id/child_profiles/:child_profile_id/support_plan` renders
      for authorized users
- [ ] Support Plan page shows "When Things Get Hard"
- [ ] Support Plan page shows "What to Plan Around"
- [ ] Support Plan page shows "Best Support Style"
- [ ] Child profile overview no longer shows those three sections
- [ ] Child profile overview still shows the feedback loop health monitor
- [ ] Profile segmented nav includes `Support Plan`
- [ ] `Support Plan` nav segment links to the new support plan page
- [ ] New support plan controller action calls `authorize`
- [ ] Unauthorized users cannot view another space's support plan through the
      nested route
- [ ] Existing profile overview, recommendations, and assessment routes still work

## Out of scope

- New database tables or persisted support-plan records
- Editing support plan content
- AI chat or live support-plan generation
- Sharing/exporting the support plan
- Redesigning recommendation detail pages
- Removing the presenter methods that generate support plan content
- Changing assessment submission or analysis behavior

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Steps

### Step 1 - Add route and controller

Add a nested singleton `support_plan` route under child profiles. Create
`ChildProfiles::SupportPlansController#show`, set the space and child profile,
build `ChildProfileResultsPresenter`, and authorize access explicitly.

**Verify:** `bundle exec rspec spec/requests/child_profiles/support_plans_spec.rb`
**Revert:** Remove the route, controller, and request spec.

### Step 2 - Build the Support Plan view

Create `app/views/child_profiles/support_plans/show.html.erb` using the existing
hard moment, planning, and support style presenter methods.

**Verify:** `bundle exec rspec spec/requests/child_profiles/support_plans_spec.rb`
**Revert:** Remove the support plan view.

### Step 3 - Move sections off the overview

Remove "When Things Get Hard", "What to Plan Around", and "Best Support Style"
from `app/views/spaces/child_profiles/show.html.erb`. Remove unused local
assignments from the top of the overview.

**Verify:** `bundle exec rspec spec/requests/spaces/child_profiles_spec.rb`
**Revert:** Restore the removed overview sections and local assignments.

### Step 4 - Update profile sub-navigation

Add `Support Plan` to the segmented profile navigation. Extract a shared partial
if more than one page needs the same navigation markup.

**Verify:** Request specs assert the overview and support plan pages both render
the expected nav links.
**Revert:** Restore the previous nav markup.

### Step 5 - Final verification

Run targeted request specs, then the stage boundary checks.

**Verify:**

```sh
bundle exec rspec spec/requests/spaces/child_profiles_spec.rb spec/requests/child_profiles/support_plans_spec.rb
bundle exec rubocop
bin/rails db:migrate:status
```

**Revert:** Revert this stage's changed files.

---

## Status

- [x] Step 1
- [x] Step 2
- [x] Step 3
- [x] Step 4
- [x] Step 5

**Last updated:** 2026-05-22
**Handoff note:** Built the Support Plan page, moved preparation/support-style
guidance off the overview, added Support Plan to the profile segmented nav, and
verified with targeted request specs, full RuboCop, and migration status.
