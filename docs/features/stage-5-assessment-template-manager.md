# Stage 5 — Assessment Template Manager

> Full brief. Adds an admin-only authoring workflow for assessment templates so
> the team can create, preview, publish, and version the schema-driven
> assessments that power onboarding and future caregiver flows.

---

## Goal

Give admins a safe, structured way to manage assessment template drafts and
published versions without editing live published templates in place.

## User value

An admin can create and refine assessment templates inside the app instead of
relying on seeds or console edits. They can shape sections, questions, answer
options, respondent types, and AI-facing semantics, preview the full
assessment, publish only valid drafts, and create a new draft version from a
published template when the assessment needs to evolve.

This turns `AssessmentTemplate` from a developer-managed record into an
operational product tool, while preserving the auditability and immutability the
assessment pipeline already depends on.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action calls `authorize` (Pundit)
- [ ] Keep controllers thin; schema editing, publish validation, and version
      cloning logic live in models or service/form objects
- [ ] Use strong parameters
- [ ] Use RESTful routes where practical; custom member actions are allowed for
      publish, preview, and version creation
- [ ] Admin-only features gate on `user.admin?`
- [ ] Use Tailwind CSS 4 + daisyUI 5 for all new views
- [ ] Use `form_with` for forms
- [ ] Keep `AssessmentTemplate#schema` as the source of truth for sections and
      questions in this stage; do not introduce a separate `Question` model
- [ ] Published template versions remain immutable; changes to a published
      template produce a new draft version instead of mutating the live record
- [ ] Existing assessment assignment/submission flows must continue to read only
      published templates
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean

## Reference implementation

- Model pattern: `app/models/assessment_template.rb`
- Controller pattern: `app/controllers/child_profiles/assessments_controller.rb`
- Admin navigation pattern: `app/views/layouts/dashboard.html.erb`
- View pattern: `app/views/child_profiles/assessment_responses/edit.html.erb`,
  `app/views/onboarding/assessments/show.html.erb`
- Policy pattern: `app/policies/assessment_template_policy.rb`
- Brief dependency: `docs/features/stage-4-assessments.md`,
  `docs/features/stage-4.5-adaptive-assessments.md`

## Product framing

### What is being managed

Admins are managing **template definitions**, not child-specific assessments.

The core object remains `AssessmentTemplate`, which already stores:

- base metadata (`title`, `slug`, `category`, `template_key`, `version`)
- publish state (`draft`, `published`, `archived`)
- allowed respondent kinds (`respondent_types`)
- full section/question contract in `schema`

### Draft vs published behavior

- Drafts may be incomplete and editable
- Published templates must satisfy the full schema contract
- Published templates are read-only in place
- Iterating on a published template creates a new draft version

### Authoring scope for this stage

The admin manager should support:

- creating a draft template
- adding sections
- adding, editing, removing, and reordering questions
- managing answer options for supported question types
- setting respondent types
- setting AI/profile semantics per question
- previewing the full assessment
- publishing a validated draft
- creating a new version from a published template

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| None required | — | — | — |

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `AssessmentTemplate` | Add draft-friendly editing helpers and stronger publish/version workflows | Support admin authoring without weakening publish invariants |
| `AssessmentTemplatePolicy` | Expand beyond read access so admin-only management actions can be authorized cleanly | Keep admin manager explicit and Pundit-backed |

### Proposed schema contract shape

No new table is required if section and question authoring continue to live
inside `assessment_templates.schema`.

Recommended shape:

```json
{
  "version": 1,
  "sections": [
    {
      "id": "communication",
      "title": "Communication",
      "description": "How the child communicates day to day."
    }
  ],
  "questions": [
    {
      "id": "expresses_needs",
      "section": "communication",
      "label": "How does your child usually express their needs?",
      "help_text": "Think about the last two weeks.",
      "type": "select",
      "required": true,
      "options": ["Words", "Gestures", "Mixed", "Not yet consistently"],
      "dimension_key": "communication.expression",
      "concept_key": "expresses_needs",
      "time_window": "typical_two_weeks",
      "evidence_weight": 0.8,
      "extraction_hint": "Look for expressive language level and communication strategy."
    }
  ]
}
```

