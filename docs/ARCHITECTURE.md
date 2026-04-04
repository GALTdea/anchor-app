# Architecture

Domain model, layout system, request lifecycle, AppSettings, and background jobs. See docs/AGENTS.md for stack and key files.

---

## Section 1 — Domain model

### Models and attributes

- **User** — People who sign in. Attributes: `admin` (boolean), `first_name`, `last_name`, `email`, `slug` (friendly_id), `status` (enum: active, archived), `phone`, Devise fields (`encrypted_password`, `remember_created_at`, `reset_password_*`), and devise_invitable fields (`invitation_token`, `invitation_accepted_at`, `invitation_created_at`, `invitation_sent_at`, `invitation_limit`, `invited_by_id`, `invited_by_type`). `User#name` returns `"#{first_name} #{last_name}"`.

- **Space** — Tenant/workspace. Attributes: `name`, `status` (enum: active, archived), and optionally `phone`, `email`, `address`. A space has many users through roles and many plans through subscriptions.

- **Role** — Permission set; can be global (`space_id` nil) or scoped to a space. Attributes: `name`, `permissions` (json), `type` (STI: common/custom), `value`, `space_id` (optional). Defines permission methods (e.g. `can_create_user?`).

- **UserRole** — Join of User, Space, and Role. A user has one role per space. Validates that the role belongs to that space.

- **Plan** — Billing plan. Attributes: `name`, `currency`, `duration`, `price`, `description`, `crm_id`. Has many spaces through subscriptions.

- **Subscription** — Links a Space to a Plan. Attributes: `start_date`, `end_date`, `seats`, `plan_id`, `space_id`. Scope `active` for current subscriptions.

- **AppSettings** — Singleton application settings. Single row; attributes stored in `settings` (jsonb in PostgreSQL). Keys and types come from `config/app_settings.yml`. Used for feature flags and app-wide options (e.g. `multi_tenant_mode`, `show_landing_page`).

### Relationships (prose)

- **User** has many **UserRoles**, and has many **Spaces** through UserRoles. User has many **Roles** through UserRoles (role is per space).
- **Space** has many **UserRoles**, has many **Users** through UserRoles, has many **Subscriptions**, and has many **Plans** through Subscriptions.
- **Role** belongs to **Space** (optional). **UserRole** belongs to **User**, **Space**, and **Role**.
- **Plan** has many **Subscriptions** and has many **Spaces** through Subscriptions.
- **Subscription** belongs to **Space** and **Plan**.
- **AppSettings** is a singleton (one row); no associations.

### Relationship diagram (ASCII)

```
    User ──────< UserRole >────── Space
                    │                │
                    │                │ has_many
                    ▼                ▼
                 Role ◄── optional  Subscription ──► Plan
                    (space_id)

    AppSettings   (singleton, no associations)
```

---

## Section 2 — Layout system

### Three layouts

| Layout            | Use case                    | When selected                          |
|-------------------|----------------------------|----------------------------------------|
| **application**   | Public / marketing pages   | When user is not signed in             |
| **dashboard**     | Authenticated app pages    | When user is signed in                 |
| **devise**        | Auth pages (login, etc.)   | When `devise_controller?` is true      |

### ApplicationController#determine_layout

Layout is chosen in this order:

1. If the current controller is a **Devise controller** → use `"devise"`.
2. Else if **user_signed_in?** → use `"dashboard"`.
3. Else → use `"application"`.

So: Devise wins first, then signed-in users get the dashboard, and everyone else gets the application (marketing) layout.

### Shared partials

| Partial                    | Purpose |
|----------------------------|--------|
| **shared/_flash**          | Renders flash messages: `notice` as success alert (green), `alert` as error alert (red). Used in all layouts. |
| **shared/_user_menu**      | Dropdown with avatar, name, status, links to Profile, Change password, Spaces (if multi_tenant_mode?), Setup (if admin), and Logout. |
| **shared/_user_menu_compact** | Compact user block: avatar, name, email, and logout button. For narrow/sidebar use. |
| **shared/_page_header**    | Page title and optional subtitle; optional `content_for :actions` block for action buttons. |
| **shared/_pagination**     | Pagination UI for Pagy. Pass local `pagy: @pagy`. Convention: `render "shared/pagination", pagy: @pagy`. |

---

## Section 3 — Request lifecycle

Typical **authenticated** request flow:

1. **ApplicationController before_actions**
   - `authenticate_user!` (Devise) — except on `:landing`; redirects to sign-in if not signed in.
   - `set_main_space` — only for `:landing`; sets `@main_space` to current user’s first space.
   - `redirect_signed_in_user` — only for `:landing`; if signed in, redirects to main space or spaces index.

