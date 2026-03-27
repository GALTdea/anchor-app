# Stage 4 — Assessments

> Full brief. Introduces three models (`AssessmentTemplate`, `Assessment`,
> `AssessmentResponse`), migrations, controllers, policies, routes, and views.
> This is the **MVP companion to Stage 1** (child profiles): structured evaluations
> assigned to a child, with submitted answers and respondent provenance.

---

## What is an Assessment (in Anchor)?

An **assessment** is a structured questionnaire (defined by an **assessment template**)
that a caregiver assigns to a **child profile**, fills out over one or more sessions,
and **submits** as an **assessment response**. The response stores the answers (JSON)
and records **who submitted** (`actor`) and **in what capacity** (`respondent_kind` —
e.g. parent reporting on behalf of the child vs. self-report where age-appropriate).

This differs from **observations** (Stage 3, deferred): observations are informal,
timestamped notes. Assessments are **schema-driven** forms with a clear submitted
snapshot suitable for reporting and longitudinal comparison.

---

## Goal

Enable a caregiver to pick a published assessment template for a child, complete it,
submit answers, and review past submissions — all scoped to the family workspace and
authorized by existing role permissions (`create_assessment`, `read_assessment`, etc.).

## User value

After Stage 1, a parent has a child profile. Stage 4 lets them run standardized
screeners or intake forms (however you seed or define templates) and keep a history
of completed submissions for that child.

## Constraints / Invariants

Reference: `docs/features/_constraints.md`

- [ ] Every controller action calls `authorize` (Pundit)
- [ ] Use `policy_scope` where listing records across spaces
- [ ] Keep controllers thin — validation of answers against template schema lives in
      a model or service object (e.g. `AssessmentResponse#validate_answers_against_schema`)
- [ ] Use daisyUI 5 for all new views (no Bootstrap/Tabler)
- [ ] Use `form_with` for forms
- [ ] Use Rails generators for models and controllers
- [ ] Existing specs must stay green
- [ ] RuboCop must stay clean

## Reference implementation

- Model pattern: `app/models/child_profile.rb` (enums, validations, associations)
- Controller pattern: `app/controllers/spaces/child_profiles_controller.rb` (nested under
  space, `friendly.find` for child, `authorize` every action)
- Policy pattern: `app/policies/child_profile_policy.rb` (`get_role_in_space`, Scope)
- View pattern: `app/views/spaces/child_profiles/` (daisyUI 5, `page_header`, empty states)

## Domain changes

### New models

| Model | Table | Key columns | Associations |
|-------|-------|-------------|--------------|
| `AssessmentTemplate` | `assessment_templates` | `title`, `slug`, `category`, `schema` (jsonb), `respondent_types` (jsonb or array), `status` | *(none — global library)* |
| `Assessment` | `assessments` | `child_profile_id`, `assessment_template_id`, `status`, `assigned_to_user_id` | `ChildProfile`, `AssessmentTemplate`, optional `User` (assignee) |
| `AssessmentResponse` | `assessment_responses` | `assessment_id`, `actor_id`, `respondent_kind`, `answers` (jsonb), `submitted_at` | `Assessment`, `User` (actor) |

**AssessmentTemplate — columns (proposed):**

| Column | Type | Notes |
|--------|------|--------|
| `title` | string, not null | Display name, e.g. "Developmental snapshot" |
| `slug` | string, not null, unique | For URLs and FriendlyId if used |
| `category` | string, optional | e.g. `screening`, `intake`, `follow_up` — free text or enum in model |
| `schema` | jsonb, not null, default: `{}` | Question definitions (see below) |
| `respondent_types` | jsonb, not null, default: `[]` | Allowed `respondent_kind` values for this template |
| `status` | integer, not null, default: 0 | enum: `draft`, `published`, `archived` — only `published` visible to caregivers |

**Schema JSON (MVP contract):**

The `schema` document should be versioned and minimal for the first implementation:

```json
{
  "version": 1,
  "questions": [
    {
      "id": "concern_level",
      "label": "Overall level of concern",
      "type": "scale",
      "min": 1,
      "max": 5,
      "required": true
    },
    {
      "id": "notes",
      "label": "Notes",
      "type": "textarea",
      "required": false
    }
  ]
}
```

**Supported `type` values for MVP:** `scale`, `textarea`, `text`, `select` (with
`options: ["a","b"]`). Expand in a later iteration.

**Assessment — columns:**

| Column | Type | Notes |
|--------|------|--------|
| `child_profile_id` | bigint FK, not null | |
| `assessment_template_id` | bigint FK, not null | |
| `status` | integer, not null, default: 0 | enum: `draft`, `submitted`, `archived` |
| `assigned_to_user_id` | bigint FK, optional | Who should complete it; MVP may leave null |

**AssessmentResponse — columns:**

| Column | Type | Notes |
|--------|------|--------|
| `assessment_id` | bigint FK, not null, unique | **One response per assessment** in MVP (`has_one`) |
| `actor_id` | bigint FK, not null | User who submitted |
| `respondent_kind` | string, not null | e.g. `parent_proxy`, `self_report`, `therapist_report`, `teacher_report` |
| `answers` | jsonb, not null, default: `{}` | Keys match question `id` from template schema |
| `submitted_at` | datetime, optional | `nil` = draft; set on submit |

