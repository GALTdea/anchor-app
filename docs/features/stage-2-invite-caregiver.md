# Stage 2 — Invite a Caregiver

> **Status: DEFERRED — Post-MVP**
> This feature is documented for future implementation. It will not be built until
> after the MVP is complete. The current MVP target is **Stage 1 (child profiles) +
> Stage 4 (assessments)**; Stages 2 and 3 are deferred. Do not start Phase 3 (Build)
> until this deferral is lifted.

> Full brief. No new models or migrations. Fixes authorization gaps in an existing
> controller, adds missing policy actions, rebuilds Bootstrap/Tabler views to
> daisyUI 5, and adds full test coverage.

---

## Goal

Enable a space owner or caregiver to invite another adult into their family workspace
by email, and manage that person's role once they have joined.

## User value

A parent who has set up the family workspace can invite a co-parent, grandparent, or
other caregiver by email. The invitee receives an email with a sign-up link (Devise
Invitable), sets their password, and lands in the workspace with the assigned role.
The owner can later change that person's role or remove them from the workspace.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action calls `authorize` (Pundit)
- [ ] Keep controllers thin — no business logic
- [ ] Use daisyUI 5 classes for all views (no Bootstrap/Tabler)
- [ ] Use `form_with` for forms
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean

## Reference implementation

- Controller pattern: `app/controllers/spaces/child_profiles_controller.rb`
  (thin actions, `before_action` for setup, `authorize` in every action)
- Policy pattern: `app/policies/child_profile_policy.rb`
  (get role via space, check permission method)
- View pattern: `app/views/spaces/child_profiles/` (daisyUI 5 card + table layout)
- Factory pattern: `spec/factories/user_roles.rb` (association-based)

**Note:** Do NOT imitate the existing `Spaces::UsersController` views — they use
Bootstrap/Tabler. The existing controller logic for `create`/`update`/`destroy` is
sound; only the missing `authorize` calls and views need fixing.

## Domain changes

### New models

None.

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `UserPolicy` | Add `index?`, `new?` | `index` and `new` controller actions currently call no policy method — these are needed for `authorize @space, policy_class: UserPolicy` to work |

### Seed data

None. `user@example.com` already exists as an uninvited user who can be used for
testing "user with no role in this space."

## Routes and controllers

Routes are already in place — no changes needed:

```ruby
resources :spaces do
  resources :users, only: %i[index new create edit update destroy],
    controller: "spaces/users"
  # ...
end
```

| Controller | Action | Current state | Work needed |
|-----------|--------|---------------|-------------|
| `Spaces::UsersController` | `index` | No `authorize` call | Add `authorize @space, policy_class: UserPolicy` |
| | `new` | No `authorize` call | Add `authorize @space, policy_class: UserPolicy` |
| | `create` | ✅ Has `authorize` | None |
| | `edit` | No `authorize` call | Add `authorize @space, policy_class: UserPolicy` |
| | `update` | ✅ Has `authorize` | None |
| | `destroy` | ✅ Has `authorize` | None |

**How the invite works (already implemented, do not change):**

```ruby
# Spaces::UsersController#create
user = User.find_by(email: params[:email]) || User.invite!(email: params[:email])
UserRole.create(user:, space: @space, role_id: params[:role_id])
```

`User.invite!` is from Devise Invitable. It creates the user record and sends an
invitation email. The invitee follows the link, sets a password, and is signed in.
No custom mailer needed.

## Authorization

| Policy | Action | Rule |
|--------|--------|------|
| `UserPolicy` | `index?` | `@role&.can_read_user?` |
| | `new?` | `create?` (delegate) |
| | `create?` | `@role&.can_create_user?` |
| | `update?` | `@role&.can_update_user?` |
| | `destroy?` | `@role&.can_delete_user?` |

`UserPolicy#initialize` already receives a `Space` as `record` (passed as
`authorize @space, policy_class: UserPolicy`). This is intentional — the policy
asks "can this user manage users **in this space**?" Keep that pattern.

