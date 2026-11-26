---
executor: task-executor
scopes: [docs]
workKinds: [documentation, planning]
blockedBy: [status-finished-contract]
securityReview: required
---

# Staff login: write the API contract and the decision record (CLAUDE.md first)

Planned 2026-11-26. **Editing `CLAUDE.md` needs the owner's explicit approval for this task** (Safety policy). Without it, stop and ask. No other `staff-login-*` card starts before this one is accepted (invariant 3). It runs after `status-finished-contract` and **never at the same time** as another card that edits `CLAUDE.md` (`status-finished-contract`, `qr-static-api-contract`, `order-status-audit-log`).

## Owner request (verbatim, 2026-11-26)

> Create a login screen for restaurant application and store the authorisation with token (the session lives for 16 hours or until the staff log out, add the refresh token feature if needed), from then, there's no need of re-enter the authorisation for mentioned features (except for extract .xlsx file will need to re-enter the password). Let the account be multi-device.

"Mentioned features" = everything staff do with the staff ID and password today: price and sold-out edits, adding a menu item, "Đã nhận chuyển khoản", "Chuyển sang tiền mặt", and (new) status changes through `PATCH /orders/{id}`.

## Owner decisions (2026-11-26, AskUserQuestion in the planning session)

Editing `CLAUDE.md` for this task is **approved by the owner, 2026-11-26, this task only** (it does not carry over). The bullets under "Decisions to record" below are the planner's text; where this table says "owner decided 2026-11-26" the decision is final and the contract was written that way.

| Decision | State |
|---|---|
| SL-a one shared account, many simultaneous sessions, logout ends only that device | **owner decided 2026-11-26** |
| SL-b the token travels in the header `X-Staff-Session` (not `Authorization: Bearer`, not a cookie); stored in `localStorage` key `food_orders_staff_session`. "Never `Authorization`" stays in CLAUDE.md, now with its reason (the Caddy proxy strips it, the demo gate uses it); reasoning: `docs/staff-session-header-decision.md` | **owner decided 2026-11-26** |
| SL-c new direct backend dependency `crypto` (invariant 5) | **approved by the owner 2026-11-26** (recorded in CLAUDE.md "Dependencies"); HMAC-SHA-256 keyed with the staff ID and password; cap 20 live sessions, oldest ends first; "live" = unexpired AND verifiable under the current key, and sessions made under another key are deleted at the next login and at startup (review fix, wording only) |
| SL-d fixed 16 hours, no refresh token | **owner decided 2026-11-26** |
| SL-e the lock counts wrong passwords only. On the five session-accepting routes a present `X-Staff-Session` is judged alone (valid allowed even during a lock; invalid 401, never counted, never refused by the lock; password headers ignored); on `POST /staff/login` and `GET /orders/export` the header gives no exemption (ignored; counted and locked as before); logout is never counted nor refused (review fix, wording only, the decision is unchanged). Closes the open point about failed session tokens that `status-finished-contract` deferred to this card (the 429 bullet is updated) | **owner decided 2026-11-26** |
| SL-f the five staff routes accept the session or the password headers; if `X-Staff-Session` is present it alone is judged; the export needs the password headers for **all three** outputs (CSV and both xlsx), a session alone is 401 | **owner decided 2026-11-26** (yes) |
| SL-g, SL-h, SL-i as written below | planner text, unchanged; SL-i is in CLAUDE.md "Known limitations" and "Weak points" |
| SL-j optional `deviceLabel` (at most 40 UTF-16 units) at login, copied into the audit log | **owner decided 2026-11-26** (yes) |
| SL-k changing the staff ID or password and restarting signs everyone out | **owner decided 2026-11-26** (yes) |
| SL-l no "who am I" route; the app learns from the first 401 | **owner decided 2026-11-26** |
| Audit log `order-status-audit-log` records every status change with the session id and device label | **owner decided 2026-11-26** (yes); CLAUDE.md keeps the pointer text |
| `cancelled` -> `cancelled` on an expiry-cancelled order clears `paymentDueAt` (was "planner's recommendation") | **owner decided 2026-11-26**; the rule is unchanged, only the wording in CLAUDE.md |

