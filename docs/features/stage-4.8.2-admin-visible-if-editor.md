# Stage 4.8.2 — Admin editor: authoring `visible_if` branching

> Light brief. Completes the deferred Step 8 of
> `stage-4.8-adaptive-branching.md`.
> No new models, routes, policies, or migrations. Model normalization + admin
> view changes only, plus targeted model and request specs.
>
> Purpose: let non-engineers author and edit `visible_if` predicates from the
> admin template editor, closing the current gap that forces every branching
> change to go through seeds + a deploy.

---

## Goal

Enable admins to add, edit, and remove `visible_if` predicates on both
questions and sections directly from the admin assessment template editor, so
that branching templates can be authored without code changes and validated
before publish.

## User value

Today, the only way to introduce a branch (for example, showing
`transition_recovery_time` only when `stop_start_friction` is
`emotional_collapse`) is to modify
`db/seeds/assessment_templates/anchor_initial_profile.rb` and redeploy. After
this stage, an admin opens a draft template, edits a JSON predicate in the
`visible_if` field on a question or section, previews the result, fixes
validation errors inline, and publishes from the UI.

## Changes

### Model

- `AssessmentTemplate::EDITOR_QUESTION_STRING_FIELDS`
  (`app/models/assessment_template.rb`) should not include `visible_if` as a
  string field. Handle it separately in `normalize_editor_question`.
- Extend `normalize_editor_question`:
  - read `question["visible_if"]` from form params
  - if blank (`nil` / empty string), omit `visible_if` from normalized output
  - if present and a string, parse as JSON object
  - if already a hash, preserve as-is
  - on parse failure, add a schema validation error and keep the typed value
    available so the form re-renders with the same text
- Extend `normalize_editor_section` with the same `visible_if` behavior for
  sections.
- Reuse existing publish-time predicate validation
  (`AssessmentSchema::SchemaPredicate`) once `visible_if` is persisted in the
  schema.

### Editor views

- `app/views/admin/assessment_templates/_question_fields.html.erb`
  - add a `Conditional visibility (visible_if)` textarea
  - when `visible_if` exists, render pretty JSON in the field
  - include short helper text and one small JSON example
- `app/views/admin/assessment_templates/_section_fields.html.erb`
  - add the same textarea and helper copy at section level
- Keep this stage server-validated. Do not add client-side JSON parsing logic.

### Editor round-trip safety

- Ensure `AssessmentTemplate#editor_sections` and
  `apply_schema_editor_attributes!` preserve existing `visible_if` data during
  edit/save cycles so predicates are not silently dropped.

### Optional preview affordance

- If low effort, show a small "Conditional" badge in admin preview partials for
  questions/sections with `visible_if`.

### Specs

- `spec/models/assessment_template_spec.rb`
  - valid `visible_if` JSON string on question persists as hash
  - valid `visible_if` JSON string on section persists as hash
  - malformed JSON surfaces a schema error
  - blank field removes `visible_if`
  - existing hash round-trips without mutation
- `spec/requests/admin/assessment_templates_spec.rb`
  - draft update with valid `visible_if` persists and redirects
  - malformed JSON returns `unprocessable_content` and re-renders editor
  - publish surfaces unknown `question_id` reference errors from schema
    validation

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Published templates remain immutable; only drafts are editable
- [ ] Keep `AssessmentSchema::SchemaPredicate` as the single predicate
      validation source
- [ ] No changes to runtime branching contracts (`AssessmentRunner`,
      `AssessmentAnswerValidator`, `AssessmentEvidenceExtractor`)
- [ ] Existing specs remain green
- [ ] RuboCop remains clean

## Out of scope

- Visual predicate builder UI (form-driven, non-JSON condition composer)
- Client-side JSON linting/parsing
- Option-level follow-up sugar (Stage 4.9)
- New versioning UX changes beyond existing "New version" flow

## Open questions

> **Gate rule:** If any questions remain here, do not start building.

- None

## Steps

### Step 1 — Extend model normalization for `visible_if`

Add explicit parse/normalize behavior for `visible_if` in question + section
editor normalizers.

**Verify:** `bundle exec rspec spec/models/assessment_template_spec.rb`
**Revert:** `git checkout -- app/models/assessment_template.rb`

### Step 2 — Preserve predicates through editor round trips

Ensure existing `visible_if` hashes survive edit -> save cycles unchanged.

**Verify:** add and run a round-trip example in
`spec/models/assessment_template_spec.rb`
**Revert:** `git checkout -- app/models/assessment_template.rb spec/models/assessment_template_spec.rb`

### Step 3 — Add question-level `visible_if` editor UI

Add textarea + helper text in
`app/views/admin/assessment_templates/_question_fields.html.erb`.

**Verify:** manual QA on admin template edit flow
**Revert:** `git checkout -- app/views/admin/assessment_templates/_question_fields.html.erb`

### Step 4 — Add section-level `visible_if` editor UI

Add textarea + helper text in
`app/views/admin/assessment_templates/_section_fields.html.erb`.

**Verify:** manual QA on admin template edit flow
**Revert:** `git checkout -- app/views/admin/assessment_templates/_section_fields.html.erb`

### Step 5 — Optional preview badge for conditional items

If straightforward, add a small "Conditional" badge in admin preview partials.

**Verify:** manual QA on admin preview page
**Revert:** `git checkout -- app/views/admin/assessment_templates/_preview_question.html.erb app/views/admin/assessment_templates/preview.html.erb`

### Step 6 — Add request specs for admin editor flow

Add/extend request specs to cover valid update, invalid JSON re-render, and
publish-time predicate reference validation.

**Verify:** `bundle exec rspec spec/requests/admin/assessment_templates_spec.rb`
**Revert:** `git checkout -- spec/requests/admin/assessment_templates_spec.rb`

### Step 7 — Full verification and Stage 4.8 sync

```bash
bundle exec rspec
bundle exec rubocop
```

Mark Step 8 as complete in `stage-4.8-adaptive-branching.md` once this brief
is implemented and verified.

---

## Status

- [x] Step 1 — Model normalization
- [x] Step 2 — Round-trip preservation
- [x] Step 3 — Question editor UI
- [x] Step 4 — Section editor UI
- [x] Step 5 — Optional preview badge
- [ ] Step 6 — Request specs
- [ ] Step 7 — Full verification + Stage 4.8 sync

**Last updated:** 2026-04-22
**Handoff note:** This stage closes the authoring gap left in Stage 4.8 by
adding admin-facing `visible_if` editing. Runtime branching, validation, and
evidence filtering already exist and stay unchanged. This is a content/editor
stage to make branching manageable without seed edits.
