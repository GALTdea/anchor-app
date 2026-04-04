# Stage 3 — Observations

> **Status: DEFERRED — Post-MVP**
> This feature is documented for future implementation. It will not be built until
> after the MVP is complete. The current MVP target is **Stage 1 (child profiles) +
> Stage 4 (assessments)**; Stages 2 and 3 are deferred. Do not start Phase 3 (Build)
> until this deferral is lifted.

> Full brief. Introduces new model (`Observation`), migration, controller, policy,
> routes, and views. Observations are the primary daily logging tool for caregivers.

---

## What is an Observation?

An observation is a timestamped log entry that a caregiver writes about a child.
It is the most frequently used feature in Anchor — caregivers log these daily or
multiple times a day. Unlike assessments (which are structured and periodic),
observations are freeform notes organized by category.

**Real-world examples:**

- *"Emma had a meltdown at 3pm during the transition from lunch. Duration ~10 min.
  Loud cafeteria may have been a sensory trigger."* → category: **Behavior**
- *"Jake said 'mama' spontaneously for the first time today!"* → category: **Milestone**
- *"Tried the visual schedule this morning. Jake responded really well to the
  picture cards for the morning routine."* → category: **Activity**
- *"Emma seemed low-energy and tearful most of the afternoon. No clear cause."*
  → category: **Mood**
- *"General follow-up note from today's OT session."* → category: **Note**

---

## Goal

Enable caregivers to log, view, and manage daily observations about a child, providing
a chronological care history that feeds into the same second-brain evidence pipeline
as onboarding assessments.

## User value

A parent can open a child's profile and quickly log what happened today — a behavior
event, a milestone, an activity result — with a date, category, and free-text note.
All observations appear in reverse-chronological order as a care timeline. This is
the foundation for tracking patterns over time and for continuously sharpening the
child's living profile.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action calls `authorize` (Pundit)
- [ ] Use `policy_scope` for index queries (scoped to space)
- [ ] Keep controllers thin — business logic in model/service
- [ ] Use daisyUI 5 classes for all views (no Bootstrap/Tabler)
- [ ] Use `form_with` for forms
- [ ] Use Rails generators for model, controller, migration
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean

## Reference implementation

- Model pattern: `app/models/child_profile.rb` (enum status, validations,
  belongs_to, custom validation)
- Controller pattern: `app/controllers/spaces/child_profiles_controller.rb`
  (thin actions, `before_action` chain, `authorize` everywhere, scoped lookups)
- Policy pattern: `app/policies/child_profile_policy.rb` (role via space,
  permission method checks, Scope class)
- View pattern: `app/views/spaces/child_profiles/` (daisyUI 5 card + table layout,
  `render "shared/page_header"`, empty states)
- Factory pattern: `spec/factories/child_profiles.rb` (sequence, traits)

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| `Observation` | `observations` | `child_profile_id`, `author_id`, `category`, `body`, `observed_on`, `status` | `belongs_to :child_profile`, `belongs_to :author, class_name: 'User'` |

**Full schema:**
- `child_profile_id` (bigint, not null, foreign key)
- `author_id` (bigint, not null, foreign key to users)
- `category` (integer, not null, default: 0) — enum: `note`, `behavior`,
  `milestone`, `activity`, `mood`
- `body` (text, not null) — the free-text log entry
- `observed_on` (date, not null) — when the observation happened (defaults to today)
- `status` (integer, not null, default: 0) — enum: `active`, `archived`
- timestamps

**Note on `visibility`:** The architecture doc lists `visibility` as a planned column.
For Stage 3 (single guardian, no `ChildAccess` yet), all space members see all
observations for children in their space. The `visibility` column is **deferred to
Stage 5** when per-child access roles are introduced. Do not add it now.

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `ChildProfile` | Add `has_many :observations, dependent: :destroy` | A child has many logged observations |
| `User` | Add `has_many :authored_observations, class_name: 'Observation', foreign_key: :author_id, dependent: :nullify` | A user authors many observations; if user removed, preserve the observation record |

### Second-brain integration

Observations remain the caregiver-authored daily log model. They should **not** be
collapsed into `ProfileEvidence` directly in the write path.

Instead, the intended future flow is:

```text
Observation created / updated
-> raw observation stored as the caregiver-entered record
-> observation extraction job runs
-> normalized ProfileEvidence records created
-> CurrentProfile rebuilt
-> ProfileSnapshot created only if the profile materially changed
-> Recommendation generation refreshed from the latest snapshot
```

