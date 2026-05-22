# Stage 5.1 — Dedicated Admin Home

> Full brief. Adds a dedicated `/admin` landing page and scopes the admin
> sidebar to admin screens only, so admin users can switch between normal app
> workflows and admin tooling without the dashboard navigation being replaced
> everywhere.

---

## Goal

Create a simple admin home page at `/admin` and make the admin sidebar render
only for admin namespace pages.

## User value

An admin can enter a clear admin area before managing assessment templates or
setup. When they are using normal app pages such as Home or Spaces, they see the
same dashboard navigation as other authenticated users instead of an admin-only
sidebar.

This keeps operational tools discoverable without making the regular product
experience feel different or harder to navigate for admin accounts.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [x] Every controller action calls `authorize` (Pundit)
- [x] Admin-only features gate on `user.admin?`
- [x] Keep controllers thin
- [x] Use RESTful routes where practical
- [x] Use Tailwind CSS 4 + daisyUI 5 for all new views
- [x] Keep views DRY with partials
- [x] Use `render "shared/page_header"` for page titles where it fits the
      existing page pattern
- [x] Existing assessment template management routes and behavior must continue
      to work
- [x] Existing specs must stay green
- [x] RuboCop must stay clean

## Reference implementation

- Controller pattern: `app/controllers/admin/assessment_templates_controller.rb`
- View pattern: `app/views/admin/assessment_templates/index.html.erb`
- Layout pattern: `app/views/layouts/dashboard.html.erb`
- Sidebar pattern: `app/views/shared/_dashboard_sidebar.html.erb`
- Policy pattern: `app/policies/assessment_template_policy.rb`
- Existing feature brief: `docs/features/stage-5-assessment-template-manager.md`

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

The existing seeded admin account remains:

- `admin@example.com`
- `password123`

## Routes and controllers

```ruby
namespace :admin do
  root "dashboard#show"

  resources :assessment_templates, only: %i[index show new create edit update] do
    member do
      get :preview
      post :publish
      post :new_version
      post :set_as_onboarding
    end
  end
end
```

| Controller | Actions | Notes |
|-----------|---------|-------|
| `Admin::DashboardController` | `show` | Admin-only landing page for operational tools |

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|-------------|
| `Admin::DashboardPolicy` or equivalent Pundit authorization target | `show?` | Admin users only |

Authorization should stay explicit. The dashboard action may authorize a
lightweight policy object, a symbol policy, or another conventional Pundit
target already used in the app, but the controller action must call
`authorize`.

Non-admin authenticated users should not be able to access `/admin`.

## UI

- **Layout:** `dashboard`
- **Turbo:** neither
- **New views:** `app/views/admin/dashboard/show.html.erb`
- **Changed views:**
  - `app/views/layouts/dashboard.html.erb`
  - `app/views/shared/_dashboard_sidebar.html.erb`

### Admin home page

The `/admin` page should be intentionally simple. It should provide direct
links to the current admin tools:

- Assessment Templates
- Setup

The page does not need analytics, charts, system metrics, recent activity, or
user management in this stage.

### Admin sidebar

The existing sidebar should become admin-area navigation rather than a global
replacement dashboard for admin accounts.

Keep or add:

- Admin Home -> `/admin`
- Assessments -> `/admin/assessment_templates`
- Setup -> `/setup/edit`

Remove from the admin sidebar:

- Home
- Spaces

### Dashboard layout behavior

Current behavior:

```erb
<% admin_sidebar = current_user&.admin? %>
```

Target behavior:

```erb
<% admin_sidebar = current_user&.admin? && controller_path.start_with?("admin/") %>
```

The exact helper or predicate can differ, but the behavior should be:

- Admin sidebar appears on `/admin` and `/admin/*`
- Normal dashboard top navigation appears on regular authenticated pages,
  including for admin users

## Acceptance criteria

- [x] Admin users can visit `/admin`
- [x] `/admin` renders a simple admin home page
- [x] `/admin` links to assessment template management
- [x] `/admin` links to setup
- [x] Admin sidebar renders on `/admin`
- [x] Admin sidebar renders on `/admin/assessment_templates`
- [x] Admin sidebar does not render on `/home` for admin users
- [x] Admin sidebar does not render on `/spaces` for admin users
- [x] Non-admin authenticated users cannot access `/admin`
- [x] Existing assessment template admin routes still work

## Out of scope

- User management
- Admin analytics or reporting
- Role management
- New admin CRUD features beyond the existing assessment template manager
- Reintroducing `rails_admin`
- Changing assessment template authoring behavior
- Changing setup form behavior

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Steps

### Step 1 — Add the admin landing route and controller

Add `admin_root_path` via `root "dashboard#show"` inside the admin namespace.
Create `Admin::DashboardController#show` and authorize the action for admin
users only.

**Verify:** `bundle exec rspec spec/requests/admin/dashboard_spec.rb`
**Revert:** Remove the route, controller, policy target, and request spec.

### Step 2 — Add the admin home view

Create a simple admin home page that links to assessment templates and setup.
Use existing dashboard/daisyUI conventions and keep the page operational rather
than decorative.

**Verify:** `bundle exec rspec spec/requests/admin/dashboard_spec.rb`
**Revert:** Remove `app/views/admin/dashboard/show.html.erb`.

### Step 3 — Scope the admin sidebar to admin pages

Update the dashboard layout so admin users get the admin sidebar only when the
current controller is inside the admin namespace. Keep the normal dashboard top
navigation for admin users on non-admin pages.

**Verify:** Request specs covering `/admin`, `/home`, and `/spaces` layout
behavior for an admin user.
**Revert:** Restore the previous layout predicate.

### Step 4 — Convert the sidebar into admin navigation

Update `shared/dashboard_sidebar` so it links to Admin Home, Assessments, and
Setup. Remove Home and Spaces from the admin sidebar.

**Verify:** Request/view specs or rendered request assertions that the admin
sidebar contains admin links and no longer contains Home/Spaces on admin pages.
**Revert:** Restore the previous sidebar partial.

### Step 5 — Run final verification

Run targeted request specs, then the stage boundary checks.

**Verify:**

```sh
bundle exec rspec spec/requests/admin/dashboard_spec.rb spec/requests/admin/assessment_templates_spec.rb
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
**Handoff note:** Stage complete. Admin home at `/admin`, sidebar scoped to admin
namespace pages, and request specs cover layout behavior for admin users.
