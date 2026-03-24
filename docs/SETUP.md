# Setup

## First-time setup

### Prerequisites
- Ruby 4.0.1 (rbenv or asdf recommended)
- Bundler 2.x
- Node.js + npm (for daisyUI)
- PostgreSQL 14+ (or equivalent recent version)

Make sure PostgreSQL is running locally and your user can create databases.
Defaults in `config/database.yml` use:
- host: `127.0.0.1`
- port: `5432`
- user: your current shell user (`$USER`) unless `POSTGRES_USER` is set
- password: `POSTGRES_PASSWORD` env var (optional, but usually needed)

### Setup

  git clone <your-repo-url>
  cd <app-name>
  bundle install
  npm install
  cp .env.sample .env
  bin/rails db:prepare
  bin/dev

Visit http://localhost:3000

### Verify

  bundle exec rspec        # target: 0 failures
  bundle exec rubocop      # 0 offenses

## Credentials

Rails 8 uses encrypted credentials for secrets.
This template also supports `.env` for local, non-credential config
like PostgreSQL connection settings.

To view or edit credentials:

  bin/rails credentials:edit

The master key is in config/master.key (gitignored).
Never commit config/master.key.
When deploying, set the RAILS_MASTER_KEY environment
variable in your hosting platform (e.g. Hatchbox).
