# AI Development Flow

A repeatable process for building features with AI assistance.
Designed to prevent code slop, preserve context between sessions,
and keep the codebase consistent.

---

## Principles

1. **Understand before building.** AI reads the brief and existing code before writing anything.
2. **Small verifiable steps.** Each step produces one testable behavior, not one file type.
3. **Gate on open questions.** If assumptions are unresolved, stop and clarify — do not guess.
4. **Artifacts over memory.** Decisions live in docs, not in chat history.
5. **Verify continuously.** Never accumulate broken state.

---

## The five phases

### Phase 1 — Feature Brief (Ask mode)

Before any code, create a feature brief in `docs/features/`.

Use the **full template** (`_template-full.md`) when the stage introduces
new models, controllers, migrations, policies, or routes.

Use the **light template** (`_template-light.md`) for config, seed data,
docs, UI copy, or refactoring stages.

The brief must reference `docs/features/_constraints.md` for app invariants.

**Gate rule:** If the "Open questions" section is non-empty, do not proceed
to Phase 3. Resolve questions first.

### Phase 2 — Design Review (Ask mode)

Ask the AI to review the brief against:
- `docs/ARCHITECTURE.md` — does the plan conflict with the domain model?
- `docs/CONVENTIONS.md` — does it follow coding and UI patterns?
- Existing code — are there patterns to reuse?

Revise the brief based on review feedback. This phase is cheap and
catches most problems before they become code.

### Phase 3 — Step-by-step Build (Agent mode)

Execute the brief one step at a time. Each step should be:

- **One testable behavior.** After this step, you can verify one new thing works.
- **Small enough to read in full.** If you can't review every changed line in
  under 2 minutes, the step is too big.
- **Committable.** Each step or small group of steps is a clean commit point.

#### Pre-flight check (step 0 of every stage)

Before any code changes, verify the foundation is clean:

```
bundle exec rspec          # green
bundle exec rubocop        # clean
bin/rails db:migrate:status # no pending migrations
git status                 # clean working tree or known changes only
```

If any of these fail, fix them before starting the stage.

#### Verification cadence

- **After each step:** Run targeted specs and rubocop on changed files.
- **At stage boundaries:** Run the full test suite and rubocop before committing.

#### Commit cadence

Commit at natural boundaries — after each step or logical group of steps.
Small commits make bad changes easy to identify and revert.

#### Revert plan

For each step, know the rollback:
- Migration: `bin/rails db:rollback`
- Seed data: re-seed or manual console cleanup
- Code changes: `git checkout -- <files>`
- Generator output: `bin/rails destroy <generator> <args>`

### Phase 4 — Post-build Audit (Ask mode)

After the stage is complete, switch to Ask mode and audit:

- Does every controller action call `authorize`?
- Are there N+1 queries?
- Do views follow daisyUI 5 patterns from `CONVENTIONS.md`?
- Are edge cases handled (empty states, unauthorized access, missing records)?
- Do specs cover the acceptance criteria from the brief?

Fix anything found before moving on.

### Phase 5 — Update Docs

- Update `docs/ARCHITECTURE.md` **only** if the domain model changed
  (new models, changed associations, new architectural patterns).
- Update the feature brief's `## Status` section with what was completed.
- Do not dump feature details into `ARCHITECTURE.md` — keep briefs in
  `docs/features/` as historical records.

---

## Session workflow

### Starting a session

1. AI reads `docs/AGENTS.md` (stack, key files, constraints).
2. AI reads the current feature brief from `docs/features/`.
3. You tell it which step you're on.
4. AI runs the pre-flight check.

### During a session

5. AI executes one step at a time in Agent mode.
6. You verify after each step.
7. Commit at natural boundaries.

### Ending a session

8. Update the brief's `## Status` section with progress.
9. Update `docs/ARCHITECTURE.md` if the domain model changed.
10. Commit doc changes.

---

## Brief tiers

| Tier | When to use | Template |
|------|------------|---------|
| **Full** | New models, controllers, policies, migrations, routes | `_template-full.md` |
| **Light** | Config, seeds, docs, UI copy, refactoring | `_template-light.md` |

Gate rule for choosing: if the change touches a migration, controller,
or policy, it gets a full brief. Everything else gets a light brief.

---

## Anti-slop rules

1. Never ask AI to build an entire feature in one prompt.
2. Always read generated code before accepting.
3. Prefer Rails generators — they produce conventional code.
4. Run targeted verification after every step; full suite at stage boundaries.
5. Keep `ARCHITECTURE.md` current when the domain model changes.
6. Use Ask mode for planning and review; Agent mode for execution only.
7. Never let AI skip verification. Every step has a check, even if it's not a spec.
8. If unsure, ask before building. A 30-second question costs nothing.
9. Every brief must have an empty "Open questions" section before building starts.
10. Every controller action must call `authorize` (Pundit).
