# Template Maintenance Guide

Complete reference for developers who improve this starter template. For building apps *from* this template, use docs/AGENTS.md and docs/CONVENTIONS.md instead.

---

## Overview

This template is a **Rails 8 starter** for building multi-tenant SaaS-style applications. It solves the problem of starting from a clean, modern stack (Ruby 4, Rails 8, Tailwind CSS 4, daisyUI 5, Devise, Pundit, Solid Queue) with sensible defaults, AI-friendly documentation, and no Bootstrap/Tabler legacy.

It was built **from** [rails-tabler-starter](https://github.com/nicedoc/rails-tabler-starter), which provided the base Rails 8 app, Devise, multitenancy (Space/Role), and deployment (Kamal). This template replaced Bootstrap 5 + Tabler with Tailwind CSS 4 + daisyUI 5, removed rails_admin and kaminari, simplified the layout system, and added a full AI documentation layer.

---

## Current template version and stack

Exact versions and configuration:

- **Ruby** 4.0.1
- **Rails** 8.1.2
- **PostgreSQL** (default)
- **Hotwire** (Turbo + Stimulus), importmap, propshaft
- **Tailwind CSS** 4.2.0 + **daisyUI** 5.5.19  
  - tailwindcss-rails 4.4.0, daisyUI via npm as `@plugin`  
  - config: `app/assets/tailwind/application.css`
- **Devise** 5.0.2 + devise_invitable
- **Pundit** (authorization)
- **Solid Queue** (background jobs, no Redis)
- **Pagy** 9.x (pagination)
- **friendly_id** 5.x (slug-based URLs)
- **meta-tags** 2.x (SEO)
- **RSpec** + **FactoryBot** (testing)
- **Kamal** (deployment)
- **RuboCop-rails-omakase**
- **annotate**, **letter_opener**, **bullet**, **rack-mini-profiler**

---

## What was changed from rails-tabler-starter

### Removed

- **rails_admin** — redundant with custom admin area, not Tailwind compatible
- **kaminari** — replaced with pagy
- **Bootstrap 5 + Tabler** — all JS, CSS, importmap pins
- **Font Awesome**, **ApexCharts**, **jsvectormap**
- **9-variant layout system** driven by AppSettings
- **Bootstrap theming helpers** from SettingsHelper:  
  `color_mode`, `theme_base`, `theme_font`, `primary_color`, `corner_radius`, `interface_layout`, `login_layout`
- **rails_admin** routes, initializer, JS, SCSS
- **Turbo.session.drive = false** — was disabled for Bootstrap JS conflicts; no longer needed

### Added

- **Tailwind CSS 4.2.0** via tailwindcss-rails gem
- **daisyUI 5.5.19** via npm as `@plugin`
- **pagy** 9.x (pagination)
- **friendly_id** 5.x (slug-based URLs)
- **meta-tags** 2.x (SEO)
- **3 purposeful layouts**: application, dashboard, devise
- **Shared partials**: flash, user_menu, user_menu_compact, page_header, pagination
- **bin/setup** script
- **bin/rename** script
- **Seed data**: admin + regular user + default space
- **Full AI documentation layer** (AGENTS.md, CONVENTIONS.md, SETUP.md, ARCHITECTURE.md, docs/template/, docs/modules/)

### Rebuilt in Tailwind + daisyUI

- All 3 layouts
- Devise views (login, register, password)
- Landing page
- Setup/AppSettings view
- Error pages (404, 422, 500)

### Simplified

- **SettingsHelper**: kept only `multi_tenant_mode?` and `show_landing_page?`
- **Module name**: RailsTabler8 → MyRailsStarter
- **App name references** updated in Dockerfile, deploy.yml, manifest.json.erb

---

## Build phases completed

Historical context for how the template was built:

- **Phase 1** — Gem cleanup (rails_admin, kaminari removal; pagy, friendly_id, meta-tags added)
- **Phase 2** — Tailwind + daisyUI foundation
- **Phase 3** — Layout system rebuild (3 layouts, shared partials)
- **Phase 4** — Active file cleanup (importmap, assets)
- **Phase 5** — Gem configuration (pagy, friendly_id, meta-tags initializers)
- **Phase 6** — Bug fixes (kaminari remnants, friendly_id initializer)
- **Phase 7** — AI documentation layer
- **Upgrade 1** — Ruby 3.4.4 → 4.0.1
- **Upgrade 2** — Tailwind CSS 3 → 4, daisyUI 5 via npm
- **Cleanup 1** — assets.rb, docs sync, daisyUI 5 cheatsheet
- **Cleanup 2** — Docs reorganization (template/ vs app-dev)
- **Cleanup 3** — bin/setup, bin/rename, seeds, README
- **Upgrade 3** — PostgreSQL-first template conversion

---

## Completed checklist

- [x] Base rails-tabler-starter on Ruby 4.0.1 / Rails 8.1.2
- [x] AI documentation layer
- [x] rails_admin removed
- [x] kaminari replaced with pagy
- [x] Bootstrap/Tabler pipeline replaced with Tailwind CSS 4.2.0 + daisyUI 5.5.19
- [x] App module renamed to MyRailsStarter
- [x] friendly_id installed and configured
- [x] meta-tags installed and configured
- [x] 3 layouts rebuilt in Tailwind + daisyUI
- [x] Shared partials created
- [x] Devise views rebuilt in Tailwind + daisyUI
- [x] Landing page rebuilt
- [x] Setup/AppSettings view rebuilt
- [x] Error pages rebuilt (404, 422, 500)
- [x] Turbo Drive re-enabled
- [x] Importmap cleaned
- [x] assets.rb cleaned
- [x] Ruby upgraded to 4.0.1
- [x] Tailwind CSS upgraded to 4.2.0
- [x] daisyUI 5 via npm
- [x] docs reorganized (template/ vs app-dev)
- [x] bin/setup and bin/rename scripts
- [x] Seed data (users + space)
- [x] README rewritten
- [x] RuboCop clean: 0 offenses
- [x] RSpec: 80 examples, 0 failures
- [x] SQLite removed as template database default
- [x] PostgreSQL adopted across app config, CI, and docs

---

## Intentionally deferred (rebuild per app)

These views remain in Bootstrap; rebuild when needed per app, following docs/CONVENTIONS.md:

- [ ] spaces/ views (Bootstrap, 11 files)
- [ ] users/ views (Bootstrap, 3 files)
- [ ] spaces/roles views
- [ ] spaces/subscriptions views
- [ ] Devise remaining views (password reset, edit registration, confirmation, unlock, invitation)

---

## Planned improvements (next tasks)

- [x] Mailer defaults configured
      (letter_opener, default_url_options,
      perform_deliveries in development.rb)
- [x] FactoryBot factories complete
      (User, Space, Role, UserRole, Plan, Subscription
      — all verified against schema)
- [x] annotaterb replacing annotate
      (annotate 2.6.5 incompatible with Ruby 4.0.1)
- [x] Flash messages audited — all 3 layouts correct
- [ ] ApplicationPolicy default defined
      (deny by default for SaaS)
- [x] GitHub Actions CI workflow
      (.github/workflows/ci.yml — see How to work
      on the template for the workflow structure)
- [ ] docs/template/UPGRADING.md
- [ ] docs/modules/ content written
      (billing, api, file_uploads, multitenancy)

---

## Optional modules (documented, not installed)

These live in docs/modules/ — install per app:

- docs/modules/api.md
- docs/modules/billing.md
- docs/modules/file_uploads.md
- docs/modules/multitenancy.md

*(Currently placeholder files; content to be added per module.)*

---

## How to work on the template

1. `git checkout -b improvement-name`
2. Make changes
3. `bundle exec rspec && bundle exec rubocop`
4. `bin/rails tailwindcss:build`
5. Merge to main
6. Update this file (checklist + phase history as needed)
7. Update docs/template/DECISIONS.md if an architecture decision was made
8. Tag: `git tag -a vX.X.X -m "description"`
9. `git push origin main --tags`

---

## Version history

- **v1.0.0** — Base template
- **v1.0.1** — Ruby 4.0.1 upgrade
- **v1.0.2** — Fix daisyUI missing from package.json
- **v1.1.0** — Tailwind CSS 4 + daisyUI 5 via npm
- **v1.1.1** — Fix assets.rb, sync docs to current stack
- **v1.2.0** — Docs reorganization
- **v1.2.1** — bin/setup, bin/rename, seeds, README
 - **v1.2.2** — Add MAINTENANCE.md, complete 
   template docs
 - **v1.2.3** — Write ARCHITECTURE.md
 - **v1.2.4** — Replace annotate with annotaterb,
   mailer config, factory audit
 - **v1.2.5** — Devise request specs
   (102 examples, 0 failures)
 - **v1.3.0** — PostgreSQL-first starter conversion

---

## Testing baseline

Always verify before tagging a new version:

```bash
bundle exec rspec                    # target: 0 failures
bundle exec rubocop                 # target: 0 offenses
bin/rails tailwindcss:build         # target: no errors
bin/rails runner "puts 'OK'"        # target: OK
```
