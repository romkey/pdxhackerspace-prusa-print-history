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
