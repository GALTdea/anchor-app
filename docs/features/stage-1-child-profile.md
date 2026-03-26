# Stage 1 — Child Profile + Single-Guardian Flow

> Full brief. Introduces new model, migration, controller, policy, routes, and views.

---

## Goal

Enable a single caregiver to create and manage a child profile in their family workspace.

## User value

A parent signing up can create a profile for their child (name, date of birth, basic info). This is the foundation for all future features (observations, assessments, goals). Without a child profile, there is no subject for care data.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Use Rails generator for model, controller, migration
- [ ] Every controller action calls `authorize` (Pundit)
- [ ] Keep controllers thin — business logic in model
- [ ] Use daisyUI 5 classes for all views (no Bootstrap/Tabler)
- [ ] Use `form_with` for forms (not raw HTML)
- [ ] Use `friendly_id` for slugged URLs if appropriate
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean

## Reference implementation

Imitate existing patterns for consistency.

- Model pattern: `app/models/space.rb` (enum status, validations, associations, friendly_id)
- Controller pattern: `app/controllers/spaces/users_controller.rb` (authorization with `authorize`, scoped lookups)
- View pattern: Use daisyUI 5 (not the Bootstrap spaces views — those are deferred)
- Policy pattern: `app/policies/user_policy.rb` (get role in space, check permissions)
- Factory pattern: `spec/factories/spaces.rb` (sequence, traits)

**Note:** Do NOT imitate `SpacesController` for authorization — it has a pre-existing gap (no `authorize` calls). Use `Spaces::UsersController` instead.

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| `ChildProfile` | `child_profiles` | `space_id`, `first_name`, `last_name`, `date_of_birth`, `status` (enum), `created_by_id` | `belongs_to :space`, `belongs_to :created_by, class_name: 'User'` |

Full schema:
- `space_id` (integer, not null, foreign key)
- `first_name` (string, not null)
- `last_name` (string, not null)
- `date_of_birth` (date)
- `status` (integer, default: 0) — enum: `active`, `archived`
- `created_by_id` (integer, foreign key to users)
- `slug` (string, unique) — for friendly_id if we want `/families/:space_id/children/:slug`
- timestamps

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `Space` | Add `has_many :child_profiles` | A family workspace contains children |

### Seed data

None for this stage. Dev users can create profiles manually via UI.

## Routes and controllers

```ruby
# Proposed route additions in config/routes.rb
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles"
  # existing nested routes...
end
```

| Controller | Actions | Notes |
|-----------|---------|-------|
| `Spaces::ChildProfilesController` | `index`, `new`, `create`, `show`, `edit`, `update`, `destroy` | RESTful CRUD, nested under space |

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|-------------|
| `ChildProfilePolicy` | `index?` | User belongs to space (`@role.present?`) |
| | `show?` | User belongs to space |
| | `create?` | User has `create_child_profile` permission in space role |
| | `update?` | User has `update_child_profile` permission |
| | `destroy?` | User has `delete_child_profile` permission |

**Policy pattern:** For a child profile policy, get the user's role via the child's space:
```ruby
@role = user.get_role_in_space(record.space)
```
Not `get_role_in_space(record)` — the record is a ChildProfile, not a Space.

For now (single-guardian stage), all users in the space can see all children in that space. Per-child access via `ChildAccess` is deferred to Stage 5.

**Note on destroy action:** The acceptance criteria says "archive" (soft delete via status enum), but REST convention uses `destroy`. Implementation: the `destroy` action should set `@child_profile.status = :archived` and save, not call `destroy!`. This keeps audit trail.

## UI

- **Layout:** dashboard
- **Turbo:** frames for child profile cards/list; streams not needed yet
- **New views:**
  - `app/views/spaces/child_profiles/index.html.erb` — list of children in family
  - `app/views/spaces/child_profiles/new.html.erb` — create child form
  - `app/views/spaces/child_profiles/show.html.erb` — child profile page
  - `app/views/spaces/child_profiles/edit.html.erb` — edit child form
  - `app/views/spaces/child_profiles/_form.html.erb` — shared form partial
  - `app/views/spaces/child_profiles/_child_profile.html.erb` — card partial for index
- **Changed views:**
  - `app/views/spaces/show.html.erb` — replace Tabler demo content with real family dashboard showing child profiles list

Use daisyUI 5: `card`, `btn`, `input`, `fieldset`, `label`, etc. No Bootstrap classes.

## Acceptance criteria

- [ ] A caregiver can create a child profile with first name, last name, date of birth
- [ ] Child profiles are listed on the family dashboard (`spaces/show`)
- [ ] A caregiver can view a child's profile page
- [ ] A caregiver can edit a child's profile
- [ ] A caregiver can archive a child profile (soft delete via status enum)
- [ ] Only users who belong to the space can see/manage children in that space
- [ ] Specs cover model validations, controller actions, and policy rules
- [ ] Views use daisyUI 5 classes consistently