This mirrors the assessment pipeline introduced in Stage 4.5:

- `Observation` = human-authored source record
- `ProfileEvidence` = normalized second-brain evidence
- `CurrentProfile` = latest synthesized child portrait
- `ProfileSnapshot` = historical profile state over time
- `Recommendation` = generated next-step guidance

For observation implementation, that means:

- keep the raw `body`, `category`, `observed_on`, and `author` on `Observation`
- add extraction jobs/services later rather than overloading the model itself
- use the same `child_profile_id`, `source_type`, `source_id` evidence pattern that
  assessments already use
- preserve observations as editable/archiveable human records even though downstream
  evidence and recommendations may be regenerated

### Seed data

None required. Optionally add 2–3 sample observations to the demo child profile in
`db/seeds.rb` to make the dev environment feel real. This is optional.

## Routes and controllers

```ruby
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles" do
    resources :observations, controller: "child_profiles/observations"
  end
end
```

This produces URLs like:
- `/spaces/:space_id/child_profiles/:child_profile_id/observations`
- `/spaces/:space_id/child_profiles/:child_profile_id/observations/:id`

| Controller | Actions | Notes |
|-----------|---------|-------|
| `ChildProfiles::ObservationsController` | `index`, `new`, `create`, `show`, `edit`, `update`, `destroy` | RESTful CRUD, nested under child_profile (nested under space) |

**Controller `before_action` chain:**

```ruby
class ChildProfiles::ObservationsController < ApplicationController
  before_action :set_space
  before_action :set_child_profile
  before_action :set_observation, only: %i[show edit update destroy]
end
```

- `set_space` → `Space.find(params[:space_id])`
- `set_child_profile` → `@space.child_profiles.friendly.find(params[:child_profile_id])`
- `set_observation` → `@child_profile.observations.find(params[:id])`

**Destroy:** Soft delete only — `@observation.update!(status: :archived)`.
Preserves the care history record.

**Author:** Set automatically in `create` before save:
```ruby
@observation = @child_profile.observations.build(observation_params)
@observation.author = current_user
```

## Authorization

| Policy | Action | Rule |
|--------|--------|------|
| `ObservationPolicy` | `index?` | `@role&.can_read_observation?` |
| | `show?` | `@role&.can_read_observation?` |
| | `create?` | `@role&.can_create_observation?` |
| | `update?` | `@role&.can_update_observation?` |
| | `destroy?` | `@role&.can_delete_observation?` |

Policy `initialize` — get role via the child's space:

```ruby
def initialize(user, record)
  super
  @role = user.get_role_in_space(record.child_profile.space)
end
```

**Note on `index?`:** The `index` action authorizes a dummy built record
(`@child_profile.observations.build`) so the policy has the correct
`record.child_profile.space` context — same pattern used in
`Spaces::ChildProfilesController#index`.

**Role permission matrix:**

| Role | read | create | update | delete |
|------|------|--------|--------|--------|
| Owner | ✅ | ✅ | ✅ | ✅ |
| Caregiver | ✅ | ✅ | ✅ | ✅ |
| Collaborator | ✅ | ✅ | ✅ | ✅ |

All three seeded roles have full observation permissions. Restricting edit/archive
to author only is **out of scope for Stage 3** — deferred to Stage 5.

**Scope class:**
```ruby
class Scope < ApplicationPolicy::Scope
  def resolve
    return scope.all if user.admin?
    space_ids = user.user_roles.pluck(:space_id)
    scope.joins(:child_profile).where(child_profiles: { space_id: space_ids })
  end
end
```

## UI

- **Layout:** dashboard
- **Turbo:** neither — full-page navigation is sufficient for Stage 3
- **New views:**
  - `app/views/child_profiles/observations/index.html.erb` — reverse-chronological
    list with category badge, date, author, body snippet; empty state
  - `app/views/child_profiles/observations/show.html.erb` — full detail, Back/Edit/Archive
  - `app/views/child_profiles/observations/new.html.erb` — page header + `_form`
  - `app/views/child_profiles/observations/edit.html.erb` — page header + `_form`
  - `app/views/child_profiles/observations/_form.html.erb` — category select,
    `observed_on` date field, `body` textarea
  - `app/views/child_profiles/observations/_observation.html.erb` — card partial
    (category badge, date, author name, body snippet)
- **Changed views:**
  - `app/views/spaces/child_profiles/show.html.erb` — add "Recent Observations"
    section: 3 most recent active observations + "View all" link + "Log observation"
    button

