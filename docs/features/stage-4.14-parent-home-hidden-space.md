# Stage 4.14 — Parent Home Route and Hidden Space Tenant

> Full brief. Introduces `/home` as the parent-facing authenticated landing
> page while keeping `Space` as an internal tenant boundary.

---

## Goal

Make `/home` the normal parent landing page for managing children, without
exposing the internal `Space` tenant concept in parent-facing navigation,
actions, or URLs for the main children list.

## User value

After signup or sign-in, a parent lands on a clear home page showing their
children and a way to add another child profile. They do not need to understand
or create a "space" before receiving value from Anchor.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action must call `authorize` through Pundit.
- [ ] Use `policy_scope` or equivalent tenant-scoped authorization for index
      queries.
- [ ] Keep controllers thin; default-space provisioning belongs in a model or
      service object, not inline controller logic.
- [ ] Use RESTful routes where possible.
- [ ] Use `before_action` for shared setup.
- [ ] Use Tailwind CSS 4 + daisyUI 5 components.
- [ ] Use Rails form helpers for child profile forms.
- [ ] `Space` remains the tenant model.
- [ ] Always respect tenant scoping when loading child profiles.
- [ ] A user has one role per space through `UserRole`.
- [ ] Existing onboarding-created spaces and child profiles must continue to
      work.
- [ ] Existing specs must stay green.
- [ ] RuboCop must stay clean.

## Reference implementation

- Model pattern: `app/models/space.rb`, `app/models/user.rb`,
  `app/models/child_profile.rb`
- Controller pattern: `app/controllers/spaces/child_profiles_controller.rb`,
  `app/controllers/application_controller.rb`
- Service pattern: `app/services/onboarding_finalizer.rb`
- View pattern: `app/views/spaces/child_profiles/index.html.erb`,
  `app/views/shared/_dashboard_top_nav.html.erb`,
  `app/views/shared/_dashboard_sidebar.html.erb`
- Policy pattern: `app/policies/child_profile_policy.rb`

## Domain changes

### New models

None.

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `User` | Add or expose a primary/default space helper if one does not already exist. | `/home` needs to resolve the user's internal tenant without putting `space_id` in the URL. |
| `Space` | No table or association change expected. | `Space` remains the internal tenant boundary. |

### Seed data

No new seed records expected.

## Routes and controllers

```ruby
# Proposed parent-facing route
get "home", to: "home#index", as: :home

# Keep existing routes during migration
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles"
end
```

| Controller | Actions | Notes |
|-----------|---------|-------|
| `HomeController` | `index` | Parent-facing children list. Resolves the current user's default internal `Space` and displays active child profiles. |
| `ApplicationController` | `landing`, redirect helpers | Redirect signed-in users to `home_path` instead of `space_path(@main_space)` or `spaces_path`. |
| `SpacesController` | `index`, `show`, `new`, `create` | Treat as internal, admin-only, multi-tenant-only, or legacy. Normal parents should not land on a spaces management UI. |
| `Spaces::ChildProfilesController` | existing actions | Keep working during this stage for existing nested links and child detail flows. |

Recommended first-stage routing decision: add `/home` for the child profile list
only. Leave child detail, edit, assessment, current profile, and recommendation
routes under `/spaces/:space_id` temporarily, then lift them to parent-facing
routes in a later brief.

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|-------------|
| `ChildProfilePolicy` | `index?`, `show?`, `create?`, `update?`, `destroy?` | User can act on child profiles only through a role in the internal space. |
| `Space` policy or controller guard | legacy spaces actions | Normal parents should not manage arbitrary spaces. Admin or multi-tenant mode may retain access if needed. |

The `/home` action must authorize the child profile collection or an equivalent
space-scoped child profile object. It should not load child profiles across
spaces unless policy scope allows that explicitly.

## UI

- **Layout:** dashboard
- **Turbo:** neither required for the first stage; full-page render is
  acceptable.
- **New views:**
  - `app/views/home/index.html.erb`
