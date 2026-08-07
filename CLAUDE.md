# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

Rails 8.1 app that tracks print history for a fleet of Prusa 3D printers. Every minute Sidekiq
polls each printer's PrusaLink API and captures a camera photo; readings from Home Assistant
(enclosure temp/humidity, ambient) are merged in; state changes become `JobEvent` rows and
notify the job's claimant via email or Slack.

## Commands

Everything runs through Docker Compose — one file per stack. Source is bind-mounted, so no
rebuild is needed after editing Ruby/ERB.

```bash
# Dev stack (postgres, redis, web on :3000, css watcher, sidekiq)
docker compose -f docker-compose.dev.yml up

# One-off tools (profile 'tools'): console, shell, migrate
docker compose -f docker-compose.dev.yml --profile tools run --rm console
docker compose -f docker-compose.dev.yml --profile tools run --rm migrate
docker compose -f docker-compose.dev.yml --profile tools run --rm shell bash -c "yarn install && bin/rails db:prepare"

# Full test suite (throwaway tmpfs Postgres; prepares the DB itself)
docker compose -f docker-compose.test.yml run --rm test

# A subset / a single test
docker compose -f docker-compose.test.yml run --rm test bin/rails test test/services/printer_poller_test.rb
docker compose -f docker-compose.test.yml run --rm test bin/rails test test/models/job_test.rb:42

# Lint (build the image once, then reruns are fast)
docker compose -f docker-compose.lint.build.yml build rubocop
docker compose -f docker-compose.lint.yml run --rm rubocop
docker compose -f docker-compose.lint.yml run --rm rubocop --auto-correct
```

Use `docker-compose.test.build.yml` / `docker-compose.lint.build.yml` when the image itself
changed (Ruby version, system packages). CI runs the same RuboCop image plus `bin/rails test`
against Postgres 18 + Redis 8.

## Architecture

### Polling pipeline — the core of the app

`FanOutPrinterPollsJob` (cron, every minute) enqueues a `PrinterPollJob` per printer, which runs
`PrinterPoller` (`app/services/printer_poller.rb`, the largest and most important class).
`PrinterPoller#poll!`:

- calls `PrusaLink::Client` (`/api/v1/status`, `/api/v1/job`, `/api/v1/info`, legacy
  `/api/printer`, file metadata) and maps Prusa states to app statuses via `PRUSA_TO_STATUS`,
- creates/updates the `Job` row, syncs `PrinterHead` and `Tool` rows, appends `TelemetryReading`s,
- writes `JobEvent` rows on status transitions (`EVENT_TYPE_FOR_STATUS`) and enqueues
  `CaptureEventPhotoJob` so every transition has a photo,
- merges Home Assistant sensor values (`HomeAssistant::Client`; a printer's sensors are derived
  from `ha_base_sensor` + fixed suffixes),
- records PrusaLink reachability and calls `PrinterLiveBroadcaster` to push a Turbo Stream
  replace of the printer's live panel.

`FanOutPrinterPhotoCapturesJob` runs the same fan-out shape for `PrinterPhotoCapture`, which
stores an ActiveStorage image on a `PhotoCapture` (one rolling idle photo per printer; a growing
series while a job is active) and enqueues `PrusaConnectPhotoUploadJob` to mirror it to Prusa
Connect.

Statuses live in two parallel vocabularies: `Job::STATUSES` (pending/printing/paused/attention/
error/finished/cancelled, with `ACTIVE_STATUSES` and `TERMINAL_STATUSES`) and
`Printer::OPERATIONAL_STATES`.

### Authorization — four tiers, no gem

There is no Pundit/CanCan. `ApplicationController` exposes `current_user`, `logged_in?`,
`admin?`, `internal_network?`, `can_clear_prints?` as helpers, and controllers use the
`require_login`, `require_admin`, `require_login_or_internal`, `require_admin_or_internal`
before_action filters. `internal_network?` is IP-based via `lib/internal_networks.rb` reading the
`INTERNAL_NETWORKS` CIDR list — anonymous visitors on the shop network get more than anonymous
visitors from the internet. Admin comes from Authentik's `is_admin` OIDC claim (see
`User.apply_admin_from_auth`); `LOCAL_ADMIN_EMAIL`/`LOCAL_ADMIN_PASSWORD` enable a password login
path (`sessions#create_local`, `LocalAdmin`, rate-limited by `LocalLoginRateLimiter`).
`AdminConstraint` gates the mounted Sidekiq Web UI.

### Encryption