**Category badge colors (daisyUI 5):**

| Category | Badge class |
|----------|------------|
| `behavior` | `badge-error` |
| `milestone` | `badge-success` |
| `activity` | `badge-info` |
| `mood` | `badge-warning` |
| `note` | `badge-ghost` |

**Form fields:**
- `category` — `select` populated from `Observation.categories.keys`
- `observed_on` — `date_field`, default: `Date.current`
- `body` — `textarea`, required, placeholder "What did you observe?"

## Acceptance criteria

- [ ] A caregiver can log an observation for a child with category, date, and body
- [ ] Author is automatically set to the current user on create
- [ ] Observations are listed in reverse-chronological order on the observations index
- [ ] The child profile show page shows the 3 most recent active observations
- [ ] A caregiver can view a single observation's full detail page
- [ ] A caregiver can edit an observation
- [ ] A caregiver can archive an observation (soft delete — sets status to archived)
- [ ] Archived observations do not appear in the active list
- [ ] Only users who belong to the space can see/manage observations in that space
- [ ] All views use daisyUI 5 classes only
- [ ] Specs cover model validations, controller actions, and policy rules

## Out of scope

- `visibility` column and per-observation visibility control — Stage 5
- Restricting edit/archive to author only — Stage 5 or later
- Filtering or searching observations by category or date range — post-MVP UX pass
- Pagination of the observations index (add Pagy when count grows; defer for now)
- Attachments (photos, audio) — post-MVP
- Notifications when a new observation is logged — post-MVP
- Observation-to-`ProfileEvidence` extraction implementation — handled after the
  Stage 4.5 second-brain foundation is in place

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

1. **Categories:** The proposed five are `note`, `behavior`, `milestone`, `activity`,
   `mood`. These map to an integer enum in the migration — renaming or removing
   values later requires a migration. Are these the right set for Anchor? Consider
   whether autism-specific categories like `sensory`, `medication`, `sleep`, or
   `seizure` belong here or are better as sub-tags later. **Decide before building.**

2. **Edit policy:** Should only the observation's author be able to edit/archive, or
   is role permission sufficient (anyone with `update_observation` in the space)?
   Stage 3 proposal: role permission only. If you want author-only, say so now.

3. **Child profile show page:** Should the show page gain a "Recent Observations"
   inline section, or should clicking a child's name go straight to the observations
   list? Recommendation: keep the show page, add inline section.

---

## Steps

### Step 1 — Generate Observation model, migration, factory, and spec

```
bin/rails generate model Observation child_profile:references \
  author_id:integer:index category:integer body:text \
  observed_on:date status:integer
```

Manually enhance the generated migration:
- Add `null: false` to `child_profile_id`, `body`, `observed_on`
- Add `null: false, default: 0` to `category` and `status`
- Add `foreign_key: true` to `author_id` (references `users`)
- Add index on `author_id`

Manually enhance the model:
- `belongs_to :child_profile`
- `belongs_to :author, class_name: 'User', foreign_key: :author_id`
- `enum :category, { note: 0, behavior: 1, milestone: 2, activity: 3, mood: 4 }, default: :note`
- `enum :status, { active: 0, archived: 1 }, default: :active`
- Validations: presence of `body`, `observed_on`, `category`
- Custom validation: `observed_on` cannot be in the future
- Scopes: `active`, `archived`, `recent` (`order(observed_on: :desc)`)

Factory (`spec/factories/observations.rb`):
- Associations: `child_profile`, `author` (user)
- Defaults: `category :note`, `body "Sample observation."`, `observed_on Date.current`, `status :active`
- Traits: `:archived`, `:behavior`, `:milestone`, `:past` (observed_on 7 days ago)

Model spec (`spec/models/observation_spec.rb`):
- Associations, validations, enum values, scopes, `observed_on` not-in-future

**Verify:** `bundle exec rspec spec/models/observation_spec.rb`
**Revert:** `bin/rails destroy model Observation` + `bin/rails db:rollback`

---

### Step 2 — Add associations to ChildProfile and User, update specs

Add to `app/models/child_profile.rb`:
```ruby
has_many :observations, dependent: :destroy
```

Add to `app/models/user.rb`:
```ruby
has_many :authored_observations, class_name: 'Observation',
  foreign_key: :author_id, dependent: :nullify
```

Update `spec/models/child_profile_spec.rb` — add `has_many :observations` test.