- **Changed views:**
  - `app/views/shared/_dashboard_top_nav.html.erb`
  - `app/views/shared/_dashboard_sidebar.html.erb`
  - `app/views/shared/_user_menu.html.erb`
  - Existing spaces views only as needed to redirect or hide parent-facing copy.

### Parent-facing language

Prefer:

- "Home"
- "Children"
- "Child profiles"
- "Add child"
- "Add child profile"

Avoid for normal parent users:

- "Space"
- "Spaces"
- "New space"
- "Workspace"
- "Tenant"

## Acceptance criteria

- [ ] After signup/sign-in, a normal parent lands on `/home`.
- [ ] `/home` displays the parent's active child profiles.
- [ ] `/home` includes a clear primary action to add a child profile.
- [ ] A parent with no child profiles sees a parent-friendly empty state.
- [ ] Normal parent navigation does not expose "Spaces" or "New space".
- [ ] Direct visits to legacy `/spaces` routes do not show confusing spaces
      management UI to normal parents.
- [ ] Existing onboarding finalization still creates an internal `Space`, user
      role, child profile, assessment, and assessment response.
- [ ] Existing tenant isolation through `Space`, `UserRole`, and Pundit remains
      intact.

## Out of scope

- Renaming the `Space` model or `spaces` table.
- Removing all nested `/spaces/:space_id/...` routes.
- Building care-team invitation UX.
- Redesigning child profile detail, assessment, current profile, or
  recommendation pages.
- Changing subscription or role semantics.

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Steps

### Step 1 — Add parent home route and controller

Add `HomeController#index` and `/home`. Resolve the current user's default
internal space and render active child profiles using existing
`ChildProfilePolicy` behavior.

**Verify:** `bundle exec rspec spec/requests/home_spec.rb`
**Revert:** remove the route, controller, view, and request spec.

### Step 2 — Provision or recover a default internal space

Introduce a small service or model helper that ensures a normal user has a
default internal `Space`. Reuse the same role semantics as onboarding
finalization.

Recommended implementation: a service object rather than a model callback, so
space creation stays explicit and testable.

**Verify:** `bundle exec rspec spec/services/default_space_provisioner_spec.rb spec/requests/home_spec.rb`
**Revert:** remove the service/helper and restore direct space lookup.

### Step 3 — Redirect authenticated users to `/home`

Update signed-in landing behavior so normal users land on `home_path`. Preserve
the public landing page for signed-out users.

**Verify:** `bundle exec rspec spec/requests/devise/protected_routes_spec.rb spec/requests/home_spec.rb`
**Revert:** restore the previous redirect to `space_path(@main_space)` or
`spaces_path`.

### Step 4 — Replace parent-facing spaces navigation

Update dashboard top nav, sidebar, and user menu links so normal parent users
see "Home" or child-centered navigation instead of "Spaces".

**Verify:** request/view specs covering normal parent navigation labels.
**Revert:** restore the previous nav partial links.

### Step 5 — Make legacy spaces routes safe for parents

Redirect or gate `spaces#index`, `spaces#show`, `spaces#new`, and
`spaces#create` so normal parents do not see spaces management. Keep routes
available where needed for admin, multi-tenant mode, or legacy child detail
flows.

**Verify:** `bundle exec rspec spec/requests/spaces_spec.rb spec/routing/spaces_routing_spec.rb`
**Revert:** restore existing `SpacesController` behavior.

### Step 6 — Final verification and copy sweep

Search for parent-facing "Space", "Spaces", and "New space" copy. Keep internal
model, route, and spec references where appropriate, but remove confusing UI
language for normal parents.

**Verify:** `bundle exec rspec` and `bundle exec rubocop`
**Revert:** revert copy-only view changes from this step.

---

## Status

- [x] Step 1
- [x] Step 2
- [x] Step 3
- [x] Step 4
- [x] Step 5
- [x] Step 6

**Last updated:** 2026-05-15
**Handoff note:** Brief created from architecture discussion. Preferred approach
is to keep `Space` internal, introduce `/home` as the parent-facing children
list, and postpone a full model/table rename.
