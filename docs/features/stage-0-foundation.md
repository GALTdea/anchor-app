# Stage 0 — Foundation Cleanup

> Light brief. No new models, migrations, controllers, or routes.

---

## Goal

Prepare the existing template's roles, permissions, and UI labels for the
Anchor app domain (autism care-circle) without changing the database schema.

## Changes

### 1. Expand `Role::AVAILABLE_PERMISSIONS` with child-related permission keys

File: `app/models/role.rb`

Add these permission keys to the `AVAILABLE_PERMISSIONS` array so they're
available for role definitions in later stages:

```
create_child_profile
read_child_profile
update_child_profile
delete_child_profile
create_observation
read_observation
update_observation
delete_observation
create_assessment
read_assessment
update_assessment
delete_assessment
manage_collaborators
```

The existing user/space permissions stay. These are additive.

### 2. Seed domain-specific common roles

File: `db/seeds.rb`

Add three common roles (global, `space_id: nil`) with appropriate
permissions. These replace the template's generic setup:

- **owner** — full access. All permissions set to `"true"`.
  `value: "owner"` for machine-readable lookup.
- **caregiver** — same as owner except `create_space`, `update_space`,
  `delete_space`, and `manage_collaborators` are `"false"`.
  `value: "caregiver"`.
- **collaborator** — read-only for child data, can create observations
  and assessments. No user/space management.
  `value: "collaborator"`.

Use `Roles::Common.find_or_create_by!(name: "owner")` (and similar) to
keep seeds idempotent. Store the machine-readable identifier in the
`value` column so display names can change later without breaking lookups.

Also update the default Space seed to use the name "Demo Family" instead
of "Default Space", and wire the admin user into that space with the
`owner` role.

**Ordering matters:** Create roles first, then the Space, then the
UserRole that links the admin user to the space with the owner role.

### 3. Rename "Space" to "Family" in user-facing UI text

Only change the one view that is already rebuilt in daisyUI 5:

- `app/views/shared/_user_menu.html.erb` — "Spaces" link text → "Families"

**Do NOT touch** the `app/views/spaces/` directory. Those 11 files are
still Bootstrap/Tabler (see `docs/AGENTS.md` "Deferred views") and need
a full rebuild in daisyUI 5 before any label work makes sense. The
`show.html.erb` alone is ~1,870 lines of Tabler demo content that will
be entirely replaced when we build the family dashboard.

Relabeling the spaces views is deferred to a separate "rebuild spaces
views in daisyUI 5" step (not part of this stage).

Do NOT rename the `Space` model, `spaces` table, routes, controllers,
or any Ruby identifiers. This is a UI-text-only change.

### 4. Update `docs/ARCHITECTURE.md` with planned domain model

Add a new section documenting the planned Anchor app domain model
(ChildProfile, ChildAccess, Assessment, Observation, etc.) so future
sessions have the full picture.

## Constraints / Invariants

- [ ] No new migrations
- [ ] No new models or controllers
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean
- [ ] daisyUI 5 classes only in any view changes
- [ ] `authorize` on every controller action (no controller changes, so N/A)

## Out of scope

- No `ChildProfile` model yet (Stage 1)
- No `ChildAccess` model (Stage 5)
- No new controllers or routes
- No changes to authentication flow
- No billing changes
- No rebuild of `app/views/spaces/` (still Bootstrap/Tabler — deferred)

## Open questions

- None

## Steps

### Step 1 — Expand `Role::AVAILABLE_PERMISSIONS`

Add child-related permission keys to `app/models/role.rb`.
Update `spec/models/role_spec.rb` if it tests the permissions list.

**Verify:** `bundle exec rspec spec/models/role_spec.rb`
**Revert:** `git checkout -- app/models/role.rb spec/models/role_spec.rb`

### Step 2 — Seed domain roles and update default space

Update `db/seeds.rb` to:
1. Create three common roles (owner, caregiver, collaborator) using
   `Roles::Common.find_or_create_by!(name: ...)` with `value` set for
   machine-readable lookup.
2. Rename "Default Space" to "Demo Family".
3. Wire the admin user into that space with the owner role via UserRole.

Order: roles → space → user role.

**Verify:** `bin/rails db:seed` runs without error; verify in console:
`Roles::Common.pluck(:name, :value)` returns the three roles.
**Revert:** `git checkout -- db/seeds.rb` then re-seed

### Step 3 — Rename "Spaces" → "Families" in user menu

Change only the link text in `app/views/shared/_user_menu.html.erb`.
Do not touch any `app/views/spaces/` files (Bootstrap/Tabler, deferred).
Do not change any Ruby identifiers, routes, or class names.

**Verify:** `bundle exec rspec spec/` (full suite — no specs assert on
menu link text, but run to confirm nothing broke); visual check in browser.
**Revert:** `git checkout -- app/views/shared/_user_menu.html.erb`

### Step 4 — Update `docs/ARCHITECTURE.md`

Add a new "Planned domain model" section with the Anchor app models,
associations, and role structure designed in this planning session.

**Verify:** Read the doc; confirm it's accurate and consistent with briefs.
**Revert:** `git checkout -- docs/ARCHITECTURE.md`

---

## Status

- [x] Step 1 — Expand permissions
- [x] Step 2 — Seed domain roles
- [x] Step 3 — User menu label rename
- [x] Step 4 — Update architecture docs

**Last updated:** 2026-03-24
**Handoff note:** Stage 0 complete. All 4 steps done. RSpec 102/0,
RuboCop 0 offenses. Seed needs `bin/rails db:seed` run manually to
verify in dev. Next: Stage 1 (ChildProfile + single-guardian flow).
