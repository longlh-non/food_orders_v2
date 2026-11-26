---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: [staff-login-contract, qr-static-backend-schema-and-create]
securityReview: required
---

# Backend: staff login, logout and sessions (schema step 11), accepted by the staff routes

Planned 2026-11-26. Decisions SL-a to SL-l in `staff-login-contract`. It runs **after `qr-static-backend-schema-and-create`** only so the schema step numbers stay 9, 10, 11 (`status-finished-backend` already ran, being a dependency of that card). The card changes the one staff check, so `PATCH /orders/{id}` (from `status-finished-backend`) and the qr-static transition routes get the session without further edits. Security review is required: new auth endpoints, token handling, a schema step. **Needs the owner's approval to add `crypto` as a direct dependency of `backend/pubspec.yaml`** (invariant 5; it is already in `backend/pubspec.lock` as an indirect package). Not approved: stop and ask; do not hand-write a hash.

## Sources

`backend/lib/staff_gate.dart` (`StaffGate`, `check`, the failure list and lock, `constantTimeEquals`), `backend/lib/orders_api.dart` (every `_gate.check(req)`: export, PATCH, staff-switch-to-cash, confirm-payment), `backend/lib/menu_api.dart` (lines ~55 and ~161), `backend/bin/server.dart` (the Cascade, where the gate is built and the startup lines printed), `backend/lib/database.dart` (steps 7 to 10), `backend/lib/no_sniff.dart`, existing tests `staff_gate_test`, `orders_export_api_test`, `menu_*_test`, `orders_payment_*_test`, the proxies `deploy/docker/Caddyfile` and `dev/Caddyfile` (body limit 64 KB; `header_up -Authorization` is why the token is **not** an `Authorization` header).

## Goal

1. **Schema step 11** (never edit shipped steps): `CREATE TABLE staff_sessions (id TEXT PRIMARY KEY, token_hash TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL, expires_at TEXT NOT NULL, device_label TEXT)`. Update the step list comment. No change to other tables.
2. **`StaffSessions`** (new file `backend/lib/staff_sessions.dart`, takes the database, an injectable `now`, the staff ID and password for the HMAC key): `create({label})` -> token (32 bytes from `Random.secure()`, base64url), session id (8 random bytes, hex), `expiresAt = now + 16 h`; stores only `HMAC-SHA256(key = id + '\n' + password, token)` as hex; `validate(token)` -> the live session (id, label) or null, comparing hashes with `constantTimeEquals`, never accepting a row whose `expires_at` is not after `now` and deleting it; `revoke(token)`; purge of expired rows on each `create`; **cap 20 live sessions, creating the 21st ends the oldest**. Unusable configured ID or password (gate disabled) -> no session can be created or validated.
3. **Routes** (new `backend/lib/staff_api.dart`, added to the Cascade in `server.dart`, **before** the orders API; **no CORS middleware** on these two routes):
   - `POST /staff/login`: body `{"id","password"}` plus optional `"deviceLabel"` (<= 40 UTF-16 units, no control characters; SL-j); body read only after the gate says "not disabled and not locked", size cap 4 KB, unknown fields 400. Checks in order: disabled 403, locked 429 (+ `Retry-After`), body 400, wrong pair 401 (counts toward the lock, same counter as `StaffGate`, same fixed text, both halves compared in constant time), then 200 `{"token","expiresAt","lifetimeSeconds":57600}` with `Cache-Control: no-store`. Fixed error bodies; nothing from the request is echoed.
   - `POST /staff/logout`: `X-Staff-Session` required; 204 and the row is deleted; 401 for an unknown, expired or already ended token. Never counts toward the lock.
