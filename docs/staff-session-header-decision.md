# Decision report: how the staff login token travels (`X-Staff-Session`)

Date: 2026-11-26. Status: **decided by the owner** (header `X-Staff-Session`), to be written into the contract by the task `staff-login-contract`. Nothing in this report has been implemented or run yet.

This report explains why the staff login (a login screen in the restaurant app, a session token that lasts 16 hours) sends its token in a **custom request header, `X-Staff-Session`**, and not in the more common `Authorization: Bearer <token>` header or in a cookie. It also lists what is verified from the repository, what is only an expectation, and what could make us change the decision.

## 1. What problem is being solved

Today staff routes (menu edit, confirm payment, switch to cash, export) need the shared staff ID and password in two headers on every request, and the restaurant app asks for them again whenever the page is reloaded. The owner asked for:

- a login screen in the restaurant app;
- a session token, valid for 16 hours or until the staff member logs out;
- one shared account usable on several devices at once;
- no need to type the credentials again for the staff features, **except** the month export (`.xlsx`, and by our recommendation the CSV too), which keeps asking for the password.

The open design question was the transport: **where does the token go on each request?**

## 2. Constraints found in the repository

These facts decide the question. Each one was checked in the files named.

1. **The demo deployment has a gate in front of everything.** `deploy/Caddyfile` and `deploy/docker/Caddyfile` protect the whole site, including `/api/*` and the live order stream, with Caddy `basicauth`. That gate works by the browser sending `Authorization: Basic ...`. The comment in `deploy/Caddyfile` (lines 44-58) states the design: the gate is "separate from the staff login: the backend never reads `Authorization`. Staff routes use X-Staff-Id / X-Staff-Password, so one request can carry both."
2. **Caddy deletes `Authorization` before the backend.** In both Caddyfiles, inside the `/api/*` proxy block: `header_up -Authorization` (for example `deploy/Caddyfile` lines 104-105 and 156, `deploy/docker/Caddyfile` lines 62 and 102). The comment says "The backend never needs the gate credentials; X-Staff-* pass." This was added deliberately so the gate password never reaches the backend. The side effect: **any value the app puts in `Authorization` would be removed before the backend sees it.**
3. **A request has only one `Authorization` header.** With the gate on, the browser already uses that header for the gate credentials (Basic). A bearer token cannot share it. The two meanings collide.
4. **`X-Staff-*` headers already pass through.** The staff routes use `x-staff-id` and `x-staff-password` (`backend/lib/staff_gate.dart` lines 6-7), and the proxy does not touch them. A new `X-Staff-*` header follows the same path with no proxy change. (That the systemd `deploy/Caddyfile` passes an unknown custom header unchanged is expected from the config, but **not yet tested** on a real server.)
5. **The apps call the API same-origin.** Caddy routes `/api/*` on each hostname to the backend (stripping `/api`), so browsers do not make cross-origin requests and no CORS preflight happens. The backend does add `corsHeaders()` (`backend/lib/orders_api.dart` line 661, `menu_api.dart` line 219) and the hand-written stream response sets `Access-Control-Allow-Origin: *` (line 632).
6. **A cross-site guard exists in the deployed proxy, but not in dev.** The deployed Caddyfiles return 403 for `/api/*` requests with `Sec-Fetch-Site: cross-site` (added after a security review, see the CROSS-SITE note in `deploy/Caddyfile`). `dev/Caddyfile` has no such guard.
7. **The project's own rule says "never `Authorization`"** for staff credentials (`CLAUDE.md`, "Staff ID and password"). Choosing Bearer would mean rewriting that rule and the proxy config.

## 3. Options considered

### Option A: `Authorization: Bearer <token>` (the common standard)

- For: well known; libraries and tools understand it.
- Against, from the constraints above:
  - **With the demo gate on, it does not work.** The gate already owns `Authorization`. The browser would send either the gate's Basic credentials or the app's header, not both, and the proxy strips `Authorization` anyway (constraint 2). Login would appear to succeed and every staff request would then fail with 401, only on the server, never on a developer laptop. That kind of "works locally, fails in production" bug is the worst kind to debug.
  - Fixing it means changing both Caddyfiles (stop stripping `Authorization`), which would then forward the gate's Basic credentials to the backend too, **leaking the gate password to a program that has no need for it.** We could strip only values that start with `Basic`, but that is a new, fragile rule in a security-relevant file.
  - It changes the written project rule ("never `Authorization`") and every staff doc.
