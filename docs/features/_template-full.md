# [Stage N] — [Feature Name]

> Use this template when the stage introduces new models, controllers,
> migrations, policies, or routes. For lighter changes, use `_template-light.md`.

---

## Goal

One sentence: what does this stage accomplish?

## User value

Who benefits and how? What can they do after this that they couldn't before?

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

List only the constraints relevant to this stage:
- [ ] ...
- [ ] ...

## Reference implementation

Which existing model, controller, or view pattern should this stage imitate?
Cite specific files.

- Model pattern: `app/models/...`
- Controller pattern: `app/controllers/...`
- View pattern: `app/views/...`
- Policy pattern: `app/policies/...`

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| ... | ... | ... | ... |

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| ... | ... | ... |

### Seed data

Describe any new seed records.

## Routes and controllers

```
# Proposed route additions
resources :example do
  ...
end
```

| Controller | Actions | Notes |
|-----------|---------|-------|
| ... | ... | ... |

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|-------------|
| ... | ... | ... |

## UI

- **Layout:** dashboard / application / devise
- **Turbo:** frames / streams / neither
- **New views:** list new templates
- **Changed views:** list modified templates

## Acceptance criteria

- [ ] ...
- [ ] ...
- [ ] ...

## Out of scope

- ...
- ...

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Steps

### Step 1 — [description]

What changes. What to verify.

**Verify:** `bundle exec rspec spec/... `
**Revert:** `...`

### Step 2 — [description]

...

---

## Status

- [ ] Step 1
- [ ] Step 2
- [ ] ...

**Last updated:** YYYY-MM-DD
**Handoff note:** What's done, what's next, what was decided.
