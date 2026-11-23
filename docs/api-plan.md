# API and token management plan

Status: being built. `docs/api.md` is the reference for what has shipped.

## Goals

- A versioned JSON API (`/api/v1`) authenticated by bearer tokens.
- Token management flexible enough for a low-friction hackerspace and for a locked-down site,
  controlled by system settings rather than code changes.
- First consumers: a keyfob kiosk (list printers, claim, clear with outcome), emailed login
  links, and "report a problem" links.

## How this fits what exists today

| Area | Today | Consequence for the API |
| --- | --- | --- |
| Authorization | Four tiers in `ApplicationController` (`admin?`, `logged_in?`, `internal_network?`), no policy layer | Extract the rules into one policy object used by both web and API, so they cannot drift |
| Claim | `jobs#claim`: any signed-in user; overwrites an existing owner | Fixed in this work, web and API: only an unowned print can be claimed; admins may reassign |
| Clear | `jobs#clear_print`: admin, or anyone (even anonymous) on an internal network. A signed-in member **outside** the shop network cannot clear; `JobClearPrintService` already takes outcome, failure reason, detail, label options | Fixed in this work, web and API: any signed-in member may clear. Reuse the service unchanged |
| Problem reports | `PrinterServiceLog.report_problem!`; allowed for signed-in or internal | Reusable as is |
| Login | Authentik OIDC, plus optional local admin password. No emailed links | Login links are a new sign-in path and need their own model |
| Member identity | Users are matched on `provider` + `uid` (the OIDC `sub`). The app receives no stable Authentik ID that the kiosk also knows | New `member_id` Authentik claim, synced to `users.member_id` at sign-in. Keyfobs stay entirely outside this app |
| Settings | `Setting::KEYS` whitelist with paired accessors | Token policy lives here |
| Rate limiting | `LocalLoginRateLimiter` (cache-backed) | Use Rails 8 `rate_limit` in API controllers; same cache store |

## Token model

New table `api_tokens`:

| Column | Notes |
| --- | --- |
| `user_id` (NOT NULL) | Owner. The token can never do more than this user can do *right now* |
| `created_by_id` | Differs from owner when an admin creates a token for someone |
| `name` | Human label ("Kiosk by the door", "My script") |
| `kind` | `personal` or `device` (see Kiosk below) |
| `token_digest` (unique index) | SHA-256 of the secret. The secret is shown once at creation and never stored |
| `token_prefix` | First characters (`pph_ab12…`) so a token can be recognized in lists and logs |
| `access_level` | `read`, `read_write`, `read_write_delete` |
| `expires_at` | NULL means no expiry |
| `paused_at` | Reversible suspension |
| `revoked_at` | Permanent |
| `allowed_cidrs` | Optional. Empty means any address |
| `can_display_login_links` | Device tokens only, default off. Lets the kiosk receive a sign-in link to show as a QR code |
| `last_used_at`, `last_used_ip` | Updated at most once a minute |

Rules:

- **Effective permission = owner's current role ∩ token access level ∩ request network tier.**
  Role is read at request time, so a demoted admin's tokens demote with them.
- Access level maps to HTTP verb: `GET` needs read; `POST`/`PUT`/`PATCH` need write; `DELETE`
  needs delete. Each endpoint then applies the same role rule as its web counterpart.
- States: active, paused, expired, revoked. Only active tokens authenticate. All failures return
  the same `401` body so a caller cannot tell why.
- **Pause / resume**: owner or admin.
- **Renew**: extends `expires_at` from now by the role's default duration, capped by the role's
  maximum. Secret unchanged. Allowed on expired tokens within a grace window (setting).
- **Rotate**: new secret, same row and settings. Separate from renew.
- **Revoke**: permanent; row kept for audit.
- Admins see and manage every token. Members see and manage only their own.
- Tokens are sent only in `Authorization: Bearer`. Never in a query string.
- Tokens cannot create or manage tokens in v1. Token management stays in the web UI behind a
  real sign-in.

### System settings (new `Setting::KEYS`)

| Key | Low-friction example | Higher-security example |
| --- | --- | --- |
| `api_enabled` | on | on |
| `api_members_can_create_tokens` | on | off (admins issue tokens) |
| `api_member_max_access_level` | `read_write_delete` | `read` |
| `api_member_token_default_days` | blank (no expiry) | 30 |
| `api_member_token_max_days` | blank (no limit) | 90 |
| `api_admin_token_default_days` | 365 | 7 |
| `api_admin_token_max_days` | blank | 30 |
| `api_token_renew_grace_days` | 30 | 0 |
| `api_token_max_login_age_days` | blank | 30 |
| `api_require_internal_network` | off | on |
| `login_links_enabled` | on | off |
| `login_links_allow_admins` | off | off |
| `login_link_qr_ttl_minutes` | 5 (the default) | 2 |
| `login_link_ttl_minutes` | 60 (the default) | 5 |
| `members_can_undo_clear` | on (the default) | off (admins only) |