Role permission check:
- **Owner** — `can_read_user?` ✅, `can_create_user?` ✅, `can_update_user?` ✅, `can_delete_user?` ✅
- **Caregiver** — same as owner for user permissions (only `manage_collaborators` is false)
- **Collaborator** — `can_create_user?` ❌, `can_update_user?` ❌, `can_delete_user?` ❌, but `can_read_user?` ✅

## UI

- **Layout:** dashboard
- **Turbo:** neither (standard full-page navigation is fine for this stage)
- **New views:** none
- **Changed views (full daisyUI 5 rewrite):**
  - `app/views/spaces/users/index.html.erb` — member list with role badge, invite + edit + remove actions
  - `app/views/spaces/users/new.html.erb` — invite form (email + role select)
  - `app/views/spaces/users/edit.html.erb` — change role form
  - `app/views/spaces/users/_new_form.html.erb` — shared invite form partial
  - `app/views/spaces/users/_edit_form.html.erb` — shared edit-role form partial

**Index view** should show: avatar initials, name, email, role badge, status badge,
and action buttons (Edit role, Remove). Show "Invite member" button gated on
`policy(@space, policy_class: UserPolicy).create?`. Empty state if space has no users.

**New/invite form** fields: `email` (text, required), `role_id` (select from
`@space.all_roles`). Cancel button returns to index.

**Edit form** fields: `role_id` select only (you cannot change email). Cancel button
returns to index.

Use `render "shared/page_header"` for page titles. Use daisyUI 5 `card`, `table`,
`btn`, `input`, `select`, `badge`, `avatar` components. No Bootstrap classes.

## Acceptance criteria

- [ ] A space owner or caregiver can invite a new user by email from the members list
- [ ] Inviting an already-registered email adds them to the space without re-sending
      an invitation (existing `User.find_by(email:)` logic handles this)
- [ ] The invite form shows a role selector populated with the space's available roles
- [ ] A space owner or caregiver can change a member's role
- [ ] A space owner or caregiver can remove a member from the space
- [ ] A collaborator cannot access the invite or edit-role pages (policy blocks them)
- [ ] A user with no role in the space cannot access any users pages
- [ ] All views use daisyUI 5 classes — no Bootstrap or Tabler classes remain
- [ ] All controller actions call `authorize`
- [ ] Request specs cover all six actions (index, new, create, edit, update, destroy)
- [ ] Policy spec covers all five policy methods across all three roles

## Out of scope

- Custom invitation email template — Devise Invitable default is sufficient for now
- Invitation tracking UI (pending invites list) — Stage 6 or later
- `manage_collaborators` permission enforcement — the permission exists in seeds but
  is not yet wired to a policy check; leave for Stage 5 (external collaborators)
- Per-child access control (`ChildAccess`) — Stage 5

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Steps

### Step 1 — Add missing policy methods to `UserPolicy` and add policy spec

Add `index?` and `new?` to `app/policies/user_policy.rb`:

```ruby
def index?
  @role&.can_read_user?
end

def new?
  create?
end
```

Create `spec/policies/user_policy_spec.rb`. Test each method for:
- owner (all true)
- caregiver (read/create/update/delete user all true, same as owner for this policy)
- collaborator (index true, create/update/destroy false)
- user with no role in space (all false — `@role` is nil)

**Verify:** `bundle exec rspec spec/policies/user_policy_spec.rb`
**Revert:** `git checkout -- app/policies/user_policy.rb spec/policies/`

---

### Step 2 — Add `authorize` to `index`, `new`, `edit` in `Spaces::UsersController`

Add to each action:

```ruby
def index
  authorize @space, policy_class: UserPolicy
  @users = @space.users.page params[:page]
end

def new
  authorize @space, policy_class: UserPolicy
  @space_roles = @space.all_roles
end

def edit
  authorize @space, policy_class: UserPolicy
  @space_roles = @space.all_roles
end
```

**Verify:** `bundle exec rspec` (existing suite stays green)
**Revert:** `git checkout -- app/controllers/spaces/users_controller.rb`

---

### Step 3 — Rebuild views with daisyUI 5

Replace all five files in `app/views/spaces/users/`:

