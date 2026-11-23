# Prusa print history API (v1)

A JSON API for the 3D printer print history app: list printers and prints, claim and clear
prints, report printer problems, and request sign-in links. This document is the complete
reference. It is written to be read by people and by LLM agents; every endpoint follows the
same layout (purpose, request, rules, example, errors).

The app serves this file at `GET /api/v1/docs` (Markdown, no token needed).

## Quick start

```bash
# 1. Create a token: sign in, open your name in the top right → API tokens → New token.
# 2. Call the API with it:
curl -H "Authorization: Bearer pph_YOUR_TOKEN" https://printers.example.org/api/v1/me
```

## Conventions

| Topic | Rule |
| --- | --- |
| Base URL | `https://<your app host>/api/v1` |
| Format | JSON request bodies (`Content-Type: application/json`) and JSON responses |
| Authentication | `Authorization: Bearer <token>` on every request except `GET /api/v1` and `GET /api/v1/docs` |
| Times | ISO 8601 in UTC, for example `2026-11-24T18:30:00Z` |
| IDs | Integers |
| Unknown fields | Ignored in requests. Responses may gain new fields within v1; existing fields are not renamed or removed |
| Rate limit | 120 requests per minute per client address. Over the limit: `429` |

## Tokens

Tokens look like `pph_` followed by 32 letters and digits. The app stores only a hash, so a
token is shown once, when it is created or rotated. Keep it secret: anyone holding it can act
as its owner within its access level.

A token always acts as a user (its owner) and can never do more than that user can do at the
moment of the request. If the owner stops being an admin, their tokens stop having admin
powers immediately.

### Access levels

Each token has one access level. The HTTP method of a request decides which level it needs.

| Access level | Allows methods | Typical use |
| --- | --- | --- |
| `read` | `GET` | Dashboards, status displays |
| `read_write` | `GET`, `POST`, `PUT`, `PATCH` | Claiming, clearing, reporting problems |
| `read_write_delete` | All, including `DELETE` | Releasing claims, undoing clears |

Admins can cap the level for member tokens in Settings; a member token's
`effective_access_level` (see `GET /me`) is the lower of its own level and that cap.

### Token states

A token works only when it is **active**. It stops working when it is **paused** (by its owner
or an admin; can be resumed), **expired** (past `expires_at`; may be renewed for a while,
depending on settings), or **revoked** (permanent). Admins can also make the API stop
accepting tokens from outside the shop network, or limit a token to listed addresses.

All of these refusals return the same `401` response, on purpose: the API does not reveal
whether a token exists or why it was refused. Check the token's page in the web UI to see its
state.

## Errors

Every error uses the same envelope:

```json
{ "error": { "code": "not_found", "message": "Not found." } }
```

`message` is meant for people and may change. Program against `code` and the HTTP status.

| Status | `code` | Meaning | What to do |
| --- | --- | --- | --- |
| 400 | `bad_request` | A required parameter is missing or malformed | Fix the request |
| 401 | `unauthorized` | No token, or the token is unknown, paused, expired, revoked, or not allowed from this address, or the API is turned off | Check the token in the web UI |
| 403 | `insufficient_access_level` | The token's effective access level is too low for this HTTP method | Use a token with a higher level |
| 403 | `forbidden` | The token's owner is not allowed to do this | Do not retry |
| 404 | `not_found` | No such record, or it is not visible to this token | Check the ID |
| 409 | `conflict` | The request conflicts with the record's current state (see each endpoint) | Re-read the record, then decide |
| 422 | `unprocessable` | The request was understood but is invalid (see `message`) | Fix the request |
| 429 | `rate_limited` | Too many requests | Wait a minute |

## Endpoints

### `GET /api/v1`

**Purpose:** Discovery. Returns the API name, version, and the URL of this document.
**Token:** Not required.

```json
{
  "name": "Prusa print history API",
  "version": "v1",
  "docs_url": "https://printers.example.org/api/v1/docs",
  "authentication": "Send an API token as \"Authorization: Bearer <token>\". ..."
}
```

### `GET /api/v1/docs`

**Purpose:** This document, as `text/markdown`.
**Token:** Not required.

### `GET /api/v1/me`

**Purpose:** Show who the token acts as and what it may do. Use it to check a token works.
**Access level:** `read`

**Example**

```bash
curl -H "Authorization: Bearer pph_..." https://printers.example.org/api/v1/me
```

