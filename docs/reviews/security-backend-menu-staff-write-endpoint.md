---
task: backend-menu-staff-write-endpoint
status: passed
p0: 0
p1: 0
---

# Security review: backend-menu-staff-write-endpoint

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-backend-menu-staff-write-endpoint.md`.

- **Assets:** menu prices and the sold-out flag (customers see and pay these), the staff token, and process availability.
- **Attacker inputs:** the `X-Staff-Token` header, the `<id>` path segment, and the PATCH body.
- **New capability:** the first write path outside orders, gated by the shared token.

## Round 1: passed. P0 0, P1 0, P2 3 (optional)

Checked and clean:
- **Auth before body:** a request without the token never has its body read. A 401/403 stops the cascade, and a 404 falls through to APIs with no matching PATCH route.
- **Fail closed:** the default `StaffGate(null)` gives 403. The server passes the real gate. Denial bodies are fixed.
- **SQL:** the column names come from literals chosen by `containsKey`, after every other key was refused; values and the id are bound. No injection.
- **Id:** shelf_router 1.1.5 doesn't decode, so the handler's single `Uri.decodeComponent` is right and there's no double decode. A malformed escape gives 404.
- **Body cap:** a declared length over 4096 is refused, and a chunked body is cut off past 4096. Malformed UTF-8 and bad JSON can't crash it.
- **Strict types:** a bool, string or null price, Infinity, negatives and values over the cap are refused; `available` must be a bool, so SQLite never coerces `"1"`.
- **Logging:** only the request line is logged, never headers.
- **CORS:** the default allow-list has no `x-staff-token`, so a cross-origin preflight fails. No cookies, so no CSRF.
- **Docs:** the curl example keeps the literal `$STAFF_TOKEN` in shell history.
- **MENU-EDIT5 / MENU-DB3:** documented, not fixed, as the card intends.
- No new dependency.

P2:
1. **Fractional prices** were accepted. **Fixed:** whole numbers only.
2. **`curl -H` exposes the token to `ps`** while it runs. **Fixed in the docs** (`curl -H @file` on shared machines).
3. **No rate limiting,** and a weak 16-character token would pass. Known and accepted (card non-goals, gate review); the docs advise `openssl rand -hex 24`.

## Re-review 1: passed. P0 0, P1 0, P2 0

The whole-price check runs after the `isFinite` check, so `truncate()` never sees Infinity or NaN. The docs note is accurate (`-H @file` needs curl 7.55+, which Ubuntu has).

## Gates

See `execute-backend-menu-staff-write-endpoint.md`. `make check` exits 0.

## Needs owner confirmation in the real environment

- The PATCH, 401 and 403 cases through Caddy.
- A browser preflight with `Access-Control-Request-Headers: x-staff-token` is rejected.
- `STAFF_TOKEN` in the deploy runbook (pending).
