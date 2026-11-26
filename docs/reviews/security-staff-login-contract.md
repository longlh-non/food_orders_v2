---
task: staff-login-contract
status: passed
p0: 0
p1: 0
---

# Security review: staff-login-contract

Reviewer: security-reviewer, run on the staff login contract in `CLAUDE.md` (the card has `securityReview: required`). Read-only; nothing run. Round 1: P0 0, **P1 1**, P2 4. Round 2: P0 0, P1 0, P2 2. All fixed in the text.

## Round 1

**P1 fixed: the lock exemption was keyed on header presence.** The text said a request "carrying `X-Staff-Session`" is never counted and never refused by the lock. A literal implementer would have exempted `POST /staff/login` and the export too, so an attacker sending `X-Staff-Session: x` plus password guesses would bypass the only brute-force control on the shared password. **Fixed:** one rule, stated identically in the 429 bullet, the brute-force bullet, the routes bullet, the export, login and logout rows and card SL-e: on the five session-accepting routes a present session is judged alone (valid: allowed even during a lock; invalid: 401, never counted, password headers ignored); on login and export the header is ignored and gives **no** exemption; logout is never counted and never refused.

**P2 fixed:**
1. The login credential comparison now requires `constantTimeEquals` on both halves with no short-circuit, and a wrong pair counts toward the lock.
2. The eviction trade-off is in Weak points: anyone who has the password can log in 20 times and end every legitimate session (accepted).
3. Changing the password and changing it back could revive old tokens: sessions made under another key are deleted at the next login and at startup, and "live" for the 20-session cap means unexpired and verifiable under the current key.
4. The localStorage limitation now mentions third-party scripts (the app and a CDN); `frame-ancestors 'none'` only stops framing.

## Round 2 (P0 0, P1 0, P2 2, both fixed)

The bypass attempts were all closed in the text: a junk session header on login or export; password headers plus a session header on a session route (the password headers are never evaluated, so there is no guess to count and no oracle); a session and password headers during a lock; guessing a 256-bit token while invalid sessions are uncounted (infeasible, the server compares an HMAC).

- **P2 fixed:** the text said logins could be locked out "for a minute at a time". An attacker can keep the lock held for as long as they keep sending wrong passwords, which matters at the start of a shift when every session has expired. It now says so plainly, and names the recovery (restart the backend, since the lock is in memory). Signed-in staff on the five routes keep working.
- **P2 fixed:** the text now says a staff-route request without a session gets 429 during a lock.

## Checked and clean

Token: 32 random bytes from a secure source, base64url, not derived from anything; only an HMAC-SHA-256 keyed with the staff ID and password is stored, so a stolen database yields nothing usable and the password cannot be recovered; the key is unambiguous (the ID is printable ASCII with no newline). Logging and URLs: the token is banned from URLs, logs, errors and bodies; the login reply is `no-store`; `logRequests()` logs method and path only. A captured token works only on the five routes: it cannot export, mint sessions, extend itself or end other sessions. Header choice: correct against the repo (both deployed Caddyfiles strip `Authorization`; a custom header passes and is never added by the browser, so no CSRF path). Accepted risks (open `GET /orders`, the stream, the customer routes) are stated accurately; the login is called a convenience gate, not a data gate. Nothing tells an implementer to log, commit or env-inject a secret; the audit log holds the session id and label only.

## Needs confirmation in a real environment

The CORS preflight refusing `x-staff-session`; `X-Staff-Session` passing the systemd and Docker Caddyfiles unchanged; the request logger never printing the header; `localStorage` behaviour in private windows and across tabs; that the startup deletion of unverifiable sessions really runs.