**`index.html.erb`** — render `shared/page_header` with "Family Members" title.
Table with columns: Member (avatar + name + email), Role (badge), Status (badge),
Actions (Edit role, Remove buttons). Gate "Invite member" button on
`policy(@space, policy_class: UserPolicy).create?`. Empty state if `@users.empty?`.

**`new.html.erb`** — render `shared/page_header` "Invite a Member", then render
`_new_form`.

**`_new_form.html.erb`** — `form_with url: space_users_path(@space), method: :post`.
Fields: email input, role select (`@space_roles`). Submit "Send Invitation". Cancel
link to `space_users_path(@space)`.

**`edit.html.erb`** — render `shared/page_header` "Edit Member Role", then render
`_edit_form`.

**`_edit_form.html.erb`** — `form_with model: @user_role, url: space_user_path(@space, @user), method: :patch`.
Fields: role select only. Submit "Update Role". Cancel link to `space_users_path(@space)`.

Use daisyUI 5 only: `card`, `card-body`, `table table-zebra`, `btn btn-primary`,
`btn-ghost`, `btn-sm`, `input input-bordered`, `select select-bordered`,
`badge`, `avatar`. Use `render "shared/page_header"`.

**Verify:** Visual check in browser (no layout breakage)
**Revert:** `git checkout -- app/views/spaces/users/`

---

### Step 4 — Add request specs for `Spaces::UsersController`

Create `spec/requests/spaces/users_spec.rb`. Cover:

- `GET /spaces/:id/users` (index) — owner sees list; collaborator is redirected
- `GET /spaces/:id/users/new` — owner sees form; collaborator is redirected
- `POST /spaces/:id/users` (create) — owner invites new email → creates user + user_role
- `POST /spaces/:id/users` (create) — owner invites existing email → adds user_role
- `GET /spaces/:id/users/:id/edit` — owner sees role form
- `PATCH /spaces/:id/users/:id` (update) — owner changes role → redirects to index
- `DELETE /spaces/:id/users/:id` (destroy) — owner removes member → redirects to index
- Authorization: user with no role in space gets redirected on all actions

Use `User.invite_accepted_or_not_invited` or create user via factory (do not use
`User.invite!` in specs — use factory `:user` with `invitation_accepted_at`
preset or a confirmed user).

**Verify:** `bundle exec rspec spec/requests/spaces/users_spec.rb`
**Revert:** `git checkout -- spec/requests/spaces/`

---

### Step 5 — Run full test suite + RuboCop

```
bundle exec rspec
bundle exec rubocop
```

**Verify:** All examples pass, 0 offenses
**Revert:** N/A

---

### Step 6 — Manual QA in browser

1. Sign in as `admin@example.com / password123`
2. Navigate to Demo Family → Members (or `/spaces/:id/users`)
3. Click "Invite member" → enter a new email + pick role → submit
4. Verify flash notice and new row in table
5. Click "Edit role" → change to a different role → save
6. Click "Remove" → confirm removal → verify row disappears
7. Sign out, sign in as `user@example.com / password123` (no role in Demo Family)
8. Navigate to `/spaces/:id/users` → verify redirect or 403

**Verify:** All acceptance criteria pass visually
**Revert:** N/A (QA only)

---

## Status

- [ ] Step 1 — Add `index?` and `new?` to `UserPolicy` + policy spec
- [ ] Step 2 — Add `authorize` to `index`, `new`, `edit` actions
- [ ] Step 3 — Rebuild views with daisyUI 5
- [ ] Step 4 — Add request specs
- [ ] Step 5 — Run full test suite + RuboCop
- [ ] Step 6 — Manual QA

**Last updated:** 2026-03-24
**Handoff note:** Brief drafted but deferred to post-MVP. The invite infrastructure
(Devise Invitable, `User.invite!`, routes, `UserRole` creation) already exists and
works. When this stage is activated, the work is: fix authorization gaps in the
controller (index/new/edit missing `authorize`), add `index?`/`new?` to `UserPolicy`,
rebuild all five user views to daisyUI 5, and add request + policy specs.
