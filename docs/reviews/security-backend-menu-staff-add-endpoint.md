---
task: backend-menu-staff-add-endpoint
status: passed
p0: 0
p1: 0
---

# Security review: backend-menu-staff-add-endpoint

No exploitable path found (P0 0, P1 0, P2 2).

Checked clean: gate before the body is read (disabled gate 403, lockout 429, constant-time compare, one shared gate instance); body size (declared length, then counted bytes, chunked and lying lengths; 4 KB, plus the proxies' 64 KB); JSON edge cases (non-objects, huge numbers, duplicate keys, unknown keys 400 so `id` / `available` can't be sent); all values bound parameters; ids only `[a-z0-9-]`, at most 53 characters, never a file path; one `BEGIN IMMEDIATE` transaction with no `await` inside and a rollback on every exit; bounded work (300 rows, 1000 id attempts); fixed error texts; a cross-site simple request cannot set the `X-Staff-*` headers, and a hostile page lacks the password.

## Findings

- P2-1 (deferred, accepted as staff-only): `name` and `description` accept bidi overrides and zero-width characters (U+200B..U+200F, U+202A..U+202E, U+2060..U+2069, U+FEFF), so a pasted name could display misleadingly and escape the duplicate check. Needs valid staff credentials. Rejecting them would widen the contract ("no control characters") and is left to a decision.
- P2-2 (deferred): if `BEGIN IMMEDIATE` times out (a stuck `sqlite3` CLI writer), the reply is a 500. Nothing leaks; mapping it to a fixed 503 is optional.

## Unverified

- A real OPTIONS preflight with `Access-Control-Request-Headers: x-staff-id` should be rejected by the CORS middleware (same as the existing `PATCH`); not run.
- `dev/Caddyfile` and `dev/nginx.conf` have no `Sec-Fetch-Site` guard (unchanged by this card; `deploy/Caddyfile` has it).
- Whether menu names reach the CSV/Excel exports was not traced (the exports read order lines, not menu rows).
