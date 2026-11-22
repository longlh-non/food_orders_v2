---
task: backend-staff-token-gate
status: passed
p0: 0
p1: 0
---

# Security review: backend-staff-token-gate

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-backend-staff-token-gate.md`.

**Assets:** the shared staff token, and later the customer data the export returns. **Attacker input:** the `X-Staff-Token` header. **New capability:** a gate that no route uses yet.

## Round 1: passed. P0 0, P1 0, P2 4

1. **Pre-existing exposure (accepted, docs/expectation):** `GET /orders` and `GET /orders/stream` already send every customer name and order to anyone on the wifi, with no token. Until those routes are gated, a token on the month export adds no confidentiality, and neither the docs nor the next card may claim it does.
2. **Token visibility:** `CLAUDE.md` showed `STAFF_TOKEN='<value>' dart run ...`. That leaves the token in shell history, and in `/proc/<pid>/environ` and `ps e` output (same user or root).
3. **Untrimmed token:** a configured token with surrounding whitespace never matches. It fails closed; this is an operational annoyance only.
4. **Notes for the next card:**
   - send `Cache-Control: no-store`;
   - never accept the token in the query string, because `logRequests` logs URLs;
   - run the gate before any database work;
   - Cascade only falls through on 404/405, so 401/403 are safe.

Checked and clean:
- **Fail-closed:** null, empty and short tokens give 403 even with a matching header. 403 versus 401 reveals whether staff routes are enabled, which is minor.
- **Comparison:** the loop runs once per character of the sent value, so its cost doesn't depend on the secret. The only thing leaked is the guess's own length.
- **Header handling:** names are lowercased and values trimmed. Duplicate headers are joined with ", " and never match, so there's no bypass.
- **No leaks:** fixed response bodies; the start-up print shows only enabled or disabled; `logRequests` doesn't log headers.
- **Supply chain:** no new dependency, and no `.claude/`, CI or `dev/` changes.

## Fixes

- **Item 3:** `StaffGate` trims the configured token before the length check, with tests.
- **Item 2:** `CLAUDE.md` now suggests `read -rs STAFF_TOKEN && export STAFF_TOKEN && dart run bin/server.dart`, with the environment caveat.
- **Items 1 and 4:** written into `docs/tasks/backend-orders-month-export-endpoint.md`, section "Added by `backend-staff-token-gate` reviews".

## Re-review 1: passed. P0 0, P1 0

- **Trimming:** it still fails closed. The sent header is compared untrimmed, so senders get no extra leeway, and the effective entropy is unchanged.
- **Docs:** the `CLAUDE.md` guidance is correct.
- **CORS (corrected):** `corsHeaders()` is applied inside `OrdersApi`, not in `server.dart`; round 1 got that wrong. The conclusion still holds. `shelf_cors_headers` 0.1.5's default allow-headers don't include `x-staff-token`, so a cross-origin browser request with it fails preflight. Auth uses a header and no cookies, so there's no CSRF path.
- **P2, a note for the next card, added there:**
  - `authorization` *is* in the default CORS allow-list, and any `Origin` is reflected. Keep staff auth on `X-Staff-Token` only, never `Authorization: Bearer`, and never add `x-staff-token` to the allow-list.
  - The reflected `Origin` also means any web page the owner visits can read the open `GET /orders`. That's the same pre-existing exposure as item 1.

## Gates

See `execute-backend-staff-token-gate.md`. `make check` exits 0 on the final candidate.

## Needs owner confirmation in the real environment

- **Start-up line:** starting the backend with and without `STAFF_TOKEN` prints the right enabled/disabled line.
- **Through Caddy (next card):** `X-Staff-Token` is forwarded and not written to Caddy's access log.