`api_token_max_login_age_days` addresses a real gap: admin status and membership are only
refreshed from Authentik at sign-in, so someone removed from Authentik would otherwise keep
working tokens indefinitely. With it set, a token stops working when its owner has not signed in
through Authentik within that many days (`users.last_login_at` already exists).

### Audit

New table `api_token_events`: token, acting user, on-behalf-of user, action, target, IP, time.
Written for token lifecycle changes and for every non-GET API call. Shown on the admin token
page. Pruned by `DataRetentionCleaner`.

### Web UI

- **Profile → API tokens**: list, create (secret shown once with a copy button), pause/resume,
  renew, rotate, revoke. Hidden when member tokens are disabled.
- **Settings → API tokens** (admin): all tokens, filter by user/kind/state, same actions, create
  device tokens, last-used and recent events.
- **Settings → API** (admin): the policy keys above.

## API surface (v1)

`Api::V1::BaseController < ActionController::API`: bearer authentication, JSON error envelope
(`{ "error": { "code", "message" } }`), per-token and per-IP `rate_limit`, no session or CSRF.

| Method and path | Level | Role rule | Notes |
| --- | --- | --- | --- |
| `GET /api/v1/me` | read | any | Token introspection: owner, level, expiry, acting user |
| `GET /api/v1/printers` | read | any | `?active=true` for printers with an active or uncleared job. Each includes current job summary plus `can_claim` / `can_clear` |
| `GET /api/v1/jobs` | read | any | `?state=active\|uncleared`, `?mine=true`, `?printer_id=` |
| `GET /api/v1/jobs/:id` | read | any | Honors `Job#details_visible_to?` for private prints |
| `PUT /api/v1/jobs/:id/claim` | write | member | `{ private }`. `409` if owned by someone else; admins may reassign |
| `DELETE /api/v1/jobs/:id/claim` | delete | owner or admin | Mirrors `jobs#unclaim` |
| `POST /api/v1/jobs/:id/clearance` | write | member, or internal | `{ outcome, failure_reason, failure_detail, print_label, label_printer_id }` → `JobClearPrintService`. Returns label and notification results |
| `DELETE /api/v1/jobs/:id/clearance` | delete | member if `members_can_undo_clear`, else admin | Same rule on the web |
| `GET /api/v1/clear_options` | read | any | Outcomes and failure reasons, so clients do not hardcode them |
| `POST /api/v1/login_links` | write | see below | `{ return_to, delivery }`. Emails a link to the acting user, or returns it for QR display. `202`; `403` for admins unless `login_links_allow_admins` |
| `POST /api/v1/problem_report_links` | write | see below | `{ printer_id, delivery }`. A login link that lands on the problem form with the printer preselected |
| `POST /api/v1/printers/:id/problems` | write | member | `{ summary, details, take_out_of_service }` → `PrinterServiceLog.report_problem!`, same as the web form. Returns the new entry and whether the printer is now out of service. Allowed in kiosk sessions |
| `POST /api/v1/kiosk/sessions` | write | device token | `{ member_id }` → short-lived delegated token for that member |

The existing `printers.json` / `jobs.json` / `events.json` stay as they are; they could accept
bearer tokens later.

## Login links

New table `login_links`: `user_id`, `token_digest`, `return_to` (validated local path),
`expires_at`, `used_at`, `requested_by_token_id`.

- Single use, digest stored. Expires after `login_link_ttl_minutes`, an admin setting on the
  Settings page that defaults to 60.
- `GET /login/link/:token` shows a "Sign in as …" confirmation; the button `POST`s. Mail
  scanners that prefetch links would otherwise burn the link.
- Signs in through the existing `establish_session`. It does not refresh Authentik claims, which
  is why admins are excluded by default.
- Rate limited per target user (for example 3 per 15 minutes) and per token.
- An emailed link only ever goes to the acting user. It takes no email address parameter, so it cannot
  be used to probe for accounts or mail strangers.
- **Delivery** is `email` (the default) or `display`. With `display` the response contains the
  link URL so the kiosk can render it as a QR code for the member to scan with their phone. It is
  allowed only in a kiosk's delegated session, and only when an admin has switched on
  `can_display_login_links` for that device token; anything else gets `403`. Displayed links use
  the shorter `login_link_qr_ttl_minutes` (default 5), since they sit on a screen others can see.
  They are still single use and still go through the confirmation page, which names the member,
  and the admin rule applies the same way. The audit row records the delivery method.
