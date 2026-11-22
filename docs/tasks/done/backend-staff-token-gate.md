---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: []
securityReview: required
---

# Backend: a shared staff token check, reusable by staff-only routes

Planned 2026-11-12 after the owner chose **EXP3 = (b)**: the monthly export becomes an HTTP endpoint behind a staff token. The token check is its own card so the export does not wait for the menu-editing chain (`backend-menu-availability-column`, `backend-menu-staff-write-endpoint`, open MENU-EDIT0). `backend-menu-staff-write-endpoint` reuses this helper instead of building its own.

## Why

Today every `/api` route is open to anyone on the wifi (later, the internet). The export returns every customer's name and order history, so it must never exist without a gate. This card adds only the gate, with no route using it yet, so it is small and fully testable.

## Design (plain words, with the trade-off)

- The backend reads `STAFF_TOKEN` from its environment at start (never committed, never written by an agent; the owner generates it, e.g. `openssl rand -hex 24`).
- A staff request sends it in the header `X-Staff-Token`.
- **Fails closed:** `STAFF_TOKEN` unset, empty or shorter than 16 characters means staff routes are disabled: they answer **403** even with a header.
- Missing or wrong header: **401**.
- Constant-time comparison (small helper, no new package). The token and the header value are never logged, echoed or put in an error body.
- Weak points, stated honestly (same as MENU-EDIT0 option b): one shared secret for all staff, no per-person accounts, rotation = restart the backend with a new value, and on plain-HTTP wifi someone on the same network can sniff it. HTTPS when hosted. Real staff login (MENU-EDIT0 d) is still needed before real customers.
- CORS: the apps are same-origin through Caddy. `corsHeaders()` (shelf_cors_headers) does not list `X-Staff-Token` in its allowed headers, so a cross-site page cannot send it (the browser preflight fails). Do **not** add it. The executor confirms this against the installed package version and reports.

## Sources

`backend/bin/server.dart` (how `ORDERS_DB` is read: copy the "empty counts as unset" rule), `backend/lib/orders_api.dart` and `backend/lib/menu_api.dart` (handler style), `docs/tasks/backend-menu-staff-write-endpoint.md` (the same rules, written earlier for menu writes), `CLAUDE.md` -> "Safety policy".

## Goal

1. `backend/lib/staff_token.dart`: a small class or function, e.g. `StaffGate(String? configuredToken)` with `Response? check(Request req)` returning `null` when allowed, else a 401/403 `Response` with a short fixed JSON message. Plus `bool constantTimeEquals(String a, String b)`.
2. `backend/bin/server.dart` reads `STAFF_TOKEN` once and passes it to whatever needs it (nothing yet; the export endpoint card wires it). The token value is never printed. At start, print one line saying whether staff routes are **enabled** or **disabled** (no value, no length).
3. `CLAUDE.md` (owner approval needed for this edit, per task): a short "Staff token" paragraph under "Backend": how to start with it (`STAFF_TOKEN=<long random value> dart run bin/server.dart`), never commit it, what 401/403 mean, the weak points above. "Known limitations": one shared staff token, no per-person auth.

## Non-goals

Any route using the gate (next card), Flutter changes, login, rate limiting (a long random token is the mitigation; brute-force limiting belongs to real auth or the proxy), token rotation UI.

## Tests written with the change

`backend/test/staff_token_test.dart` (token given by constructor, never read from the real environment):
- correct token -> allowed; missing header -> 401; wrong token same length -> 401; wrong token different length -> 401;
- configured token null, empty, or 15 characters -> 403 even with a matching header;
- 401/403 bodies never contain the configured token or the sent header value;
- `constantTimeEquals` true/false cases including different lengths and non-ASCII.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Rules above | `make backend-test` (gate) |
| Backend clean | `make backend-analyze` (gate) |
| Fails closed, no token in logs or responses, constant-time compare, CORS not widened | `security-reviewer` (review) |
| `CLAUDE.md` paragraph matches the code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Backend started with and without `STAFF_TOKEN` prints enabled/disabled and never the value | owner acceptance - "unverified" until done |

## Environment limits

Agents never see, generate or write the real token. The owner sets it in the shell that starts the backend.

## Owner approval (2026-11-12)

The owner approved the `CLAUDE.md` edit for this card: the "Staff token" paragraph under "Backend" and the "Known limitations" line.
