# App Constraints and Invariants

Shared reference for feature briefs. Copy relevant items into each brief's
"Constraints / Invariants" section.

Source of truth: `docs/AGENTS.md`, `docs/CONVENTIONS.md`, `.cursorrules`

---

## Authorization

- Every controller action must call `authorize` (Pundit).
- Use `policy_scope` for index queries.
- Admin-only features gate on `user.admin?` (the `users.admin` boolean).

## Controllers

- Keep controllers thin — no business logic.
- Use strong parameters.
- Use RESTful routes.
- Use `before_action` for shared setup (set_space, set_record, etc.).
- Flash keys: `notice` (success), `alert` (warning/error).

## Models

- Use ActiveRecord validations, not controller-level checks.
- Use enums for status fields.
- Use `friendly_id` for slugged URLs where appropriate.
- Use concerns for shared behavior across models.
- Move complex logic into models or service objects.

## Views and UI

- Use Tailwind CSS 4 + daisyUI 5 for all components.
- Never use Bootstrap, Tabler, or daisyUI 4 class names.
- See `docs/CONVENTIONS.md` for the daisyUI 5 migration table.
- Use `fieldset` / `fieldset-legend` / `label` for forms (not `form-control` / `label-text`).
- Use Rails form helpers (`form_with`), never raw HTML form tags.
- Keep views DRY with partials.
- Use `render "shared/page_header"` for page titles.
- Use `render "shared/pagination", pagy: @pagy` for pagination.

## Turbo / Hotwire

- Prefer server-rendered HTML with Turbo Frames for partial page updates.
- Use Turbo Streams for multi-element updates from controller actions.
- Add `data-turbo-confirm` for destructive actions.

## Layouts

- `layouts/application` — public / marketing pages (not signed in).
- `layouts/dashboard` — authenticated pages (signed in).
- `layouts/devise` — auth pages (login, register, etc.).
- Layout is auto-selected by `ApplicationController#determine_layout`.

## Pagination

- Use Pagy. Never Kaminari.
- Controller: `@pagy, @records = pagy(collection)`
- View: `render "shared/pagination", pagy: @pagy`

## Background jobs

- Use Active Job with Solid Queue. No Redis.
- Keep jobs small and idempotent.

## Multi-tenancy

- Space is the tenant model.
- Always respect tenant scoping when adding or editing features.
- A user has one role per space (via `UserRole`).
- Roles can be common (global, `space_id` nil) or custom (space-scoped).

## Testing

- Use RSpec + FactoryBot.
- Write request specs for controller actions.
- Write model specs for validations and business logic.

## Code style

- Ruby style guide: `snake_case` for methods/variables/files, `CamelCase` for classes/modules.
- Prefer Rails generators to create new artifacts.
- No custom CSS unless no Tailwind/daisyUI equivalent exists.

## What NOT to do

- Do not use Bootstrap or Tabler classes.
- Do not add Kaminari.
- Do not use `form-control` or `label-text` (daisyUI 4).
- Do not use `rails_admin`.
- Do not install Redis.
- Do not write raw SQL — use ActiveRecord.
- Do not put business logic in controllers.