- A problem-report link is the same thing with `return_to` set to
  `/service/problems/new?printer_id=…`.

## Kiosk and keyfobs

A kiosk is neither a member token nor an admin token. It is a shared device that acts for
whichever member just scanned. The plan models that explicitly:

- **Device token** (`kind: device`), created only by admins, normally with `allowed_cidrs` set to
  the shop network. On its own it can read printers and jobs.
- **Member identity**: a new Authentik claim, **`member_id`**, carrying the Authentik ID that
  never changes, whatever happens to the member's email, username or fob.
  `User.apply_member_id_from_auth` copies it to a new `users.member_id` column at every sign-in,
  alongside the existing `is_admin`, `trained_on` and `slack` claims. Deterministically encrypted
  (it is looked up) with a unique index; add it to `encrypt_sensitive_fixtures!`. Shown read-only
  on the admin user list to help with kiosk troubleshooting.
- **This app knows nothing about keyfobs.** The kiosk reads the fob, resolves it to the member's
  Authentik ID by its own means, and sends only that ID here. Fob enrollment, replacement and
  revocation never touch this app.
- Because the claim is only read at sign-in, a member must have signed in to this app once before
  the kiosk can act for them. Existing users get their `member_id` at their next sign-in. The
  kiosk's "member not found" screen says so.
- **Delegated session**: the kiosk posts the member's ID to `/kiosk/sessions` and receives a
  token valid for a couple of minutes, bound to that kiosk and that member. Requests made with it
  run as the member, limited to a fixed allowlist: list printers and jobs, claim, release own
  claim, clear, report a problem, request login link, request problem-report link. Never admin powers, even when
  an admin scans.
- Unknown `member_id`: `404` with a generic message; heavily rate limited per kiosk.
- Audit rows record "member X via kiosk Y".

Kiosk flow: scan → kiosk maps fob to `member_id` → `kiosk/sessions` → `GET printers?active=true` → tap a printer → **Claim**, or
**Clear** → Success / Failed → reason (from `clear_options`) → optional detail → done.

A device token can act for any member just by naming their ID, so it is the most sensitive
credential in the system. The design compensates with the action allowlist, the network
restriction, short delegated sessions, and the audit trail.

## Phasing

1. **Foundation**: policy object extracted from `ApplicationController`, including the two web
   behavior fixes (members may clear from anywhere; a claimed print cannot be taken over except
   by an admin, and the Claim button is hidden on prints owned by someone else; undoing a clear
   follows `members_can_undo_clear`); `api_tokens`,
   `api_token_events`; settings; profile and admin UI; `Api::V1::BaseController`; `GET /me`.
2. **Jobs**: printers and jobs reads, claim, clearance, clear options, direct problem reports.
3. **Login links**: model, mailer, confirmation page, both link endpoints.
4. **Kiosk**: `member_id` claim sync and column, device tokens, delegated sessions. Document the
   claim in the README's Authentik section.
5. **Polish**: `docs/api.md` reference with curl examples, README and CHANGELOG, Prometheus
   counters for API requests and auth failures, expiry-warning emails, cleanup of expired tokens
   and links.

Each phase ships on its own. Phases 3 and 4 are independent of each other.

## Testing

- Model tests for every token state and for renew/rotate bounds under different settings.
- Integration tests per endpoint × role × access level × network tier (`external_request_headers`
  for the outside tier).
- Policy object tests shared by web and API paths.
- Login link: single use, expiry, prefetch safety, admin exclusion, rate limit, and `display`
  delivery refused without the device-token flag.
- Kiosk: allowlist enforcement, an admin's `member_id` gets member powers only, unknown ID.

## Decided

- Login links expire after an admin-set period, default one hour.
- Members may clear prints from anywhere, on the web and through the API.
- A print that is already claimed cannot be claimed by another member; admins may reassign.
- The kiosk identifies members by a stable Authentik ID delivered in a new `member_id` claim.
  Keyfobs are the kiosk's business only.
- `members_can_undo_clear` decides whether any signed-in member or only admins can undo a clear.
  It defaults to on. Either way, anonymous visitors on the shop network can no longer undo a
  clear (they can today); they can still clear.
- `login_links_allow_admins` decides whether admins can sign in with an emailed link. It defaults
  to off, because the link bypasses Authentik and does not refresh the admin claim. When off, a
  request on behalf of an admin gets a `403` with a clear message, so a kiosk can tell them to
  sign in normally instead of leaving them waiting for an email.
- A kiosk may show a sign-in link as a QR code, when an admin enables it for that kiosk's token.
  QR links have their own, shorter expiry.
- Problems can be filed directly through the API as well as through an emailed or displayed link.
  The API always records the reporting member; there is no anonymous problem report through the
  API.