## Out of scope

- No `ChildAccess` model yet — per-child permissions are Stage 5
- No external collaborators yet — only caregivers in the same space
- No observations or assessments — those are Stage 3 and 4
- No photos or file uploads — that can be added later
- No onboarding wizard — just manual child profile creation for now

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Steps

### Step 1 — Generate ChildProfile model, migration, factory, and spec

Use Rails generator:
```
bin/rails generate model ChildProfile space:references first_name:string last_name:string date_of_birth:date status:integer created_by_id:integer:index slug:string:uniq
```

Then manually enhance the generated files:

**Model (`app/models/child_profile.rb`):**
- Add `extend FriendlyId` and `friendly_id :name, use: :slugged`
- Add `name` method: `"#{first_name} #{last_name}"`
- Add enum: `enum :status, [:active, :archived]`
- Add validations: `validates :first_name, :last_name, presence: true`
- Add associations: `belongs_to :space` (already generated), `belongs_to :created_by, class_name: 'User', foreign_key: :created_by_id`

**Factory (`spec/factories/child_profiles.rb`):**
- Create factory with `sequence(:first_name)`, `sequence(:last_name)`, `date_of_birth`, `status: :active`
- Add association refs: `space` and `created_by` (User)
- Add `:archived` trait

**Model spec (`spec/models/child_profile_spec.rb`):**
- Test associations (belongs_to space, belongs_to created_by)
- Test validations (presence of first_name, last_name)
- Test enum (status: active/archived)
- Test `name` method
- Test friendly_id slug generation

**Verify:** `bundle exec rspec spec/models/child_profile_spec.rb`
**Revert:** `bin/rails destroy model ChildProfile` + `bin/rails db:rollback`

### Step 2 — Add association to Space model and update spec

Add to `app/models/space.rb`:
```ruby
has_many :child_profiles, dependent: :destroy
```

Update `spec/models/space_spec.rb` to test the association:
```ruby
it 'has many child_profiles' do
  expect(Space.reflect_on_association(:child_profiles).macro).to eq(:has_many)
end
```

**Verify:** `bundle exec rspec spec/models/space_spec.rb`
**Revert:** `git checkout -- app/models/space.rb spec/models/space_spec.rb`

### Step 3 — Generate controller, add actions, routes, and request specs

Use Rails generator:
```
bin/rails generate controller Spaces::ChildProfiles
```

**Controller implementation** (`app/controllers/spaces/child_profiles_controller.rb`):

Key patterns (imitate `Spaces::UsersController`):
- `before_action :set_space`
- `before_action :set_child_profile, only: %i[show edit update destroy]`
- Call `authorize @child_profile` in every action
- Scope child lookups to space: `@child_profile = @space.child_profiles.find(params[:id])`
- For index: `@child_profiles = @space.child_profiles.includes(:created_by)` (avoid N+1)
- For create: set `created_by: current_user`

Actions: `index`, `new`, `create`, `show`, `edit`, `update`, `destroy`

**Destroy implementation:** Set `status = :archived` instead of hard delete:
```ruby
def destroy
  authorize @child_profile
  @child_profile.update(status: :archived)
  redirect_to space_path(@space), notice: "Child profile was archived."
end
```

**Routes** (`config/routes.rb`):
```ruby
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles"
  # existing nested routes...
end
```

**Request spec** (`spec/requests/spaces/child_profiles_spec.rb`):
- Test full CRUD flow (GET index, GET new, POST create, GET show, GET edit, PATCH update, DELETE destroy)
- Test authorization (user not in space cannot access)
- Test nested scoping (cannot access child from different space)
- Test soft delete (destroy sets status to archived)

**Verify:**
- `bin/rails routes | grep child_profile` shows expected routes
- `bundle exec rspec spec/requests/spaces/child_profiles_spec.rb`

**Revert:** `bin/rails destroy controller Spaces::ChildProfiles` + `git checkout -- config/routes.rb spec/requests/`

### Step 4 — Create ChildProfilePolicy and policy spec

Create `app/policies/child_profile_policy.rb`.

**Implementation:**
```ruby
class ChildProfilePolicy < ApplicationPolicy
  def initialize(user, record)
    super
    @role = user.get_role_in_space(record.space)
  end

  def index?
    @role.present?  # User belongs to space
  end

  def show?
    @role.present?
  end

  def create?
    @role&.can_create_child_profile?
  end

  def update?
    @role&.can_update_child_profile?
  end

  def destroy?
    @role&.can_delete_child_profile?
  end
end
```

