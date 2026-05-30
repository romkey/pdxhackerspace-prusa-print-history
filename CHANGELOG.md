# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.4.10] - 2026-05-30

### Changed
- Authentik sign-in syncs admin status only from the `is_admin` claim. Users without it are demoted on login, even if they were admin before. `ADMIN_EMAILS` no longer grants admin on Authentik login.

## [0.4.9] - 2026-05-30

### Changed
- Dashboard shows **PDX Hackerspace** above a smaller live clock (still overridable via app settings).
- Sign-in page puts highlighted Authentik first; email/password login is labeled **Local accounts**.
- Email and Slack notification preferences both default to on for new users.

## [0.4.8] - 2026-05-30

### Fixed
- Docker production image build: load `AppTlsConfig` before `production.rb` runs so `assets:precompile` succeeds.

## [0.4.7] - 2026-05-30

### Fixed
- Authentik sign-in no longer shows a stale "session expired / Invalid state" warning after a successful login.
- OAuth state is less likely to be lost behind HTTPS reverse proxies: when `APP_PROTOCOL=https`, session cookies default to Secure and `RAILS_ASSUME_SSL` defaults to on.

## [0.4.6] - 2026-05-30

### Changed
- Rebrand the UI to **3D Printer History**; the public dashboard shows a larger live clock instead of a page title.
- Footer always links to PDX Hackerspace and GitHub, in addition to any configured footer text/link.
- Remote anonymous visitors see Sign in aligned to the right when Jobs/Printers nav is hidden.
- Idle printer status dots are green when PrusaLink is reachable and red when it is not.

## [0.4.5] - 2026-05-30

### Fixed
- Slack file upload requests use form encoding for `files.getUploadURLExternal` and multipart upload to the presigned URL (fixes `invalid_arguments` after v2 migration).
- The printer dashboard at `/` is public again; sign-in is only required for jobs, printers, and other pages when visiting from outside `INTERNAL_NETWORKS`.

## [0.4.2] - 2026-05-30

### Fixed
- Slack file DMs resolve the bot–user IM channel via `conversations.open` before upload (`channel_id` must be `D…`, not `U…`).

### Changed
- Slack bot token docs now list `im:write` alongside `chat:write` and `files:write`.

## [0.4.1] - 2026-05-30

### Fixed
- Slack print notifications with photos failed with `method_deprecated` after Slack retired `files.upload`; uploads now use Slack's v2 file API.

## [0.4.0] - 2026-05-29

### Added
- `INTERNAL_NETWORKS` env var: comma-separated IPv4 CIDR blocks (e.g. `192.168.0.0/24`) for a relaxed LAN posture. Visitors from those networks can view the dashboard, jobs, and printers, and clear or unclear prints without signing in. Client IP is taken from `X-Forwarded-For` through trusted reverse proxies.

### Changed
- Anonymous access from the public internet now requires sign-in for status pages. Claiming prints and all settings remain login- or admin-gated everywhere.

## [0.3.20] - 2026-05-29

### Added
- Usernames synced from Authentik `nickname` on sign-in; shown in the UI instead of full names.

### Changed
- Print job owner section shows username only — Slack details remain on your profile page.

## [0.3.19] - 2026-05-29

### Fixed
- Rails 8.1 deprecation warning for `ActiveSupport::Configurable` from OmniAuth CSRF protection (upgraded `omniauth-rails_csrf_protection` to 2.x).

## [0.3.18] - 2026-05-29

### Fixed
- Cleared-print thermal labels print landscape with full filename and compact start/finish line.

## [0.3.17] - 2026-05-29

### Added
- Admin **Unclear print** action to reset a cleared print so it can be cleared again.

## [0.3.16] - 2026-05-29

### Changed
- Authentik OIDC requests the `slack` scope and syncs Slack linkage only from the `slack` claim.

## [0.3.15] - 2026-05-29

### Added
- `SMTP_SSL=false` for plain-text SMTP to local mail servers without TLS/SSL.

## [0.3.14] - 2026-05-29

### Changed
- Authentik OIDC requests `has_slack` as a scope; only `is_admin` is requested as a claim.

## [0.3.13] - 2026-05-29