2. **Layout selection**
   - `layout :determine_layout` — sets the layout (devise / dashboard / application) as above.

3. **Controller action**
   - Subclass controllers add their own `before_action`s (e.g. `set_space`, Pundit `authorize`).
   - **Pagination** (if used): `@pagy, @records = pagy(collection)` in the action; view renders `shared/pagination` with `@pagy`.
   - **Pundit**: each action should call `authorize` (or use a `before_action` that does) so the policy is checked before rendering.

4. **Response**
   - View renders with the chosen layout; layout includes shared partials (e.g. flash, user menu) as needed.

So for an authenticated request: authenticate → determine layout → run action (authorize, optionally pagy) → render with layout.

---

## Section 4 — AppSettings

AppSettings is a **singleton**: one row holds all app settings in a `settings` json column. Schema (keys, types, defaults) is defined in **config/app_settings.yml**; the app loads it in **config/initializers/load_app_settings.rb** and exposes accessors on the **AppSettings** model.

### What AppSettings controls (used in this template)

- **multi_tenant_mode** — When true, space switcher and space-scoped features are relevant. Affects Space visibility and whether “Spaces” appears in the user menu. Accessed in views via helper `multi_tenant_mode?` (wraps `AppSettings.multi_tenant_mode`).
- **show_landing_page** — When true, the public landing page is shown; when false, the app can redirect to sign-in or another path. Accessed via helper `show_landing_page?` (wraps `AppSettings.show_landing_page`).

### How to access

- **Read**: Use class methods generated from the YAML, e.g. `AppSettings.multi_tenant_mode`, `AppSettings.show_landing_page`. In views, use the helpers `multi_tenant_mode?` and `show_landing_page?`.
- **Singleton record**: The record holding the settings is the first row, e.g. `AppSettings.first`. Use it when updating the `settings` hash or when you need the ActiveRecord instance.

---

## Section 5 — Background jobs

### Solid Queue

Background jobs use **Solid Queue**. No Redis is required; jobs are stored in PostgreSQL.

### Configuration

- **Production** (`config/environments/production.rb`):
  - `config.active_job.queue_adapter = :solid_queue`
  - `config.solid_queue.connects_to = { database: { writing: :queue } }` (separate DB for the queue).
- **Development**: Default queue adapter is used (e.g. `:async`); Solid Queue can be enabled in Puma with `ENV["SOLID_QUEUE_IN_PUMA"]` (see `config/puma.rb`).

### How to enqueue jobs

Use Active Job as usual:

```ruby
MyJob.perform_later(arg1, arg2)
# or
MyJob.set(wait: 5.minutes).perform_later(arg1)
```

Define job classes that inherit from `ApplicationJob`; they run via Solid Queue in production when the queue adapter is `:solid_queue`.

---

## Section 6 — Anchor app domain model

Anchor is an autism care-circle app. The domain extends the template's
User/Space/Role foundation with child-centered models.

### Domain concepts

- **Space** = a family or care-circle workspace (UI label: "Family").
- **User** = any authenticated adult (parent, therapist, teacher, admin).
- **ChildProfile** = the child or supported person being cared for.
- **ChildAccess** = per-user, per-child relationship and permissions.
- **Assessment** = a structured evaluation assigned to a child.
- **AssessmentResponse** = a submitted answer set with respondent provenance.
- **Observation** = a log entry (behavior, milestone, note) about a child.
- **ProfileEvidence** = normalized, cross-source evidence derived from assessments
  and later observations.
- **CurrentProfile** = the latest synthesized child portrait built from evidence.
- **ProfileSnapshot** = a point-in-time saved state of the current profile.
- **Recommendation** = generated guidance tied to a profile snapshot.

### Three-tier role system

1. **System role** — `users.admin` boolean. Platform administration only (super admin).
2. **Workspace role** — `UserRole` join with `Role`. Controls what a user can do in a family workspace. Seeded common roles: `owner`, `caregiver`, `collaborator`.
3. **Child access role** (future, Stage 5) — `ChildAccess` join between User and ChildProfile. Controls per-child relationship and permissions. Values: `primary_guardian`, `guardian`, `therapist`, `teacher`, `aba_staff`, `observer`.

### Seeded workspace roles

| Role | value | Permissions |
|------|-------|-------------|
| **Owner** | `owner` | All permissions `true` |
| **Caregiver** | `caregiver` | All except `create_space`, `update_space`, `delete_space`, `manage_collaborators` |
| **Collaborator** | `collaborator` | Read child data, create observations/assessments. No user/space management, no child profile edit/delete |