```json
{
  "user": { "id": 7, "display_name": "Ada Lovelace", "username": "ada", "admin": false },
  "token": {
    "id": 3,
    "name": "My print script",
    "prefix": "pph_4kT9xQ2m",
    "kind": "personal",
    "access_level": "read_write_delete",
    "effective_access_level": "read_write",
    "expires_at": "2027-11-24T18:30:00Z"
  }
}
```

`effective_access_level` is what the token can do right now. It is lower than
`access_level` when an admin has capped member tokens.

**Errors:** `401`.

## Printers and prints

### The job object

Endpoints below return prints ("jobs") in this shape:

```json
{
  "id": 412,
  "status": "finished",
  "filename": "vase.gcode",
  "private": false,
  "progress_percent": 100.0,
  "started_at": "2026-11-24T15:00:00Z",
  "ended_at": "2026-11-24T17:00:00Z",
  "estimated_finish_at": null,
  "claimed": true,
  "owner": { "id": 7, "display_name": "Ada Lovelace", "username": "ada" },
  "clearance": null,
  "actions": {
    "can_claim": false,
    "can_release_claim": true,
    "can_clear": true,
    "can_undo_clear": false
  },
  "printer": { "id": 1, "name": "Prusa XL" }
}
```

| Field | Notes |
| --- | --- |
| `status` | One of `pending`, `printing`, `paused`, `attention`, `error`, `finished`, `cancelled` |
| `filename`, `progress_percent`, `owner` | `null` when the print is private and the token's owner is neither its owner nor an admin |
| `claimed` | Whether anyone has claimed the print (true even when `owner` is hidden) |
| `clearance` | `null` until the print is cleared, then `{ cleared_at, outcome, failure_reason, failure_detail, cleared_by }` |
| `actions` | What the token's owner may do to this print right now. Show only the buttons whose flag is `true`. The token's access level still applies on top (for example `can_release_claim` needs a `read_write_delete` token) |
| `printer` | Present in job lists and `GET /jobs/:id`; left out inside a printer object |

### `GET /api/v1/printers`

**Purpose:** List printers, each with the print someone standing at it would act on: the print
in progress, or else the most recent print if it is still waiting to be cleared.
**Access level:** `read`

| Query parameter | Type | Notes |
| --- | --- | --- |
| `active` | boolean | `true` returns only printers that have such a print. Use it for a kiosk's printer list |

```json
{
  "printers": [
    {
      "id": 1,
      "name": "Prusa XL",
      "model": "XL 5-tool",
      "location": "Shop",
      "status": "printing",
      "out_of_service": false,
      "job": { "id": 415, "status": "printing", "...": "see the job object" }
    }
  ]
}
```

`job` is `null` for an idle printer with nothing waiting on its bed.

### `GET /api/v1/printers/:id`

**Purpose:** One printer, same shape, wrapped as `{ "printer": { ... } }`.
**Access level:** `read`
**Errors:** `404` for an unknown printer.

### `GET /api/v1/jobs`

**Purpose:** Recent prints, newest first.
**Access level:** `read`

| Query parameter | Type | Notes |
| --- | --- | --- |
| `state` | string | `all` (default), `active` (printing, paused, attention or error), or `uncleared` (active or finished, not yet cleared) |
| `printer_id` | integer | Only this printer's prints |
| `mine` | boolean | Only prints claimed by the token's owner |
| `limit` | integer | Default 50, at most 200 |

Response: `{ "jobs": [ <job>, ... ] }`.

### `GET /api/v1/jobs/:id`

**Purpose:** One print, as `{ "job": <job> }`.
**Access level:** `read`
**Errors:** `404`.

## Claiming

### `PUT /api/v1/jobs/:id/claim`

**Purpose:** Claim a print for the token's owner. Claiming a print you already own changes
whether it is private.
**Access level:** `read_write`
**Who:** Any member, for an unclaimed print or one they own. Only admins can take over a print
someone else has claimed.

| Body field | Type | Notes |
| --- | --- | --- |
| `private` | boolean | Default `false`. A private print's filename, owner, progress and photos are shown only to its owner and admins |

```bash
curl -X PUT -H "Authorization: Bearer pph_..." -H "Content-Type: application/json" \
  -d '{"private": false}' https://printers.example.org/api/v1/jobs/415/claim
```