### Fixed
- Authentik OmniAuth strategy no longer conflicts with Zeitwerk autoloading in CI.

## [0.3.12] - 2026-05-29

### Added
- Dashboard printer images use green, blue, or red outlines for idle/available, printing, and attention states.
- Authentik OIDC sign-in syncs `is_admin`, `has_slack`, and `slack` claims on every login.
- Optional `AUTHENTIK_DEBUG` logging for Authentik OIDC authorize params and HTTP JSON bodies.

### Changed
- SMTP host configuration env var renamed from `SMTP_ADDRESS` to `SMTP_SERVER`.

## [0.2.1] - 2026-05-28

### Added
- Idle dashboard cards show the last job preview, filename, completion time, and status.

### Changed
- Anonymous visitors see only the printer dashboard and sign-in link in the navbar.
- Printer detail integrations section is visible to admins only.

## [0.2.0] - 2026-05-28

### Added
- Configurable dashboard heading, footer text, and footer link in Settings.
- Expanded kiosk-style dashboard with four printers across, live clock, photo and preview images, availability, temperature table, and material/nozzle summary.

### Changed
- Home page dashboard layout redesigned to match the shop display: centered heading, printer cards with camera/preview placeholders, and simplified footer.

## [0.1.22] - 2026-05-28

### Added
- Job progress bar and estimated finish time synced from PrusaLink status/job telemetry.
- Dashboard printer cards with status, progress, filament/nozzle, and small preview/camera thumbnails.
- Footer version always reads from the embedded `VERSION` file.

## [0.1.19] - 2026-05-27

### Fixed
- Treat `/api/printer` `telemetry.material` as the loaded filament source of truth, always applied to T0 ahead of gcode file metadata.

## [0.1.18] - 2026-05-27

### Fixed
- Active Storage images (print preview, camera photos, progress photos) no longer break after live Turbo updates rewrote URLs to `example.com`.
- Production default `APP_HOST` fallback is now `localhost` instead of `example.com`.

### Added
- Pretty-printed PrusaLink JSON logged on every API fetch (`[PrusaLink JSON]` in logs).
- Parsed print head summary logged after each poll (`[PrinterHeadSync]`).
- Additional filament metadata key formats: bracket suffixes, `printing_filament_types`, and per-tool `info.tools` hash.

## [0.1.17] - 2026-05-27

### Fixed
- Parse PrusaLink gcode metadata using snake_case keys and per-tool arrays (`filament_type`, `nozzle_diameter per tool`).
- Fetch file metadata from PrusaLink when the job endpoint omits the meta block.
- Read idle nozzle size from `/api/v1/info` and loaded material from the legacy `/api/printer` endpoint.
- Persist printer-level print head state on every poll so nozzle and material stay visible when idle.

### Added
- Print head summary in the printer page header.
- Loaded print heads shown on the idle printer status card.

## [0.1.16] - 2026-05-26

### Added
- Site footer with app version and GitHub repository link.

### Fixed
- Hide the printer page camera section when no camera URL is configured.

## [0.1.15] - 2026-05-26

### Added
- Minute-by-minute camera captures stored as `PhotoCapture` records.
- Job photo gallery with start/finish defaults and browsable progress photos.
- Always-visible print head and material info on the printer page sidebar.
- Idle printers keep only their latest camera photo; active jobs retain all progress photos.

## [0.1.14] - 2026-05-26

### Added
- Live camera on the printer page, fetched from the configured camera URL via a server-side proxy.
- PrusaLink camera snap as a fallback when no camera URL is configured.

### Fixed
- Live PrusaLink telemetry when the job endpoint is empty but status includes job data.
- Active job detection for `BUSY` printer state and status-only job payloads.
- Camera URLs with HTTP basic auth.

## [0.1.13] - 2026-05-26

### Added
- Print head and material details on printer and job pages, tied to the job being shown.

## [0.1.12] - 2026-05-26

### Added
- Print preview image from PrusaLink G-code thumbnail, captured once at job start.
- Rolling camera snapshot on active jobs (updated each poll while printing).
- Preview and camera images on the printer page (while printing) and job page.
- PrusaLink connectivity dot on the dashboard printer list.

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
