# Prusa Print History

[![CI](https://img.shields.io/github/actions/workflow/status/romkey/pdxhackerspace-prusa-print-history/ci.yml?label=CI)](https://github.com/romkey/pdxhackerspace-prusa-print-history/actions/workflows/ci.yml)
[![Lint](https://img.shields.io/github/actions/workflow/status/romkey/pdxhackerspace-prusa-print-history/ci.yml?label=lint)](https://github.com/romkey/pdxhackerspace-prusa-print-history/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/actions/workflow/status/romkey/pdxhackerspace-prusa-print-history/release.yml?label=release)](https://github.com/romkey/pdxhackerspace-prusa-print-history/actions/workflows/release.yml)
[![Version](https://img.shields.io/github/v/tag/romkey/pdxhackerspace-prusa-print-history?label=version&sort=semver)](https://github.com/romkey/pdxhackerspace-prusa-print-history/releases)
[![Ruby](https://img.shields.io/badge/Ruby-3.3.11-red?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1-red?logo=rubyonrails&logoColor=white)](https://rubyonrails.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Rails application that tracks and reports the printing history of multiple
Prusa 3D printers. It polls PrusaLink for job + temperature data, layers
in enclosure / humidity / ambient readings from Home Assistant, grabs a
camera snapshot on every status change, and serves it all behind a
viewer-aware UI:

| Tier                    | Access                                                                 |
|-------------------------|------------------------------------------------------------------------|
| Anonymous (off internal networks) | Public printer dashboard at `/` only.                                |
| Anonymous (on `INTERNAL_NETWORKS`) | Dashboard, jobs, and printers; can clear prints.                     |
| Logged-in non-admin     | All of the above, plus claim/release a job and a "My prints" filter.   |
| Admin                   | All of the above, plus add/edit/delete printers, app settings, Sidekiq.|

## Requirements

- Ruby 3.3.11
- Node 24.x (for Bootstrap / Sass build)
- PostgreSQL 18
- Redis 8 (Sidekiq + ActiveJob)
- Docker + Docker Compose v2

All of the above are baked into the Docker images, so a working Docker
install is enough for local development.

## Stack

| Layer       | Choice                                            |
|-------------|---------------------------------------------------|
| Web         | Rails 8.1, Puma + Thruster                        |
| Database    | PostgreSQL 18 (`pg` gem)                          |
| Background  | Sidekiq 8 + sidekiq-cron, Redis 8                 |
| Auth        | OmniAuth + Authentik (OIDC)                       |
| Frontend    | Bootstrap 5.2.3, Bootstrap Icons, Hotwire (Turbo + Stimulus), importmap-rails |
| Asset build | cssbundling-rails (Sass via Yarn)                 |
| Test        | Minitest, Capybara + Selenium                     |
| Lint        | RuboCop (rails / performance / minitest plugins)  |

## Required environment

The application reads its configuration from `.env` in development/test
and the process environment in production. See [.env.example](.env.example)
for the full list; the values you must set on a fresh install are:

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
  `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`,
  `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` &mdash; generate with
  `docker compose -f docker-compose.dev.yml --profile tools run --rm shell
  bin/rails db:encryption:init` and copy the values into `.env`.
- `HOME_ASSISTANT_URL` and `HOME_ASSISTANT_TOKEN` &mdash; long-lived
  access token from a Home Assistant user. The Settings page shows a
  health card so you can confirm connectivity.
- `AUTHENTIK_ISSUER`, `AUTHENTIK_CLIENT_ID`, `AUTHENTIK_CLIENT_SECRET`,
  `AUTHENTIK_REDIRECT_URI` &mdash; OpenID Connect credentials from your
  Authentik application. Admin access is granted only when Authentik
  returns `is_admin: true` in the OIDC userinfo response when the user has admin access.
- `LOCAL_ADMIN_EMAIL`, `LOCAL_ADMIN_PASSWORD`, and optionally
  `LOCAL_ADMIN_NAME` — when email and password are both set, the login
  page shows a password form that signs in as a local admin account
  (no Authentik required). Useful for single-user or offline setups.
- `TIMEZONE` — IANA timezone name (e.g. `America/Los_Angeles`) used
  for displaying job timestamps and relative times. Defaults to `UTC`.
- `SMTP_SERVER`, `MAIL_FROM`, and related `SMTP_*` vars — required for
  email notifications. Each user chooses email vs Slack under
  **Notifications** in the account menu. Without `SMTP_SERVER`, email is
  not offered. In development without SMTP, outgoing mail is written to
  `tmp/mail/` instead.
- `SLACK_API_TOKEN` — bot token with `chat:write`, `files:write`, and `im:write`;
  used to DM claimants who opt in and have a Slack user ID on their profile.

## Local development

The dev stack runs Postgres, Redis, the Rails web server, a CSS watcher,
and a Sidekiq worker. Source is bind-mounted into the container at
`/rails`, so host edits show up instantly with no rebuild.

```bash
cp .env.example .env

# First time only — build the dev image
docker compose -f docker-compose.dev.yml build

# First time only — install JS deps + create the database (generates yarn.lock)
docker compose -f docker-compose.dev.yml --profile tools run --rm shell \
  bash -c "yarn install && bin/rails db:prepare"

# Run the full stack
docker compose -f docker-compose.dev.yml up
```

App at <http://localhost:3000>, Sidekiq UI at <http://localhost:3000/sidekiq>.

Other helpers:

```bash
# Rails console
docker compose -f docker-compose.dev.yml --profile tools run --rm console

# Run a migration
docker compose -f docker-compose.dev.yml --profile tools run --rm migrate

# Drop into a shell
docker compose -f docker-compose.dev.yml --profile tools run --rm shell
```

All container names, networks, and volumes are prefixed with
`prusa-print-history-dev-` so they don't collide with other Rails projects
on the same machine.

## Tests

```bash
docker compose -f docker-compose.test.yml run --rm test
```

This creates a throwaway test database (Postgres on a tmpfs), runs
`bin/rails db:test:prepare`, then `bin/rails test`. Pass extra args to
target a subset:

```bash
docker compose -f docker-compose.test.yml run --rm test bin/rails test test/models
```

If you change the test image (e.g. Ruby version, system packages), force
a rebuild:

```bash
docker compose -f docker-compose.test.build.yml build
docker compose -f docker-compose.test.build.yml run --rm test
```

## Lint

```bash
# Build the lint image once
docker compose -f docker-compose.lint.build.yml build rubocop

# Subsequent runs are fast — bind-mounted source, no rebuild
docker compose -f docker-compose.lint.yml run --rm rubocop
```

To auto-correct:

```bash
docker compose -f docker-compose.lint.yml run --rm rubocop --auto-correct
```

## Production

The production image is built by GitHub Actions and pushed to GHCR on
every `v*` tag. To run it behind your own reverse proxy:

```bash
# .env.production has SECRET_KEY_BASE, DATABASE_URL, IMAGE, WEB_PORT, etc.
docker compose -f docker-compose.server.yml --env-file .env.production up -d
```

Pending database migrations run automatically when the `web` or `sidekiq`
container starts (via `bin/docker-entrypoint`, which calls `db:prepare`).
You do not need a separate migrate step on staging or production. Set
`SKIP_DB_MIGRATE=true` on a one-off container if you need to bypass that.

The `web` service exposes Rails on `WEB_PORT` (default 3000); point your
reverse proxy at that.

## CI / CD

- `.github/workflows/ci.yml` — runs on every push to any branch (tags
  excluded) and every PR; runs RuboCop and the full test suite against
  Postgres 18 + Redis 8 services.
- `.github/workflows/release.yml` — triggered by `v*` tags; builds the
  production image for `linux/amd64` and `linux/arm64` and pushes it to
  `ghcr.io/<owner>/prusa-print-history` with `vX.Y.Z`, `vX.Y`, `vX`, and
  `latest` tags.

## Versioning

The canonical version lives in `VERSION` (and is also embedded in the
`APP_VERSION` environment variable). Bump it before opening a
`staging → main` release PR — see `.cursor/rules/deployment-rules.mdc`
for the full workflow.

## Project layout

```
app/                  Rails application code
config/               Rails + Sidekiq + Pagy config
docker-compose.*.yml  One file per stack (dev / test / lint / server)
Dockerfile            Production image (multi-stage, slim, non-root)
Dockerfile.dev        Thin dev/test image (bind-mounted source)
Dockerfile.rubocop    Lint image (rubocop + plugins only)
.github/workflows/    CI + release workflows
```