**Verify:** `bundle exec rspec spec/models/child_profile_spec.rb`
**Revert:** `git checkout -- app/models/child_profile.rb app/models/user.rb`

---

### Step 3 — Generate controller, add routes, and request specs

Nest observations under child_profiles in `config/routes.rb`:
```ruby
resources :child_profiles, controller: "spaces/child_profiles" do
  resources :observations, controller: "child_profiles/observations"
end
```

Generate the controller:
```
bin/rails generate controller ChildProfiles::Observations
```

Implement all 7 CRUD actions with full `before_action` chain and `authorize` in
every action. For `index`, build a dummy observation:
```ruby
@observation = @child_profile.observations.build
authorize @observation, :index?
@observations = policy_scope(Observation).where(child_profile: @child_profile)
                                         .active.order(observed_on: :desc)
```

For `destroy`: `@observation.update!(status: :archived)`.

Create `spec/requests/child_profiles/observations_spec.rb`. Cover:
- GET index, show, new, edit — happy path + authorization (no-role redirect)
- POST create — valid params creates observation with correct author; invalid re-renders
- PATCH update — valid params redirects; invalid re-renders
- DELETE destroy — sets status to archived, redirects to index

**Verify:** `bundle exec rspec spec/requests/child_profiles/`
**Revert:** `bin/rails destroy controller ChildProfiles::Observations` + revert routes

---

### Step 4 — Create ObservationPolicy and policy spec

Create `app/policies/observation_policy.rb` with `index?`, `show?`, `create?`,
`update?`, `destroy?`, and `Scope` class. Follow `ChildProfilePolicy` pattern exactly.

Create `spec/policies/observation_policy_spec.rb`. Test each action for:
owner (all true), caregiver (all true), collaborator (all true), user with no role
(all false).

**Verify:** `bundle exec rspec spec/policies/observation_policy_spec.rb`
**Revert:** `git checkout -- app/policies/ spec/policies/`

---

### Step 5 — Build views with daisyUI 5

Create all view templates in `app/views/child_profiles/observations/`.

Update `app/views/spaces/child_profiles/show.html.erb` to add a "Recent Observations"
section after the profile info card:
- Show `@child_profile.observations.active.order(observed_on: :desc).limit(3)`
- "View all observations" link
- "Log observation" button gated on `policy(@observation).create?`
- Pass `@observation = @child_profile.observations.build` from the `show` action
  in `Spaces::ChildProfilesController` for the policy check

**Note:** `Spaces::ChildProfilesController#show` will need `@observation` assigned
so the view can call `policy(@observation)`. Add to the `show` action:
```ruby
@observation = @child_profile.observations.build
```

**Verify:** Visual check in browser
**Revert:** `git checkout -- app/views/child_profiles/ app/views/spaces/child_profiles/show.html.erb`

---

### Step 6 — Run migration and full test suite

```
bin/rails db:migrate
bundle exec rspec
bundle exec rubocop
```

**Verify:** All examples pass, 0 offenses
**Revert:** `bin/rails db:rollback` if needed

---

### Step 7 — Manual QA in browser

1. Sign in as `admin@example.com / password123`
2. Navigate to Demo Family → child profile show page
3. Verify "Recent Observations" section with empty state and "Log observation" button
4. Click "Log observation" → fill in category, date, body → submit
5. Verify observation appears in Recent Observations on the child show page
6. Click "View all observations" → verify full list in reverse-chron order
7. Click an observation → verify detail page shows full body, category badge, author
8. Click "Edit" → change the body → save → verify update
9. Click "Archive" → confirm → verify observation disappears from active list
10. Test authorization: log out → log in as `user@example.com` → attempt
    `/spaces/:id/child_profiles/:id/observations` → verify redirect

**Verify:** All acceptance criteria pass
**Revert:** N/A (QA only)

---

## Status

- [ ] Step 1 — Generate Observation model + migration + factory + spec
- [ ] Step 2 — Add associations to ChildProfile + User, update specs
- [ ] Step 3 — Generate controller + routes + request specs
- [ ] Step 4 — Create ObservationPolicy + policy spec
- [ ] Step 5 — Build views with daisyUI 5
- [ ] Step 6 — Run migration + full test suite
- [ ] Step 7 — Manual QA

**Last updated:** 2026-03-24
**Handoff note:** Brief drafted but deferred to post-MVP. When activated, resolve the
three open questions (categories, edit policy, child show page layout) before Phase 3.
The full step-by-step plan remains valid for implementation.