### Seed data

No seed changes are required to start this stage. Existing published templates
can continue to seed demo data, and the admin manager will become the preferred
way to create future templates.

## Routes and controllers

```ruby
namespace :admin do
  resources :assessment_templates, only: %i[index show new create edit update] do
    member do
      get :preview
      post :publish
      post :new_version
    end
  end
end
```

### Controller responsibilities

| Controller | Actions | Notes |
|-----------|---------|-------|
| `Admin::AssessmentTemplatesController` | `index`, `show`, `new`, `create`, `edit`, `update`, `preview`, `publish`, `new_version` | Admin-only manager for draft lifecycle, preview, publish, and version cloning |

### Routing notes

- `index` should use `policy_scope` and paginate template versions for consistency
  with app conventions
- `show` should act as the admin detail page for a template version
- `edit` is available only for draft versions
- `preview` renders the template with the same field partials used by the real
  runner where possible
- `publish` performs strict validation and flips the draft to `published`
- `new_version` clones a published version into a new draft with the same
  `template_key` and incremented `version`

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|-------------|
| `AssessmentTemplatePolicy` | `index?`, `show?`, `create?`, `update?`, `preview?`, `publish?`, `new_version?` | Admin only for all management actions; caregiver read access remains limited to existing nested assessment flows |

### Policy notes

- Keep admin management explicit instead of inferring from workspace roles
- Existing nested caregiver flows may continue to authorize template visibility
  in space context as they do today
- The current `AssessmentTemplatePolicy` is shaped around a space-aware context
  object for caregiver flows, so the admin manager should either:
  - extend that policy to support both plain `AssessmentTemplate` records and
    the existing context object cleanly, or
  - introduce a dedicated admin policy/context pattern that avoids ambiguous
    initialization logic

The preferred outcome is one clear, testable authorization path for admin
management and one clear path for caregiver template visibility.

## Service / form layer

To keep controllers thin, prefer small focused objects:

- `AssessmentTemplateEditor` or equivalent form object
  Normalizes section/question params into `schema`
- `AssessmentTemplatePublisher`
  Runs publish validations and transitions draft to `published`
- `AssessmentTemplateVersionCloner`
  Creates a new editable draft from a published template version
- `AssessmentTemplatePreviewPresenter` or shared helper/partial strategy
  Keeps preview rendering aligned with the live runner without coupling preview
  to form parameter names

These do not need to be created all at once, but the brief assumes business
logic will not live directly in the controller.

## UI

- **Layout:** dashboard
- **Turbo:** frames are recommended for preview and editor partial updates; full
  page fallback is acceptable
- **New views:**
  - `admin/assessment_templates/index`
  - `admin/assessment_templates/show`
  - `admin/assessment_templates/new`
  - `admin/assessment_templates/edit`
  - `admin/assessment_templates/preview`
  - shared partials for section/question rows and question-type-specific fields
- **Changed views:**
  - add an admin navigation entry in the dashboard for signed-in admins
  - extract shared question rendering logic where it reduces duplication without
    tying preview rendering to live form field names

### UX requirements

- Draft editor clearly distinguishes template metadata from question authoring
- Question ordering and section ordering are visible and editable
- Question-type-specific fields appear only when relevant
- AI/profile semantics are editable without feeling like raw JSON
- Publish flow shows validation errors in human-readable terms
- Published versions clearly display as read-only
- Version history is understandable from the index/show pages
- Preview should reflect runner behavior closely enough to trust question type,
  labels, help text, sections, and options, even if it is rendered read-only

## Acceptance criteria

- [ ] An admin can create a new draft assessment template from the dashboard
- [ ] An admin can add, edit, remove, and reorder sections within a draft
- [ ] An admin can add, edit, remove, and reorder questions within a draft
- [ ] An admin can manage answer options for supported question types such as
      `select`
- [ ] An admin can set allowed respondent types on a draft
- [ ] An admin can set AI/profile semantics per question, including
      `dimension_key`, `concept_key`, `time_window`, and `evidence_weight`