Review fixes (2026-11-26, wording only): the session-header lock rule above, `constantTimeEquals` on both login halves, the 20-login eviction trade-off, unverifiable sessions deleted at login and startup, the CDN/`frame-ancestors` localStorage limit, login 400 vs 413, logout 403/401, 429 only for password headers, and "`crypto` is approved only for the token HMAC".

Written into CLAUDE.md (2026-11-26): the Dependencies line, the "Contract ahead of code" note (widened to the staff login routes, `X-Staff-Session` and `staff_sessions`, step 11), the API table (two new rows, the five staff rows and the export row), "Storage" (step 11 bullet and the steps 9 to 12 backup note), "Staff ID and password" (Headers, 401, 429, Weak points, Code, a new "Staff session" sub-section), and "Known limitations". Details beyond this card, flagged for the reviewer: the check order written for `POST /staff/login` (staff routes enabled, lock, body size, JSON and fields, then the ID and password) follows the existing gate order; `X-Staff-Session` is ignored on the export.

## Decisions to record (planner's recommended default for each; the owner confirms or corrects before the contract is written)

The table "Owner decisions (2026-11-26)" above supersedes the planner text below (the owner confirmed or corrected it).

- **SL-a, one shared account, many sessions:** the existing `STAFF_ID` / `STAFF_PASSWORD` stay the only account. "Multi-device" means any number of sessions at once for that account: each login makes its own token; logging out on one device ends only that device's session. No per-person accounts, no "log out everywhere".
- **SL-b, the routes and how the token travels:**
  - `POST /staff/login`: body `{"id": string, "password": string}` (and optionally `"deviceLabel"`, SL-j). 200 `{"token": string, "expiresAt": ISO-8601 UTC string, "lifetimeSeconds": 57600}` with `Cache-Control: no-store`. 400 bad body (not JSON object, missing or non-string fields, unknown fields, body over 4 KB), 401 wrong ID or password (the same fixed text as the other staff routes), 403 staff routes disabled, 429 locked (`Retry-After`).
  - `POST /staff/logout` (header `X-Staff-Session`, no body): ends that session. 204 on success; 401 for an unknown, expired or already ended token; 403 staff routes disabled. The app clears its copy in every case.
  - The token: **at least 32 bytes from a secure random source** (`Random.secure()`), written as base64url (43 characters). Never a function of the password, the clock or an id.
  - **How it is sent: a new header `X-Staff-Session: <token>`**, **not** `Authorization: Bearer`. Reasons found in the repo: (1) `deploy/docker/Caddyfile` runs `header_up -Authorization` on `/api/*` (the demo gate's basic-auth credentials must not reach the backend), so a Bearer token would be **stripped before it arrives**; (2) the same demo gate is `basicauth`, which uses the browser's own `Authorization`, so an app-set `Authorization` would fight it. A custom header passes both proxies unchanged (like `X-Staff-Id`). **Result: the `CLAUDE.md` rule "never `Authorization`" stays as written; this card does not need to change it.** The header value is never put in a URL, a log line, an error text or a body.
  - **Header or cookie? (compared; recommended: header, owner may overrule):**
    - *Header + `localStorage` (recommended):* simple; not sent by the browser on its own, so **no CSRF** by construction; a cross-site page can't use it, and a browser's preflight for a custom header is refused because the backend's default CORS allowed-header list doesn't include `x-staff-session` (to verify by test, not assumed). Weakness: any script injected into the restaurant page could **read** the token. The app is Flutter canvas (no user-supplied HTML), the Docker Caddyfile sends `frame-ancestors 'none'`, there is no content security policy for scripts, and the token is valid at most 16 h and can be ended by logging out.
    - *`HttpOnly` + `Secure` + `SameSite=Strict` cookie set by the backend:* script can't read it. Costs: `Secure` cookies are not stored over the plain-HTTP `http://restaurant.local` of the local setup (so the safe flags don't work locally); cookies are shared across ports on one host (demo/localhost); the browser then attaches the cookie to every request, so **CSRF protection becomes our job** (`SameSite=Strict` plus the cross-site 403 rule, which exists in `deploy/docker/Caddyfile` but **not** in `dev/Caddyfile`, a `dev/**` edit); the app can't see whether it is signed in, so it needs an extra "who am I" route; the cookie path must survive `handle_path /api/*` stripping. More moving parts for a gain only against script injection, which can still **use** the session from inside the page.
    - **Persistence across reloads is required** by the owner: header token in `localStorage` key `food_orders_staff_session` (restaurant origin only; the customer origin is a different `localStorage`).
