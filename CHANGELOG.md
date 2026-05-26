# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.11] - 2026-05-26

### Added
- Temperature chart on the job show page (bed, enclosure, ambient, tool heads).
- PrusaLink connectivity dot on the printer page (green = reachable, red = failed).
- Masked PrusaLink API key on printer settings once configured.

## [0.1.10] - 2026-05-26

### Fixed
- Print completion now registers when PrusaLink reports `FINISHED` but the job
  API is already empty (common after a print ends).

### Added
- Live printer page updates via Action Cable + Turbo Streams (refreshes every poll).
- Expanded printer page: full job details, tool heads, job events, temperature
  charts (Chartkick), and environment readings.
- Tool metadata sync from PrusaLink job file meta during polling.

## [0.1.9] - 2026-05-26

### Fixed
- Gracefully degrade when v0.1.7 environment columns are not migrated yet: status
  and ambient display fall back to job-based data instead of raising 500.

## [0.1.8] - 2026-05-26

### Fixed
- Docker entrypoint now runs `db:prepare` when the app starts via `./bin/thrust
  ./bin/rails server`, so migrations apply automatically on deploy.

## [0.1.7] - 2026-05-26

### Fixed
- Printers now report idle when PrusaLink returns IDLE/READY: active jobs are
  finalized and `operational_state` is updated on every poll.

### Changed
- Ambient temperature is always shown on the printer page (Environment card),
  updated on every poll even when no job is running.

## [0.1.6] - 2026-05-25

### Fixed
- Stop forcing HTTPS in production: `RAILS_FORCE_SSL` now defaults to off, session
  cookies default to non-Secure, and `APP_PROTOCOL` defaults to `http`. Set the
  TLS env vars explicitly when you want to require HTTPS.

### Changed
- Configurable `TIMEZONE` env var for displaying job timestamps; hover tooltips
  use a precise local-time format.

## [0.1.5] - 2026-05-26

### Fixed
- Login CSRF failures behind a reverse proxy: stop using `assume_ssl` by default,
  trust proxy networks, and honor `X-Forwarded-Proto` so session cookies are
  only marked Secure for HTTPS clients.

## [0.1.4] - 2026-05-26

### Fixed
- Release workflow manifest merge: build fully qualified `image@sha256:digest`
  sources instead of passing bare hash filenames to `imagetools create`.

## [0.1.3] - 2026-05-26

### Fixed
- System dark mode now follows OS preference via Bootstrap `$color-mode-type:
  media-query`; removed the navbar-only dark override that caused unreadable
  light-on-light text.
- Local admin login behind a TLS-terminating reverse proxy: disable CSRF origin
  scheme check in production, disable Turbo on the login form, add `APP_HOST`.

## [0.1.2] - 2026-05-26

### Changed
- Speed up release Docker builds: BuildKit cache mounts for apt, Bundler, and
  Yarn; prebuilt Node binaries instead of node-build; parallel native amd64/arm64
  builds on GitHub Actions with per-platform GHA and registry layer caches.

## [0.1.1] - 2026-05-26

### Added
- System-default light/dark mode via Bootstrap `data-bs-theme="auto"`.
- Optional local admin login configured with `LOCAL_ADMIN_EMAIL` and
  `LOCAL_ADMIN_PASSWORD` in `.env`.

### Changed
- Bootstrap upgraded from 5.2.3 to 5.3.3 for native color-mode support.

## [0.1.0] - 2026-05-25

### Added
- Initial Rails 8.1 skeleton (Ruby 3.3.11, PostgreSQL 18, Redis 8, Sidekiq 8).
- Bootstrap 5.2.3 + Bootstrap Icons via cssbundling-rails and importmap-rails.
- Sidekiq Web UI mounted at `/sidekiq`, admin-gated, sidekiq-cron support via
  `config/schedule.yml`.
- Pagy for pagination, dotenv-rails for env loading.
- Docker stacks for development, test, lint, and production (namespaced per
  project so they coexist with other Rails apps on the same host).
- Bind-mounted source for dev/test/lint so changes don't require a rebuild.
- GitHub Actions: `ci.yml` runs RuboCop and the test suite on every push/PR
  (tags excluded); `release.yml` builds and publishes a multi-arch Docker
  image to GHCR on every `v*` tag.
- Domain models: `User`, `Printer`, `Job`, `Tool`, `TelemetryReading`,
  `JobEvent`, `Setting`. `Printer#prusalink_key` is encrypted at rest via
  Active Record encryption.
- PrusaLink and Home Assistant HTTP clients (`app/services/`) plus a
  best-effort camera snapshot service.
- Per-minute polling pipeline: `FanOutPrinterPollsJob` enqueues a
  `PrinterPollJob` per configured printer; `PrinterPoller` writes a new
  `TelemetryReading` and emits a `JobEvent` on every status change. Photos
  are captured asynchronously by `CaptureEventPhotoJob`.
- `HomeAssistantHealthJob` (every 5 minutes) writes Home Assistant
  reachability into the `settings` table for the admin UI.
- Authentication via OmniAuth + Authentik. Three authorization tiers
  enforced consistently in controllers, routes, and views:
  anonymous (read-only status pages), logged-in non-admin (claim/release
  job ownership + "My prints" filter), admin (printer CRUD, app settings,
  Sidekiq UI). `ADMIN_EMAILS` auto-promotes matching users on first login.
- Viewer-aware navbar with a Printers dropdown, Jobs / My prints links,
  admin-only Settings dropdown, and a user menu with sign-in / sign-out.
- Active Storage configured with a persistent disk volume in production
  (`/data/storage`, mounted from `prusa-print-history-storage` in
  `docker-compose.server.yml`).
- Authorization matrix tests for every controller action plus an
  end-to-end integration test that walks all three tiers.
