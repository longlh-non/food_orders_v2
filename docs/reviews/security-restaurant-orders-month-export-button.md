---
task: restaurant-orders-month-export-button
status: passed
p0: 0
p1: 0
---

# Security review: restaurant-orders-month-export-button

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-restaurant-orders-month-export-button.md`.

- **Assets:** the staff token and the customer-data CSV.
- **Attacker inputs:** the server's response and the month string.
- **Boundary:** same-origin `/api` → backend.

## Round 1: passed. P0 0, P1 0, P2 2

Checked and clean:
- **Token handling:** the token is only in the `X-Staff-Token` header (a test asserts the URL doesn't contain it). Exceptions and the dialog show fixed text only.
- **No persistence:** an in-memory static, with no localStorage, sessionStorage or cookie.
- **Same origin:** a relative `Uri(path:)`.
- **Month and file name:** the month is validated by an anchored regex before sending; the file name comes only from the fixed month list (no injection).
- **401 and retries:** a 401 clears the token, and there's no automatic retry (every attempt needs a user action, gated while busy). The token is stored only after a 200.
- **Download:** a constant MIME type; the Blob is never rendered inline; the CSV is formula-neutralised server-side.
- **Boundaries:** the web-only code sits behind the conditional export; nothing added to shared.

P2:
1. **The token crosses the wifi in cleartext** (no TLS on `restaurant.local`). **Fixed in docs:** `docs/runbook-local.md` section 4 says to use it only on a trusted wifi until HTTPS.
2. **Browser password manager:** it may offer to save the obscured field. **Fixed:** `autofillHints: const []` and `enableIMEPersonalizedLearning: false`, with a test. A browser may still offer to save a password input (to check in a real browser).

Also noted: `revokeObjectURL` right after `click()` (Safari). Fixed with a 10 s delay.

## Re-review 1: passed. P0 0, P1 0, P2 0

- **The new `on Object` catch:** it leaks nothing, and it runs after the 401 handling, so the token is still cleared on 401.
- **Closing the client in `whenComplete`:** this aborts an in-flight request on dismiss; nothing is saved and no token is written.

## Gates

See `execute-restaurant-orders-month-export-button.md`. `make check` exits 0.

## Needs real-environment confirmation

- The download in Chrome and in iOS Safari via `restaurant.local`.
- The browser doesn't prompt to save the token.
- Caddy forwards `X-Staff-Token` on `/api/*`.