**Indexes:** unique on `assessment_id` for `assessment_responses`; index on
`assessment_template_id`, `child_profile_id` for listings.

### Changed models

| Model | Change | Reason |
|-------|--------|--------|
| `ChildProfile` | `has_many :assessments, dependent: :destroy` | A child can have many assessment instances |
| `User` | `has_many :assessed_assessments, ...` optional | Only if you use `assigned_to_user_id` heavily; else defer alias |

### Seed data

Seed **1–2 published** `AssessmentTemplate` records with realistic `title`, `slug`,
`schema`, and `respondent_types: ["parent_proxy"]` so development and demos work
without an admin UI.

---

## Routes and controllers

**Nested under child profile (same nesting level as planned observations):**

```ruby
resources :spaces do
  resources :child_profiles, controller: "spaces/child_profiles" do
    resources :assessments, controller: "child_profiles/assessments" do
      resource :response, only: %i[show edit update],
        controller: "child_profiles/assessment_responses",
        as: :assessment_response
    end
  end
end
```

This yields paths such as:

- `/spaces/:space_id/child_profiles/:child_profile_id/assessments`
- `/spaces/:space_id/child_profiles/:child_profile_id/assessments/:id`
- `/spaces/:space_id/child_profiles/:child_profile_id/assessments/:assessment_id/response/edit`

**Optional read-only template catalog (if not embedded in “new assessment”):**

```ruby
resources :assessment_templates, only: %i[index show]
```

Use only if you want a standalone “library” page; otherwise load templates in
`ChildProfiles::AssessmentsController#new` via `AssessmentTemplate.published`.

| Controller | Actions | Notes |
|-----------|---------|-------|
| `ChildProfiles::AssessmentsController` | `index`, `new`, `create`, `show`, `destroy` | `destroy` = soft-archive assessment. No `edit` on Assessment itself if all editing is on Response. |
| `ChildProfiles::AssessmentResponsesController` | `show`, `edit`, `update` | Update saves `answers`; add `POST` or `PATCH` action `submit` (or `update` with `params[:commit]`) to set `submitted_at` and lock |

**Simpler alternative:** single `update` on response with a "Submit" button that sets
`submitted_at` and flips parent `Assessment` to `submitted`. Policy blocks `edit` when
submitted.

**Authorization helper:** For `Assessment` and `AssessmentResponse`, resolve space via
`record.child_profile.space` (same pattern as planned `ObservationPolicy`).

## Authorization

| Policy | Actions | Rule summary |
|--------|---------|--------------|
| `AssessmentTemplatePolicy` | `index?`, `show?` | `user.admin?` **or** any authenticated user with `read_assessment` in at least one space — *or* simplify MVP: any signed-in user can read published templates (templates contain no PHI) |
| `AssessmentPolicy` | `index?` | `read_assessment?` in child's space |
| | `show?` | `read_assessment?` |
| | `create?` | `create_assessment?` |
| | `destroy?` | `delete_assessment?` |
| `AssessmentResponsePolicy` | `show?` | `read_assessment?` |
| | `update?` | `update_assessment?` **and** assessment not yet submitted (or allow admin override) |

**Initialize pattern:**

```ruby
# AssessmentPolicy
@role = user.get_role_in_space(record.child_profile.space)

# AssessmentResponsePolicy
@role = user.get_role_in_space(record.assessment.child_profile.space)
```

**Scope:** For listing assessments in `index`, scope to `child_profile.assessments`
and ensure user can `read_assessment` in that space (policy on child profile context).

**Collaborator:** Per seeds — can create/read/update assessments but not delete child
profile. Confirm `delete_assessment` is false for collaborator; if so, hide "Archive
assessment" for collaborators.

## UI

- **Layout:** dashboard
- **Turbo:** optional — form autosave can be post-MVP
- **New views:**
  - `child_profiles/assessments/index` — table of assessments for one child (template
    title, status, last updated, actions)
  - `child_profiles/assessments/new` — pick template (if multiple), optional assignee
    (defer UI if `assigned_to_user_id` not in MVP)
  - `child_profiles/assessments/show` — summary + link to response (edit or view-only)
  - `child_profiles/assessment_responses/edit` — dynamic form from `schema` + respondent
    kind select
  - `child_profiles/assessment_responses/show` — read-only submitted answers
- **Changed views:**
  - `spaces/child_profiles/show.html.erb` — add "Assessments" card or link to
    `space_child_profile_assessments_path`

**daisyUI:** `card`, `table`, `btn`, `input`, `textarea`, `select`, `badge`, `steps`
(optional for draft → submitted)

## Acceptance criteria

