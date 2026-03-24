# Architecture Decision Log

## 2026-03-24 — Converted this template to PostgreSQL-first
Reason: this repository is now the dedicated PostgreSQL sibling starter.
We intentionally removed SQLite as a supported default in this template and
standardized database configuration, Docker runtime dependencies, and CI on PostgreSQL.
Solid Queue, Solid Cache, and Solid Cable remain database-backed and are configured
to use PostgreSQL databases (`primary`, `queue`, `cache`, `cable`).

## 2026-03-12 — Upgraded to Ruby 4.0.1
Upgraded from Ruby 3.4.4 to Ruby 4.0.1 for latest language features and security updates.

## 2026-03-12 — Chose Devise over authentication-zero
Reason: rails-tabler-starter already had Devise fully integrated with 
the Space/multitenancy model and role system. The integration cost of 
switching to authentication-zero outweighed the AI-friendliness benefit 
at this stage. Revisit if starting a greenfield app.

## 2026-03-12 — Chose SQLite over PostgreSQL as default (superseded)
Superseded on 2026-03-24 when this repository was converted into a dedicated
PostgreSQL starter template.

## 2026-03-12 — Removed rails_admin
Reason: Redundant with the custom admin area. Heavyweight, not 
Tailwind-compatible, added unnecessary complexity to the asset pipeline.

## 2026-03-12 — Chose pagy over kaminari
Reason: Faster, lighter, better daisyUI pagination component support.

## 2026-03-12 — Re-enabled Turbo Drive
Turbo Drive was disabled in the original starter to prevent conflicts with Bootstrap/Tabler JS. Re-enabled after Bootstrap removal since daisyUI is CSS-only and has no Turbo conflicts.

## 2026-03-12 — Chose 3 fixed layouts over 9 Bootstrap layout variants
Original starter had 9 layout variants driven by AppSettings.interface_layout. Replaced with 3 purposeful layouts: application (marketing), dashboard (authenticated), devise (auth). Simpler, more AI-friendly, easier to maintain. Old layouts archived in app/views/body/_archive/.

## 2026-03-12 — Removed interface_layout and login_layout from SettingsHelper
These were Bootstrap/Tabler theming helpers. Kept multi_tenant_mode? and show_landing_page? as they are genuinely useful across apps.

## 2026-03-12 — friendly_id reserved_words not configurable globally in v5.x
FriendlyId 5.x does not support config.reserved_words= globally. Reserved words must be set per-model if needed. Global initializer kept as documentation only.

## 2026-03-13 — Upgraded to Tailwind CSS 4 + daisyUI 5
tailwindcss-rails 4.4.0, tailwindcss v4.2.0, daisyUI 5.5.19.
Entry point moved from app/assets/stylesheets/application.tailwind.css
to app/assets/tailwind/application.css (new v4 convention).
Config moved from tailwind.config.js (deleted) into CSS directives:
@import, @plugin, @theme, @source.
daisyUI loaded via npm as @plugin "daisyui".
daisyUI 5 has ~15 class renames from v4 — views updated on-demand
as each view is rebuilt, not preemptively.

## 2026-03-13 — Replaced annotate with annotaterb
annotate 2.6.5 uses File.exists? which was removed
in Ruby 4.0. annotaterb is the maintained fork,
API-compatible, fully supports Ruby 4.0.1.

## 2026-03-13 — Devise paranoid mode confirmed
config.paranoid = true is set in devise.rb.
Password reset does not reveal whether an email
exists in the database. Specs reflect this —
both known and unknown emails assert no observable
email delivery change.

## 2026-03-13 — Chose not to add .env.example
Rails 8 uses config/credentials.yml.enc for secrets.
A .env.example file would imply a dotenv workflow
that does not exist in this app. Credentials are
managed via bin/rails credentials:edit.
RAILS_MASTER_KEY is set in the hosting platform
(e.g. Hatchbox) for production.