### Built models

| Model | Stage | Key columns | Belongs to |
|-------|-------|-------------|-----------|
| **ChildProfile** | 1 ✅ | `space_id`, `first_name`, `last_name`, `date_of_birth`, `status`, `slug` | Space |
| **AssessmentTemplate** | 4.5 ✅ | `title`, `slug`, `template_key`, `version`, `schema`, `respondent_types`, `status` | — |
| **Assessment** | 4.5 ✅ | `child_profile_id`, `assessment_template_id`, `status`, `assigned_to_user_id` | ChildProfile, AssessmentTemplate |
| **AssessmentResponse** | 4.5 ✅ | `assessment_id`, `actor_id`, `respondent_kind`, `answers`, template snapshots, processing fields | Assessment, User |
| **ProfileEvidence** | 4.5 ✅ | `child_profile_id`, `source_type`, `source_id`, `dimension_key`, `concept_key`, `value`, `value_type`, `confidence` | ChildProfile |
| **CurrentProfile** | 4.5 ✅ | `child_profile_id`, `summary`, `narrative`, `generated_at`, `profile_version` | ChildProfile |
| **ProfileSnapshot** | 4.5 ✅ | `child_profile_id`, `summary`, `narrative`, `generated_at`, `trigger_source_type`, `trigger_source_id` | ChildProfile |
| **Recommendation** | 4.5 ✅ | `child_profile_id`, `status`, `category`, `title`, `body`, `rationale`, `generated_at` | ChildProfile, ProfileSnapshot |

### Planned models (not yet built)

| Model | Stage | Key columns | Belongs to |
|-------|-------|-------------|-----------|
| **Observation** | 3 | `child_profile_id`, `author_id`, `category`, `body`, `observed_on`, `visibility` | ChildProfile, User |
| **ChildAccess** | 5 | `user_id`, `child_profile_id`, `relationship`, `granted_by_user_id`, `status` | User, ChildProfile |
| **ConsentRecord** | 6 | `child_profile_id`, `granted_by_user_id`, `granted_to_user_id`, `scope`, `status` | ChildProfile, User |

### Planned relationship diagram

```
    User ──────< UserRole >────── Space (Family)
      │              │                │
      │              ▼                │ has_many
      │           Role                ▼
      │                          ChildProfile
      │                               │
      ├──────< ChildAccess >──────────┤  (Stage 5)
      │                               │
      ├──────< Observation >──────────┤  (Stage 3)
      │                               │
      │                          Assessment ──► AssessmentTemplate
      │                               │
      └──────< AssessmentResponse >───┘
                                      │
                                      ▼
                               ProfileEvidence
                                      │
                                      ▼
                                CurrentProfile
                                      │
                                      ▼
                               ProfileSnapshot
                                      │
                                      ▼
                                Recommendation
```

### Respondent provenance (assessments)

Each `AssessmentResponse` records:
- **actor** — which authenticated user submitted it
- **respondent_kind** — who the answers represent (`parent_proxy`, `self_report`, `therapist_report`, `teacher_report`)
- **subject** — implied via the assessment's child profile

### Second-brain pipeline

The second-brain layer now follows this shared pattern:

```text
caregiver-authored source record
-> normalized ProfileEvidence
-> CurrentProfile rebuild
-> ProfileSnapshot if profile changed
-> Recommendation refresh
```

Today the implemented source record is `AssessmentResponse`.
When Stage 3 observations are built, `Observation` should feed this same pipeline
rather than creating a parallel AI memory path.

### Feature stages

See `docs/features/` for detailed briefs per stage.

**MVP scope (current):** Stage 1 (child profiles) + Stage 4 (assessments). Stages 2
(invite caregiver) and 3 (observations) are deferred to post-MVP; briefs remain in
`docs/features/` for when you pick them up.

| Stage | Feature | Key models |
|-------|---------|-----------|
| 0 | Foundation cleanup (roles, permissions, UI labels) | — |
| 1 | Child profile + single-guardian flow | ChildProfile |
| 2 | Invite a second caregiver *(deferred — post-MVP)* | — |
| 3 | Observations *(deferred — post-MVP)* | Observation |
| 4 | Assessments | AssessmentTemplate, Assessment, AssessmentResponse |
| 4.5 | Second-brain foundation | ProfileEvidence, CurrentProfile, ProfileSnapshot, Recommendation |
| 5 | External collaborators + child access | ChildAccess |
| 6 | Consent tracking + audit trail | ConsentRecord, AuditLog |
| 7 | Goals and progress tracking | TBD |