4. **`StaffGate.check(req)` accepts a session (SL-e, SL-f):** if `X-Staff-Session` is present, it alone is judged: valid -> `null` (go on), otherwise the fixed 401, **not counted and not refused by the lock**. Otherwise the existing password-header check, unchanged (disabled 403, locked 429, wrong 401 counted). Add a second method for the export (e.g. `checkPassword(req)`) that **ignores `X-Staff-Session`** and runs the old check; `GET /orders/export` calls it (a session alone is 401). The validated session id is made available to the handler (a small return value or request context) for `order-status-audit-log` later; no handler uses it yet.
5. **Startup lines** (`server.dart`): `staff login: enabled` / `disabled`; never a value, a count of sessions is fine.
6. **Logs:** the token never appears in a log, error, response body other than the login reply, or exception text. Check `logRequests()` (it logs method, URL and status, not headers) and that no new `print`/`stderr` mentions a header value.
7. Update `pubspec.yaml` / `pubspec.lock` only through `dart pub add crypto` run by the executor after the owner's approval; never hand-edit the lock.

## Non-goals

Flutter code, the audit log (`order-status-audit-log`), refresh tokens, cookies, a "who am I" route, per-person accounts, a "log out everywhere" route, any `dev/**` or `deploy/**` change.

## Tests written with the change

- login: correct pair -> 200 with a 43-character base64url token, `expiresAt` = injected now + 16 h exactly, `lifetimeSeconds` 57600, `Cache-Control: no-store`; wrong ID, wrong password, both wrong -> the same 401 body; routes disabled (no `STAFF_*`) -> 403; bad JSON / missing / non-string / unknown field / over 4 KB -> 400; `deviceLabel` too long or with a control character -> 400.
- lock (SL-e): 5 wrong logins -> 429 with `Retry-After`, a correct login during the lock is 429, after the window it works; a **valid session** still works on a staff route during the lock; wrong **tokens** never count (20 wrong tokens, then a correct login still works); wrong password headers on a staff route still count and lock.
- expiry by the injected clock: a session works at 15 h 59 m and is 401 at 16 h 00 m 00 s and later; the expired row is removed; a request with a session never extends it.
- logout: 204 then the same token is 401 on a staff route; a second logout 401; **other sessions of the same account are unaffected** (multi-session): two logins give two different tokens, both work, ending one leaves the other.
- cap: 21 logins -> the first token is 401, the other 20 work; the table never holds more than 20 live rows.
- restart persistence: write a session to a temp file database, open a new `StaffSessions` / `OrdersApi` on the same file with the same ID and password -> the token still works; with a **different password** -> 401 (HMAC key); with a different ID -> 401.
- hash only: after login, no column of any row contains the token or its base64 / hex form; the stored hash is not the plain SHA-256 of the token (HMAC); two sessions never share a hash.
- the token never appears in: any response body other than login, the `logRequests` output captured in a test, an error response for a bad session, `StaffSessions.toString()`.
- timing: the token and password comparisons go through `constantTimeEquals` (a unit test on a pair with equal length and different last byte, plus a code-review check; timing itself isn't measured).
- routes: each of `PATCH /menu/{id}`, `POST /menu`, `confirm-payment`, `staff-switch-to-cash`, `PATCH /orders/{id}` works with a session and with the password headers and is 401 with neither; a present-but-invalid session is 401 even when valid password headers are also sent (the session alone is judged); `GET /orders/export` (CSV, summary, detail) is **401 with a session only** and 200 with the password headers; the staff gate still answers **before** a body is read.
- a cross-origin preflight (`OPTIONS` with `Origin` and `Access-Control-Request-Headers: x-staff-session`) to a staff route does **not** list `x-staff-session` in `access-control-allow-headers` (documents the CORS claim in SL-b); the two `/staff/*` routes send no `access-control-allow-origin`.
- existing staff-gate, export, menu and payment tests pass unchanged.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make backend-test` (gate) |
| Gates | `make backend-analyze`, `make format-check` exit 0 |
| Only a hash is stored; the token is random >= 32 bytes; no token in logs or errors; comparisons are constant-time | `security-reviewer`, `code-reviewer` (reviews) |
| No staff route got looser except by a valid session; the export still needs the password | `security-reviewer` (review) |
| The `crypto` dependency was approved by the owner and added with `dart pub` | `code-reviewer` (review) |
| Step 11 never edits a shipped step | `code-reviewer` (review) |
| The proxies pass `X-Staff-Session` and don't log it (Caddy default logs don't include headers) | owner acceptance in the real environment, "unverified" until done |
