# AGENTS.md — AI Agent Entry Point

Read this file first. It tells you everything you need
to work effectively on this Rails application.

## Stack
- Ruby 4.0.1
- Rails 8.1.2
- PostgreSQL (default; dedicated starter)
- Hotwire (Turbo + Stimulus), importmap, propshaft
- Tailwind CSS 4.2.0 + daisyUI 5.5.19
  (config: app/assets/tailwind/application.css)
  (daisyUI loaded via npm as @plugin)
- Devise 5.0.2 + devise_invitable
- Pundit (authorization)
- Solid Queue (background jobs, no Redis)
- Pagy 9.x (pagination)
- friendly_id 5.x (slug-based URLs)
- meta-tags 2.x (SEO)
- RSpec + FactoryBot (testing)
- Kamal (deployment)

## How to run

  bin/dev                          # start development server
  bundle exec rspec                # run test suite
  bundle exec rubocop              # lint
  bin/rails tailwindcss:build      # rebuild CSS
  bin/rails db:prepare             # create + migrate postgres databases

## Key files

| File | Purpose |
|------|---------|
| app/controllers/application_controller.rb | Pundit, Pagy::Backend, layout routing |
| app/helpers/application_helper.rb | Pagy::Frontend |
| app/helpers/settings_helper.rb | multi_tenant_mode?, show_landing_page? |
| app/views/layouts/ | application, dashboard, devise layouts |
| app/views/shared/ | flash, user_menu, page_header, pagination partials |
| app/assets/tailwind/application.css | Tailwind 4 + daisyUI config |
| config/initializers/pagy.rb | pagination config |
| config/initializers/friendly_id.rb | slug config |
| config/initializers/meta_tags.rb | SEO config |
| docs/ARCHITECTURE.md | domain model, layout system |
| docs/CONVENTIONS.md | coding conventions, UI patterns |

## Layout system
Three layouts, selected automatically by
ApplicationController#determine_layout:
- layouts/application — public/marketing pages
- layouts/dashboard — authenticated pages
- layouts/devise — auth pages (login, register, etc.)

## What NOT to do
- Do not use Bootstrap or Tabler classes anywhere
- Do not add kaminari — pagy is already configured
- Do not use form-control, label-text (daisyUI 4 classes)
  See docs/CONVENTIONS.md for daisyUI 5 migration reference
- Do not use rails_admin — not installed
- Do not install Redis — Solid Queue handles background jobs
- Do not write raw SQL — use ActiveRecord
- Do not put business logic in controllers — use models

## Deferred views (still Bootstrap — rebuild when needed)
- app/views/spaces/ — 11 files
- app/views/users/ — 3 files
When rebuilding these, follow docs/CONVENTIONS.md
UI patterns and daisyUI 5 class reference.

## Further reading
- docs/ARCHITECTURE.md — domain model, request lifecycle
- docs/CONVENTIONS.md — conventions + daisyUI 5 cheatsheet
- docs/SETUP.md — first-time setup instructions
- docs/template/ — template build history (ignore for app dev)

## Current status
- RSpec: 102 examples, 0 failures
- RuboCop: 108 files, 0 offenses
- All layouts rebuilt in Tailwind + daisyUI 5
- Turbo Drive enabled
- Devise request specs complete
- All models annotated (annotaterb)