Response: `{ "job": <job> }`.
**Errors:** `404`; `409 conflict` when someone else has claimed it (re-read the job: its
`actions.can_claim` is `false`).

### `DELETE /api/v1/jobs/:id/claim`

**Purpose:** Release a claim. The print also becomes public again.
**Access level:** `read_write_delete`
**Who:** The print's owner, or an admin.
Response: `{ "job": <job> }`.
**Errors:** `403 forbidden` (not yours), `404`, `409 conflict` (not claimed).

## Clearing

Clearing records that a print has been taken off the printer, and whether it worked.

### `GET /api/v1/clear_options`

**Purpose:** The choices a clearing form needs. Use these instead of hardcoding them.
**Access level:** `read`

```json
{
  "outcomes": ["success", "failed"],
  "failure_reasons": [
    { "value": "spaghetti", "label": "Spaghetti" },
    { "value": "printer_jammed", "label": "Printer jammed" },
    { "value": "filament_issue", "label": "Filament issue" },
    { "value": "blobbed", "label": "Blobbed" },
    { "value": "other", "label": "Other" }
  ],
  "detail_required_for": ["other"],
  "label_printers": [{ "id": 1, "name": "Front desk", "default": true }]
}
```

### `POST /api/v1/jobs/:id/clearance`

**Purpose:** Clear a print. The owner is notified by email or Slack according to their
preferences, as when clearing on the web.
**Access level:** `read_write`
**Who:** Any member.

| Body field | Type | Notes |
| --- | --- | --- |
| `outcome` | string, required | `success` or `failed` |
| `failure_reason` | string | Required when `outcome` is `failed`. A `value` from `clear_options.failure_reasons` |
| `failure_detail` | string | Required when `failure_reason` is `other` |
| `print_label` | boolean | Successful prints get a pickup label by default when a label printer is set up. `false` skips it. `true` when no label printer is set up is an error |
| `label_printer_id` | integer | Defaults to the default label printer |

```bash
curl -X POST -H "Authorization: Bearer pph_..." -H "Content-Type: application/json" \
  -d '{"outcome": "failed", "failure_reason": "spaghetti"}' \
  https://printers.example.org/api/v1/jobs/415/clearance
```

```json
{
  "job": { "id": 415, "clearance": { "outcome": "failed", "failure_reason": "spaghetti", "...": "..." } },
  "label": { "printed": false, "cups_job_id": null },
  "notification": { "email_sent": false, "slack_sent": true }
}
```

**Errors:** `404`; `409 conflict` (already cleared, or still pending); `422 unprocessable`
(bad outcome, missing reason or detail, or the label could not be printed; nothing was
cleared).

### `DELETE /api/v1/jobs/:id/clearance`

**Purpose:** Undo a clear, so the print can be cleared again.
**Access level:** `read_write_delete`
**Who:** Admins. Members too, if an admin has allowed it in Settings.
Response: `{ "job": <job> }`.
**Errors:** `403 forbidden`, `404`, `409 conflict` (not cleared).

## Problem reports

### `POST /api/v1/printers/:id/problems`

**Purpose:** Report a problem with a printer. It appears in the printer's service log under
the token owner's name.
**Access level:** `read_write`
**Who:** Any member.

| Body field | Type | Notes |
| --- | --- | --- |
| `summary` | string, required | Up to 200 characters |
| `details` | string | Optional longer description |
| `take_out_of_service` | boolean | Also mark the printer out of service. Ignored if it already is |

```json
{
  "problem": {
    "id": 88,
    "printer_id": 2,
    "kind": "problem",
    "summary": "Nozzle clogged",
    "details": "Under-extruding on the first layer",
    "occurred_at": "2026-11-24T18:40:00Z",
    "reported_by": { "id": 7, "display_name": "Ada Lovelace", "username": "ada" }
  },
  "printer_out_of_service": false
}
```

Status `201`. **Errors:** `404`; `422 unprocessable` (missing summary).

## Recipe: a claim-and-clear client

1. `GET /api/v1/printers?active=true` and show each printer with its `job`.
2. For the chosen job, offer **Claim** if `actions.can_claim` and **Clear** if
   `actions.can_clear`.
3. To clear: `GET /api/v1/clear_options` once, ask Success or Failed, and for Failed ask for a
   reason (and detail for `other`), then `POST /api/v1/jobs/:id/clearance`.
4. On `409`, re-read the printer list: someone else got there first.