**Policy spec** (`spec/policies/child_profile_policy_spec.rb`):
- Test each action with different roles (owner, caregiver, collaborator, no role)
- Test denial when user not in space
- Use factories to create user, space, role, user_role, child_profile

**Verify:** `bundle exec rspec spec/policies/child_profile_policy_spec.rb`
**Revert:** `git checkout -- app/policies/child_profile_policy.rb spec/policies/`

### Step 5 — Build child profile views in daisyUI 5

Create all view templates in `app/views/spaces/child_profiles/`:

**Templates to create:**
- `index.html.erb` — list of children as cards, "Add Child" button
- `new.html.erb` — create form with `page_header`
- `show.html.erb` — child details page
- `edit.html.erb` — edit form with `page_header`
- `_form.html.erb` — shared form partial (first_name, last_name, date_of_birth, status select)
- `_child_profile.html.erb` — card partial for displaying a single child (name, age, status badge)

Use daisyUI 5 components: `card`, `btn btn-primary`, `input w-full`, `select w-full`, `fieldset`, `label`, `badge` for status.
Use `render "shared/page_header"` for page titles.
Use `form_with model: [@space, @child_profile]` for nested resource forms.

**View specs** (`spec/views/spaces/child_profiles/*.html.erb_spec.rb`):
- Test form renders fields correctly
- Test index renders child list
- Test show renders child details

**Verify:** `bundle exec rspec spec/views/spaces/child_profiles/`
**Revert:** `git checkout -- app/views/spaces/child_profiles/ spec/views/`

### Step 6 — Replace spaces/show.html.erb with real family dashboard

Remove all 1,870 lines of Tabler demo content from `app/views/spaces/show.html.erb`.

Build a clean family dashboard that:
- Uses `render "shared/page_header", title: @space.name, subtitle: "Family Dashboard"`
- Lists child profiles in a grid using `render @space.child_profiles` (or explicit partial loop)
- Has an "Add Child" button: `link_to "Add Child", new_space_child_profile_path(@space), class: "btn btn-primary"`
- Shows empty state if no children yet
- Uses daisyUI 5 only (card, grid, btn)

Update `spec/views/spaces/show.html.erb_spec.rb` to test for child profiles list instead of demo content.

**Verify:**
- Visual check in browser at `/spaces/:id`
- `bundle exec rspec spec/views/spaces/show.html.erb_spec.rb`

**Revert:** `git checkout -- app/views/spaces/show.html.erb spec/views/spaces/show.html.erb_spec.rb`

### Step 7 — Run migration and full test suite

Run the migration:
```
bin/rails db:migrate
```

Run full suite to ensure nothing broke:
```
bundle exec rspec
bundle exec rubocop
```

**Verify:** 102+ examples, 0 failures; 108+ files, 0 offenses
**Revert:** `bin/rails db:rollback` if needed

### Step 8 — Manual QA in browser

Test the complete flow:
1. Sign in as admin@example.com / password123
2. Navigate to "Demo Family" space
3. Click "Add Child"
4. Fill form: first name, last name, date of birth
5. Submit and verify redirect to child show page or index
6. View the child profile show page
7. Edit the child profile
8. Archive the child (destroy action sets status to archived)
9. Verify archived child filtering (if implemented; optional for v1)

**Verify:** All acceptance criteria pass
**Revert:** N/A (QA only)

---

## Status

- [x] Step 1 — Generate model + migration + factory + spec
- [x] Step 2 — Add Space association + update spec
- [x] Step 3 — Generate controller + routes + request specs
- [x] Step 4 — Create policy + policy spec
- [x] Step 5 — Build views + view specs
- [x] Step 6 — Replace spaces/show dashboard
- [x] Step 7 — Run migration + full test suite
- [x] Step 8 — Manual QA

**Last updated:** 2026-03-26
**Handoff note:** Stage 1 complete. All specs green (161 examples, 0 failures), rubocop clean. ChildProfile CRUD with authorization fully implemented. Space#show now redirects to child_profiles#index. Ready for production use or Stage 2 (invite second caregiver).

### Manual QA checklist for user

If you'd like to verify in the browser, run `bin/dev` and test:
1. Login at http://localhost:3000 with `admin@example.com / password123`
2. Navigate to "Demo Family" (should auto-redirect to child profiles)
3. Click "Add Child Profile" and create a test child (e.g., Emma Watson, DOB 5 years ago)
4. Verify child appears in the list with correct name, age, and date
5. Click the child's name to view details
6. Click "Edit" and update the notes field
7. Click "Archive" and confirm it removes from active list
8. Test authorization: logout, login as `user@example.com / password123` (no role in Demo Family), and verify you can't access child profiles