- Benefit it would give here: none. There are no third-party clients that expect Bearer. The only client is our own restaurant app.

### Option B: cookie (`HttpOnly`, `Secure`, `SameSite=Strict`), set by the backend at login

- For: the token is not readable by page scripts (an XSS bug cannot steal it); the browser attaches it by itself.
- Against:
  - **`Secure` cookies are not stored over plain HTTP.** The local setup uses `http://customer.local` and `http://restaurant.local`, so the cookie would not persist in development unless we drop `Secure`, which weakens production.
  - **Cookies are attached automatically, so CSRF becomes our job.** A header that only our script sets is not sent by a forged form or image request. With a cookie we need `SameSite` plus a CSRF defence. The deployed proxy has a cross-site guard, but `dev/Caddyfile` does not, so development and production would behave differently.
  - The Flutter app needs to know whether it is logged in at startup. An `HttpOnly` cookie cannot be read by the app, so we would add a "who am I" route just for that.
  - It sits next to the gate's own browser-cached credentials, and the existing CROSS-SITE note shows that automatically attached credentials were already a real finding in this project once.
  - Logout must clear a cookie the app cannot see, so it depends on the server's `Set-Cookie` response.
- Benefit: real, but it protects only against stolen-by-script tokens (see section 6 for how we limit that risk otherwise).

### Option C: a custom header, `X-Staff-Session: <token>` (chosen)

