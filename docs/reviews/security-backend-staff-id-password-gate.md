---
task: backend-staff-id-password-gate
status: passed
p0: 0
p1: 0
---

# Security review: backend-staff-id-password-gate

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-backend-staff-id-password-gate.md`.

- **Assets:** the shared staff ID and password in the process environment, the staff-only routes, and the customer data in the export.
- **Attacker inputs:** the `x-staff-id` and `x-staff-password` headers, and the request rate.
- **New capability:** an in-memory global lockout.

## Round 1: passed. P0 0, P1 0, P2 3

1. **Wall-clock lockout:** `DateTime.now` can jump backwards, which would make a lock last longer than 60 s. Memory stays bounded (the list is capped at 5). **Deferred** (optional: a monotonic `Stopwatch`, or clamping the lock end).
2. **Stale "token" comment in `bin/server.dart`.** **Fixed.**
3. **The restaurant clients still send `X-Staff-Token`** until the next card, so staff actions get 401 and count toward the lockout. That's expected; the cards go out together.

Checked and clean:
- **Fail closed:** an invalid configuration gives 403 before any comparison; the default gate is disabled.
- **Constant time:** both halves are always evaluated. `constantTimeEquals` depends only on the sent length; there's no leading-byte or expected-length oracle.
- **Lockout:**
  - memory is bounded;
  - no race (single isolate, synchronous check);
  - no oracle: while locked every request gets 429, correct ones included, with a fixed body, and failures aren't counted during a lock;
  - at most 5 guesses per 60 s;
  - `Retry-After` is always ≥ 1.
- **No `WWW-Authenticate`.**
- **CORS:** the custom headers aren't on the `shelf_cors_headers` allow-list, so a cross-site preflight fails.
- **No logging** of the ID, password or attempts; the startup line shows only enabled/disabled and the rule constants.
- **Duplicate headers** give no advantage.
- **The `CLAUDE.md` startup line** keeps both values out of argv and history (`read -rs` for the password).
- **No new dependency.**

## Gates

See `execute-backend-staff-id-password-gate.md`. `make check` exits 0.

## Needs the real environment

- Startup with the real variables, and 200/401/403/429 via curl through Caddy.
- Caddy keeps `Retry-After` and doesn't add `WWW-Authenticate`.
