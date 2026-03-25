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
- **caregiver** — same as owner except `create_space`, `update_space`,
  `delete_space`, and `manage_collaborators` are `"false"`.
- **collaborator** — read-only for child data, can create observations
  and assessments. No user/space management.

Also update the default Space seed to use the name "Demo Family" instead
of "Default Space", and wire the admin user into that space with the
`owner` role.

### 3. Rename "Space" to "Family" in user-facing UI text

Files to change (labels only, not code identifiers):

- `app/views/shared/_user_menu.html.erb` — "Spaces" link text → "Families"
- `app/views/spaces/index.html.erb` — page heading
- `app/views/spaces/new.html.erb` — page heading, form labels
- `app/views/spaces/show.html.erb` — page heading
- `app/views/spaces/edit.html.erb` — page heading, form labels
- `app/views/spaces/_form.html.erb` — field labels

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

## Open questions

- None

## Steps

### Step 1 — Expand `Role::AVAILABLE_PERMISSIONS`

Add child-related permission keys to `app/models/role.rb`.
Update `spec/models/role_spec.rb` if it tests the permissions list.

**Verify:** `bundle exec rspec spec/models/role_spec.rb`
**Revert:** `git checkout -- app/models/role.rb spec/models/role_spec.rb`

### Step 2 — Seed domain roles and update default space

Update `db/seeds.rb` to create three common roles (owner, caregiver,
collaborator) with permissions, rename "Default Space" to "Demo Family",
and assign admin user the owner role in that space.

**Verify:** `bin/rails db:seed` runs without error; verify in console:
`Roles::Common.pluck(:name)` returns `["owner", "caregiver", "collaborator"]`
**Revert:** `git checkout -- db/seeds.rb` then re-seed

### Step 3 — Rename "Space" → "Family" in UI labels

Change user-facing text in the view files listed above.
Do not change any Ruby identifiers, routes, or class names.

**Verify:** `bundle exec rspec spec/` (full suite — view specs may reference text);
visual check in browser.
**Revert:** `git checkout -- app/views/`

### Step 4 — Update `docs/ARCHITECTURE.md`

Add a new "Planned domain model" section with the Anchor app models,
associations, and role structure designed in this planning session.

**Verify:** Read the doc; confirm it's accurate and consistent with briefs.
**Revert:** `git checkout -- docs/ARCHITECTURE.md`

---

## Status

- [ ] Step 1 — Expand permissions
- [ ] Step 2 — Seed domain roles
- [ ] Step 3 — UI label rename
- [ ] Step 4 — Update architecture docs

**Last updated:** 2026-03-24
**Handoff note:** Brief created. Ready for Phase 2 (design review) then
Phase 3 (build).
