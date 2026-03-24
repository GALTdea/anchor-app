# My Rails Starter

A personal Rails 8 starter template.
Built on Ruby 4.0.1, Tailwind CSS 4, daisyUI 5,
Devise, Pundit, Hotwire, and Solid Queue.
This template is PostgreSQL-first.

## Quick start (new app from template)

### 1. Create a new repo from this template
On GitHub, click **"Use this template"** →
**"Create a new repository"**.
Clone your new repo locally.

### 2. Rename the app
```bash
bin/rename MyNewAppName
```

### 3. Set up
```bash
bin/setup
```

### 4. Start
```bash
bin/dev
```

Visit http://localhost:3000

Default login: `admin@example.com` / `password123`

---

## Stack

| Layer | Technology |
|-------|-----------|
| Language | Ruby 4.0.1 |
| Framework | Rails 8.1.2 |
| Database | PostgreSQL |
| Frontend | Hotwire (Turbo + Stimulus) |
| CSS | Tailwind CSS 4 + daisyUI 5 |
| Auth | Devise + devise_invitable |
| Authorization | Pundit |
| Background jobs | Solid Queue |
| Pagination | Pagy |
| Deployment | Kamal |

---

## Development
```bash
bin/dev                      # start server + CSS watcher
bin/rails db:prepare         # create + migrate all postgres DBs
bundle exec rspec            # run tests
bundle exec rubocop          # lint
bin/rails tailwindcss:build  # rebuild CSS manually
bin/rails db:seed            # reload seed data
```

---

## Docs

| File | Purpose |
|------|---------|
| docs/AGENTS.md | AI agent entry point — read first |
| docs/ARCHITECTURE.md | Domain model, layout system |
| docs/CONVENTIONS.md | Coding conventions, daisyUI patterns |
| docs/SETUP.md | Detailed setup instructions |
| docs/template/ | Template build history (ignore for app dev) |

---

## Creating a new app from this template

1. Click **"Use this template"** on GitHub
2. Clone your new repo
3. Run `bin/rename YourAppName`
4. Run `bin/setup`
5. Run `bin/dev`
6. Commit: `git commit -m "Initialize from my-rails-starter"`

---

## Template versions

See [releases](../../releases) for changelog.