- For:
  - **No collision with the gate** and no proxy change: it is not `Authorization`, so the gate and the proxy ignore it, and `X-Staff-*` is already passed to the backend (constraints 3 and 4).
  - **No CSRF exposure.** The browser never adds this header by itself. A forged cross-site form or image request cannot set it, and a cross-origin script request that sets a custom header triggers a CORS preflight that the backend does not allow (expected from the library's default allowed-header list; to be confirmed by a test, see section 7).
  - Same shape as the headers the project already uses, so the same code path in `StaffGate` can read it, and the old `X-Staff-Id` / `X-Staff-Password` headers can keep working for curl and the runbook.
  - Works the same over plain HTTP in development and over HTTPS in production.
  - Keeps the written rule "never `Authorization`" unchanged.
- Against:
  - The token lives where the app can read it. To survive a page reload the owner asked for, it has to be kept in `localStorage`, which **any script running on that page could read** (XSS). See sections 6 and 7.
  - It is not an industry-standard header name. No problem for us: there is only one client, and the name is documented in the contract.

## 4. Decision

Use a custom request header **`X-Staff-Session: <token>`**, with the token stored by the restaurant app in `localStorage` (key `food_orders_staff_session`) so a reload does not log staff out. Keep `Authorization` unused by the backend, as today.

The deciding reasons, in order of weight:

1. **It is the only option that works with the demo gate and the existing proxy without changing security configuration.** Bearer breaks on the server (constraints 1-3); the cookie needs changes and new defences.
2. **It avoids creating a new class of risk.** A header set only by our script is not subject to CSRF; a cookie would be.
3. **It matches the existing design** (`X-Staff-*`, same-origin, one request carries both the gate credentials and the staff proof) and the written rule.
4. **Bearer offers no benefit in this system**, since the only client is our own app.

## 5. The rest of the session design (recommended, to be written in `staff-login-contract` and `staff-login-backend`)

- **Account:** the existing shared `STAFF_ID` / `STAFF_PASSWORD`. No per-person accounts. "Multi-device" means any number of live sessions for that one account.
- **Token:** at least 32 random bytes from a secure random source, sent once at login (`POST /staff/login`), never logged.
- **Storage on the server:** only a keyed hash of each token (HMAC-SHA-256, keyed with the staff ID and password), in a new SQLite table. The database is not a place to keep a usable token: whoever reads the file (a backup, a stolen disk) gets hashes, not working sessions. Keying with the password means **changing the staff ID or password and restarting signs everyone out** (owner decided: yes). Sessions survive an ordinary restart.
- **Lifetime:** fixed 16 hours, then log in again. **No refresh token** (owner decided): a refresh token is a second, longer-lived secret that has to be stored and rotated, and with one shared account a daily re-login is cheap.
- **Logout:** `POST /staff/logout` revokes that one token. Other devices stay logged in.
- **Session cap:** at most 20 live sessions; the oldest ends first instead of refusing the login.
- **Wrong passwords:** the existing limiter (5 wrong tries in 60 seconds, then 429) keeps applying to the login. A request carrying a *valid* session is never counted and never refused. How a *wrong* token is counted is decided in `staff-login-contract` (a stale tablet must not lock the kitchen out). See the next point.
- **Lockout effect (found in the security review):** because changing an order's status is now a staff route, a lockout also blocks every status change and cancel for 60 seconds. Anyone on the wifi can trigger it. This was stated in `CLAUDE.md` as a known weak point.
- **Routes that accept the session:** menu `PATCH`/`POST`, `confirm-payment`, `staff-switch-to-cash`, and the status-changing `PATCH /orders/{id}`. The old password headers keep working on them, so curl and the runbook do not break.
- **Export:** `GET /orders/export` still requires the **password headers**; a session alone is 401 (owner request). The CSV is included because it holds customer names. A wrong export password does not end the session.
- **New dependency:** `crypto` becomes a direct backend dependency (it is already in `pubspec.lock` as a package pulled in by another one). The owner approved it on 2026-11-26. Hand-written hashing was rejected.
- **Audit log:** a separate task, `order-status-audit-log`, stores the session id (never the token, its hash or the password) and an optional device label typed at login.

## 6. Security properties and honest limits

What the header approach gives:

- No CSRF on staff routes through this header.
- No collision with the proxy gate, and no leak of the gate password to the backend.
- Revocable (logout, password change, expiry), time-limited (16 hours), stored only as a keyed hash.

What it does **not** give, and what we do about it:

| Limit | Why it exists | Mitigation or acceptance |
|---|---|---|
| A script injected into the page could read the token from `localStorage` | The reload-survival requirement forces persistent client storage. A cookie would hide it from scripts but brings CSRF and plain-HTTP problems (section 3). | Short life (16 h), logout revokes, a password change revokes all, no user-supplied HTML is rendered by the apps. **No `Content-Security-Policy` is set today;** adding one is a sensible follow-up task, not part of this work. |
| A stolen token works for up to 16 hours | No refresh or per-request binding | Logout, password change, short lifetime |
| One shared account | Owner decision; no per-person accounts | Audit log records session and device, not a person |
| Anyone on the same wifi can sniff a token over plain HTTP | The local and demo-without-HTTPS setups use HTTP | Use HTTPS when hosted (already the documented rule) |
| The login screen is a convenience, not a data gate | `GET /orders` and the live stream stay open (existing accepted risk) | Stated in the contract |
| Customer routes (`switch-to-cash`, `renew-payment`) stay open | Accepted risk since the payment feature | Unchanged; the contract text was corrected to say only these remain |

## 7. What is verified and what is not

**Checked in the repository (this session):**
- the gate uses `basicauth` and the proxy deletes `Authorization` before the backend (both Caddyfiles);
- `X-Staff-*` headers are the existing staff proof and pass the proxy;
- the backend never reads `Authorization`;
- `crypto` exists in `backend/pubspec.lock` only as a transitive package today (so a direct dependency needs the approval that was given).

**Expected but not yet tested** (the tasks include tests or owner checks for each):
- that a CORS preflight for `x-staff-session` is refused by the backend's default `corsHeaders()` configuration (a test is written into the backend card);
- that the systemd `deploy/Caddyfile` passes `X-Staff-Session` unchanged on a real server;
- that the request logger never prints the header;
- browser behaviour of `localStorage` in private windows and across tabs;
- the full login, 16-hour expiry, logout and multi-device flow in a real browser, and over the real HTTPS demo gate.

## 8. When to revisit this decision

- If a **second, non-browser client** appears that expects `Authorization: Bearer`, add Bearer support next to the header (the backend check can accept both).
- If the project **drops the Caddy basic-auth gate**, Bearer would no longer collide, but there would still be no benefit to switching.
- If a **Content-Security-Policy** cannot be adopted and XSS exposure becomes a concern, reconsider an `HttpOnly` cookie, together with a CSRF defence and an HTTPS-only deployment.
- If **per-person accounts** are added, the token design carries over, and the audit log can then name a person.

## 9. Where this will be written into the contract

- `CLAUDE.md` "Staff ID and password" and the API table: the login and logout routes, the `X-Staff-Session` header, what each staff route accepts (written by `staff-login-contract`, which needs the owner's explicit approval to edit `CLAUDE.md`).
- `docs/deploy.md` and `docs/runbook-local.md`: how staff log in, how to sign everyone out (change the password and restart), and the lockout note (written by `staff-login-docs`).