- [ ] An admin can preview the full assessment before publishing
- [ ] A draft cannot be published unless it satisfies the same schema contract
      required by `AssessmentTemplate` for published records
- [ ] Once published, a template version cannot be edited in place through the UI
      or model updates
- [ ] An admin can create a new draft version from a published template
- [ ] Caregiver-facing assessment flows continue to use only published templates

## Out of scope

- Adaptive branching logic or conditional question visibility
- Bulk import/export of templates
- Per-space template libraries or non-admin template editors
- Separate normalized database tables for sections or questions
- Full audit event history beyond standard timestamps/version numbers
- Template localization/multi-language support
- Drag-and-drop JavaScript polish if simple server-rendered reorder controls ship first

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

- None

## Steps

### Step 1 — Admin template management foundation

Add routes, controller, policy updates, and basic index/show/new/create/edit/update
support for admin-only draft templates, including an admin navigation entry and
policy-scoped index page.

**Verify:** `bundle exec rspec spec/policies/assessment_template_policy_spec.rb spec/requests/admin/assessment_templates_spec.rb`
**Revert:** `git checkout -- config/routes.rb app/controllers/admin/assessment_templates_controller.rb app/policies/assessment_template_policy.rb app/views/admin/assessment_templates spec/requests/admin/assessment_templates_spec.rb spec/policies/assessment_template_policy_spec.rb`

### Step 2 — Draft schema editor

Add form handling for sections, questions, respondent types, supported answer
options, and AI/profile semantics stored in `schema`.

**Verify:** `bundle exec rspec spec/models/assessment_template_spec.rb spec/requests/admin/assessment_templates_spec.rb`
**Revert:** `git checkout -- app/models/assessment_template.rb app/controllers/admin/assessment_templates_controller.rb app/views/admin/assessment_templates spec/models/assessment_template_spec.rb spec/requests/admin/assessment_templates_spec.rb`

### Step 3 — Preview and publish flow

Add preview rendering and a publish action that validates the draft against the
published contract and surfaces clear errors.

**Verify:** `bundle exec rspec spec/models/assessment_template_spec.rb spec/requests/admin/assessment_templates_spec.rb`
**Revert:** `git checkout -- app/models/assessment_template.rb app/controllers/admin/assessment_templates_controller.rb app/views/admin/assessment_templates spec/models/assessment_template_spec.rb spec/requests/admin/assessment_templates_spec.rb`

### Step 4 — Version cloning

Add the `new_version` workflow so published templates can be iterated on safely
through a new draft version instead of direct edits.

**Verify:** `bundle exec rspec spec/models/assessment_template_spec.rb spec/requests/admin/assessment_templates_spec.rb`
**Revert:** `git checkout -- app/models/assessment_template.rb app/controllers/admin/assessment_templates_controller.rb spec/models/assessment_template_spec.rb spec/requests/admin/assessment_templates_spec.rb`

### Step 5 — Post-build audit and brief update

Review authorization, empty states, read-only published behavior, and reuse of
runner rendering patterns. Update this brief's status section once build work is done.

**Verify:** `bundle exec rspec && bundle exec rubocop`
**Revert:** Documentation-only for the brief update; code rollback depends on the audited step

---

## Status

- [x] Brief created
- [x] Step 1
- [x] Step 2
- [x] Step 3
- [ ] Step 4
- [ ] Step 5

**Last updated:** 2026-04-10
**Handoff note:** The feature is framed as an admin-only assessment template
manager built on the existing `AssessmentTemplate` versioning model. Step 1 is
now implemented: admin routes, controller, policy scope, dashboard navigation,
basic draft metadata CRUD, and initial request/policy coverage are in place.
Step 2 is also complete: the draft editor now supports section/question authoring,
order fields, select options, and AI semantics mapped into `schema`. Step 3 is
now complete as well: admins can preview a read-only assessment rendering and
publish valid drafts, with publish failures surfacing the model validation
errors back in the editor. Step 4 should focus on version cloning.