- [ ] Published assessment templates exist via seeds and appear when starting a new assessment
- [ ] A caregiver can create an assessment for a child from a template (status `draft`)
- [ ] A caregiver can fill in answers (JSON) matching the template schema
- [ ] A caregiver can submit the response (`submitted_at` set, assessment status `submitted`)
- [ ] Submitted responses are read-only for non-admin users
- [ ] A caregiver can list assessments for a child and open show/detail
- [ ] A caregiver can archive/delete an assessment per policy (soft-delete if using `archived` status)
- [ ] `actor_id` is set to `current_user` on submit; `respondent_kind` is chosen from template-allowed types
- [ ] Only users with appropriate space role permissions can access these actions
- [ ] All new views use daisyUI 5 only
- [ ] Specs cover models (including answer validation), policies, and request specs for main flows

## Out of scope

- Admin UI to create/edit `AssessmentTemplate` records (use seeds + future admin)
- PDF export, scoring algorithms, norm tables
- Multiple responses per assessment (retakes) — later: add new `Assessment` instance
- Assigning assessments to external users who are not in the space (Stage 5)
- Notifications and reminders
- Rich question types (file upload, matrix) — extend `schema` contract later

## Open questions

> **Gate rule:** If any questions remain here, do not start Phase 3 (Build).

1. **Template policy:** Should any signed-in user see published templates, or only users
   who have `read_assessment` in some space? (Recommendation: restrict to users who
   belong to at least one space, or check `read_assessment` on current space when coming
   from child context.)

2. **assigned_to_user_id:** Include in MVP UI or always null and hide the field?

3. **Archive vs delete:** Align naming with child profiles — `destroy` action sets
   `status: :archived` on `Assessment`?

4. **respondent_kind:** Confirm enum/string list for MVP:
   `parent_proxy`, `self_report`, `therapist_report`, `teacher_report` — subset per
   template via `respondent_types`.

---

## Steps

### Step 1 — AssessmentTemplate model, migration, factory, spec

- `bin/rails generate model AssessmentTemplate title:string slug:string:uniq category:string schema:jsonb respondent_types:jsonb status:integer`
- Add enum `status: { draft: 0, published: 1, archived: 2 }`, validations, scope `published`
- Optional: `extend FriendlyId` on `slug`
- Factory + model spec

**Verify:** `bundle exec rspec spec/models/assessment_template_spec.rb`

---

### Step 2 — Assessment model, migration, factory, spec

- `bin/rails generate model Assessment child_profile:references assessment_template:references assigned_to_user_id:integer status:integer`
- Foreign keys, null constraints, enum `status: { draft: 0, submitted: 1, archived: 2 }`
- `belongs_to :child_profile`, `belongs_to :assessment_template`, optional `belongs_to :assigned_to, class_name: "User", optional: true`
- `has_one :assessment_response, dependent: :destroy` (or `dependent: :restrict_with_error` if responses must be deleted first — pick one strategy)
- Validations: template must be `published` at create time
- Factory + spec

**Verify:** `bundle exec rspec spec/models/assessment_spec.rb`

---

### Step 3 — AssessmentResponse model, migration, factory, spec

- `bin/rails generate model AssessmentResponse assessment:references actor_id:integer respondent_kind:string answers:jsonb submitted_at:datetime`
- Unique index on `assessment_id`
- `belongs_to :assessment`, `belongs_to :actor, class_name: "User"`
- Validations: `answers` present (or allow empty hash until submit — decide); validate
  keys against template schema on submit (service or model callback)
- Factory + spec

**Verify:** `bundle exec rspec spec/models/assessment_response_spec.rb`

---

### Step 4 — Associate ChildProfile; seed templates

- `ChildProfile` `has_many :assessments`
- `db/seeds.rb` — create 1–2 `AssessmentTemplate` published records

**Verify:** `bin/rails db:seed` (idempotent)

---

### Step 5 — Policies + policy specs

- `AssessmentTemplatePolicy`, `AssessmentPolicy`, `AssessmentResponsePolicy`
- Specs for owner / caregiver / collaborator / no role

**Verify:** `bundle exec rspec spec/policies/`

---

### Step 6 — Routes + controllers + request specs

- Add nested routes as above
- Implement controllers with `before_action` chain (`set_space`, `set_child_profile`,
  `set_assessment` where needed)
- Request specs: happy path create → edit response → submit; authorization failures

**Verify:** `bundle exec rspec spec/requests/child_profiles/`

---

### Step 7 — Views (daisyUI 5) + child profile show link

- Build index, new, show for assessments; edit/show for response
- Dynamic form partial: iterate `schema["questions"]`, render field by `type`
- Child profile show: assessments section

**Verify:** Manual browser QA

---

### Step 8 — Full suite + RuboCop + manual QA

```
bin/rails db:migrate
bundle exec rspec
bundle exec rubocop
```

---

## Status

- [ ] Step 1 — AssessmentTemplate
- [ ] Step 2 — Assessment
- [ ] Step 3 — AssessmentResponse
- [ ] Step 4 — ChildProfile association + seeds
- [ ] Step 5 — Policies + specs
- [ ] Step 6 — Routes + controllers + request specs
- [ ] Step 7 — Views + child profile link
- [ ] Step 8 — Full verification

**Last updated:** 2026-03-26
**Handoff note:** Brief drafted. Resolve open questions before Phase 3 (Build). This
stage is the current **MVP** scope together with Stage 1 (child profiles).