- **SL-c, server side:** a table `staff_sessions` (schema **step 11**, after status-finished step 9 and qr-static step 10; `order-status-audit-log` takes step 12): `id` (short random public id, for the audit log), `token_hash` (unique), `created_at`, `expires_at`, `device_label` (nullable). Only a **hash** of the token is stored. **Recommended hash: HMAC-SHA-256 with the key `STAFF_ID + newline + STAFF_PASSWORD`**, so (1) a stolen database file doesn't contain usable tokens, and (2) **changing the staff password or ID on a restart ends every session** (their tokens stop matching). Plain SHA-256 would keep old sessions alive after a password change (open: see SL-k). The hash needs `package:crypto`: today it is only an indirect package of the backend; using it directly means adding it to `backend/pubspec.yaml`, which is **a new dependency and needs the owner's approval** (invariant 5). Not approved -> the card stops; hand-written hashing is not an acceptable fallback. Expired rows are removed **on use** (on each login, and when an expired token is presented); an expired row is never accepted whether or not it was removed. **Cap: 20 live sessions; a login at the cap ends the oldest one** (recommended over a 503, so a forgotten tablet can't lock staff out; only someone with the password can create sessions, so a flood needs the password). The server clock is injectable for tests.
- **SL-d, 16 hours, no refresh token (recommended):** a session lasts exactly 16 hours from login (`lifetimeSeconds` 57600), then the next staff action gets 401 and the app shows the login screen. No refresh token because (1) it would be a **second long-lived secret** to store, send and steal, longer-lived than the token it renews; (2) there is one shared account, so signing in again once a day is cheap; (3) fewer routes, tables and states. **Alternative, owner's choice:** a *sliding* expiry (each use pushes the expiry to 16 h after the last use, with a hard cap such as 7 days); friendlier on a busy day, but a tablet left logged in the kitchen would stay valid for the whole cap. Not recommended. An action tapped when the session has just ended is **not** replayed after the new login.
- **SL-e, brute force:** one limiter, the existing one (5 wrong attempts in 60 s, then 60 s of 429, global). **Recommended:** it counts wrong **passwords** (a wrong `POST /staff/login`, wrong password headers on any staff route) and, while locked, refuses `POST /staff/login` and password-header requests with 429 + `Retry-After`. On the five session-accepting routes a present `X-Staff-Session` is judged alone and **never counts** and **is not refused by the lock** (on login and export the header gives no exemption): a 256-bit token can't be guessed, so wrong tokens are not an attack worth counting (counting them would let one stale tablet lock everyone out), and staff already signed in keep working while someone on the wifi hammers the login (this also shrinks the known "anyone can lock staff out" nuisance). The export route needs the password, so it **is** subject to the lock.
- **SL-f, which routes accept the session:** `PATCH /menu/{id}`, `POST /menu`, `POST /orders/{id}/confirm-payment`, `POST /orders/{id}/staff-switch-to-cash`, `PATCH /orders/{id}`. Each accepts **either** a valid `X-Staff-Session` **or** the old `X-Staff-Id` + `X-Staff-Password` pair (recommended: keep the headers for curl and the runbook so nothing breaks). If `X-Staff-Session` is present it alone is judged (invalid -> 401; no fallback to headers). **`GET /orders/export` keeps requiring the password headers; a session alone is 401** (owner exception: the password is re-entered for the export). The export has three outputs (CSV and two xlsx) behind one route; **open: the owner said ".xlsx"; recommended: all three need the password**, because the CSV holds customer names and is the more sensitive file.
- **SL-g, restaurant UI (for the later cards):** a login screen before the orders page when there is no stored session; "Đăng xuất" button in the AppBar; any 401 from a session-using call returns to the login screen (an export 401 means a wrong password and does **not** end the session); no token or password in a log, error, snackbar or `toString`; the export dialog asks for ID and password every time. All new text in all 10 ARBs (vi first; the other 9 machine drafts, unverified).
- **SL-h, security review required** on the backend, client and restaurant cards.
- **SL-i, what stays a known limitation:** one shared login, no per-person accounts; **who changed what is recorded only once `order-status-audit-log` ships** (it records the session, not a person); a stolen token works up to 16 hours unless the staff logs out (or the password is changed, with the HMAC choice); sessions stay valid across a backend restart; the login screen is a convenience gate, **not** a data gate: `GET /orders`, the stream and the customer routes are still open (existing accepted risk); on plain-HTTP wifi the token and the password can be sniffed (use HTTPS when hosted); the lock-out of password logins by anyone on the wifi remains (a nuisance for the login only, not for signed-in staff).
- **SL-j, device label (recommended: optional):** `POST /staff/login` accepts an optional `deviceLabel` (at most 40 UTF-16 units, no control characters, e.g. "Tablet bếp"), stored on the session and copied into the audit log, so the owner can tell devices apart. The login screen has an optional "Tên thiết bị" field. Not a secret, not authentication.
- **SL-k, password change:** with the HMAC key of SL-c, restarting with a new `STAFF_PASSWORD` signs everyone out. Owner confirms that is wanted (recommended: yes).
- **SL-l, no extra "who am I" route (recommended):** the app learns a stored session is dead from the first 401. Alternative: `GET /staff/session` (200 `{"expiresAt"}` / 401) so the right first screen shows after a reload. Recommended: skip it (the orders list is public anyway; one more route, one more test surface).

## Contract changes to write (CLAUDE.md)

1. **API table:** two new rows (`POST /staff/login`, `POST /staff/logout`) with the responses above; the staff rows (`PATCH /menu/{id}`, `POST /menu`, `confirm-payment`, `staff-switch-to-cash`, `PATCH /orders/{id}`) say "staff only: `X-Staff-Session` **or** `X-Staff-Id` + `X-Staff-Password`"; the export row says "password headers only; a session is not enough".
2. **"Staff ID and password" section:** a new sub-list "Staff session" (SL-a to SL-f: lifetime, header, no refresh token, cap of 20, device label, what 401 / 403 / 429 mean for login and for a session); the **Headers** bullet gains `X-Staff-Session` and keeps "never `Authorization`", now with the reason (the proxy strips it and the demo gate uses it); the **429** bullet: the lock counts and refuses passwords only, a session is not counted and not refused; the **Weak points** bullets: add the SL-i items; **Code:** the new files (`backend/lib/staff_sessions.dart`, `backend/lib/staff_api.dart`, names as the backend card creates them).
3. **Storage:** "Step 11 adds the `staff_sessions` table (token hashes only). Nothing else changes; sessions survive a restart; with the HMAC key a changed staff ID or password ends them." The backup advice mentions steps 9 to 12 run together on one first start (step 12 is `order-status-audit-log`).
4. **Known limitations:** replace "One shared staff ID and password ... no per-person staff accounts" with the SL-i text. Keep the sentence about who changed a status as written by `status-finished-contract` (a pointer to `order-status-audit-log`).
5. **Layout / "How the Flutter side consumes it" / Notifications:** only what is true **now**; the new restaurant files are added by `staff-login-docs`.
6. **`.env`-style settings:** none are added. No new environment variable.

Do **not** edit `docs/runbook-local.md`, `docs/deploy.md` or the l10n README: that is `staff-login-docs`. Do **not** edit `dev/Caddyfile` or `deploy/**` (the header option needs no proxy change; if the owner picks the cookie option, that becomes a separate approved `dev/**` task).

## Non-goals

Any code. Per-person accounts, password hashing of the configured password, customer login, refresh tokens (unless the owner overrules SL-d), cookies (unless the owner overrules SL-b), an audit log (`order-status-audit-log`).

## Tests

None (docs). Check every row against `backend/lib/staff_gate.dart`, `orders_api.dart`, `menu_api.dart`.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Table and text match SL-a to SL-l as the owner confirmed them; the `crypto` dependency approval is recorded or the card says "asked, not approved" | owner acceptance; `code-reviewer` (review) |
| No contradiction with the status-finished text (PATCH is staff-only) | `code-reviewer` (review) |
| No other file changed | `git diff --stat` in the review |
| `make check` green | `make check` exit 0 (gate) |