`User` encrypts email/name/username/slack_id/slack_handle and `Printer` encrypts `prusalink_key`
and `prusa_connect_token` via Active Record encryption. Email and slack_id are `deterministic:
true` because they're looked up. Fixtures are plaintext in YAML and re-encrypted in
`test_helper.rb`'s `encrypt_sensitive_fixtures!` setup hook — add any new encrypted model there.

### Service objects

`app/services/` holds all non-trivial logic; controllers and models stay thin. Roughly:
external clients (`PrusaLink::`, `PrusaConnect::`, `HomeAssistant::`, `Slack::Messenger`,
`CupsService`), presenters that assemble view data (`DashboardPresenter`,
`PrinterShowPresenter`, `JobPhotosPresenter`, `JobTimeline*`, `JobTelemetryCharts`), and
workflows (`JobClearPrintService`, `JobNotificationService`, `PrintTimeAccounting`,
`PrintTimeReport`, `JobLabelPdf` + `JobLabelPrintService` for Prawn labels sent to CUPS).

`Job` has an `after_commit` that calls `PrintTimeAccounting.sync_users_for_job!` whenever
status/duration/owner changes — denormalized per-user print totals depend on it.

### Settings

App-level config not in env lives in the `settings` key/value table. `Setting::KEYS` is a
whitelist validated on write; add a key there plus the paired `Setting.foo` / `Setting.foo=`
accessors. `HomeAssistantHealthJob` writes `ha_last_*` keys that the Settings page renders.

## Conventions

- Ruby style follows `.rubocop.yml`: single quotes, 120-char lines, **no**
  `# frozen_string_literal: true` comments, all new cops enabled. Guard clauses over nesting;
  extract rather than exceed `Metrics/MethodLength: 20` / `ClassLength: 150` (disable comments
  are used sparingly — `PrinterPoller` is the one class-length exception).
- Tests are Minitest with `fixtures :all`, mirroring `app/` structure under `test/`. Never hit a
  real PrusaLink / Prusa Connect / Home Assistant / Slack endpoint — inject a fake client (most
  services take a `client:` keyword for exactly this). Integration tests default to
  `REMOTE_ADDR 127.0.0.1`, which `test_helper.rb` configures as internal; use
  `external_request_headers` to test the anonymous-from-the-internet tier, and `login_as(user)`
  (OmniAuth test mode) to sign in.
- **Never set `config.active_job.queue_name_prefix`.** It double-applies with sidekiq-cron's
  `active_job: true` and creates ghost queues. Queues are plain (`default`, `mailers`). Cron
  entries in `config/schedule.yml` must use `active_job: true` and must not set an explicit
  `queue:` — let the job class's `queue_as` decide.
- Views are Bootstrap 5 + Hotwire; prefer Turbo Frames/Streams over hand-written JS. The
  detailed visual rules (color encodes meaning, one `btn-primary` per region, `-subtle` badges,
  `.table-compact`, dot-not-pill statuses, relative dates) live in `.cursor/rules/ui.mdc` — read
  it before building any new page.
- Migrations must be reversible, index anything filtered/ordered/joined on, and add `NOT NULL`
  with a default when adding required columns to existing tables.
- Update `CHANGELOG.md` under `[Unreleased]` for any user-facing change, written from the user's
  perspective. Update `README.md` when requirements, setup steps, env vars, or architecture change.

## Branching and release

`main` is the only long-lived branch and work is pushed **directly to it** — don't insist on a
PR. Optional `feature/*` / `fix/*` branches are fine for larger changes. Releasing means:
bump `VERSION`, move `CHANGELOG.md`'s `[Unreleased]` entries under `[X.Y.Z] - YYYY-MM-DD`, push
to `main`, then push a `vX.Y.Z` tag — `release.yml` builds and pushes the multi-arch image to
`ghcr.io/romkey/prusa-print-history`. Migrations run automatically on container start via
`bin/docker-entrypoint` (`db:prepare`); there is no separate deploy migrate step.

A protected `main` with a `staging` integration branch is planned but **not in effect** — see
`.cursor/rules/deployment-rules.mdc`, which will say so when it changes.

Only commit or push when explicitly asked.

## `.cursor/rules/`

These are current and authoritative; read the one matching what you're touching.
`deployment-rules.mdc` and `rails-project.mdc` and `ui.mdc` apply always. The others are
scoped by glob: `ruby-style.mdc`, `testing.mdc`, `database.mdc`, `docker-ci.mdc`,
`sidekiq-queues.mdc`, `views-bootstrap.mdc`, `documentation-readme.mdc`,
`documentation-changelog.mdc`.
