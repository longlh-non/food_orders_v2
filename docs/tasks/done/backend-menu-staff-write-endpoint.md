---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-menu-availability-column, backend-request-body-limit, backend-staff-token-gate]
securityReview: required
---

# Staff-only menu write endpoint (PATCH /menu/{id}) behind a shared staff token

## THE critical issue: menu writes with no auth

Plain words: today anyone who can reach `/api` can already create and cancel orders. That is bad but contained. A menu write endpoint is worse: whoever can send one request could change a price to 0.01, mark everything sold out, or (if delete existed) empty the menu. Every customer sees and pays what the menu says. Today "anyone who can reach /api" means every phone on the home wifi (mDNS, port 80). Once hosted it means the whole internet. So the write endpoint must never exist without a gate. This card builds the endpoint and the gate as one unit so there is never an ungated version.

### Open decision MENU-EDIT0 (owner): how are menu writes protected?

- (a) Accept the risk for local dev, never deploy editing ungated. Cheapest, but one forgotten step at deploy time exposes prices. Not enough alone.
- (b) A shared staff secret. Backend reads `STAFF_TOKEN` from its environment (never committed). Every menu write must send it in a header; the restaurant app asks staff for it once and keeps it only in memory. Small (one check, one dialog), works with the existing stack, no new package. Weak points, stated honestly: one shared secret for everyone, no per-person accounts, no logout/rotation except restarting the backend with a new value, and on plain-HTTP wifi it can be sniffed by someone on the same network (fine for a home demo; HTTPS only when hosted).
- (c) Rely on the Caddy basic-auth gate from `deploy-demo-access-gate`. That only exists on the hosted setup, not on local wifi, and both hostnames share `/api`, so a customer who knows the demo password could also edit prices. It cannot tell staff from customers. Fine as an extra layer, not as the staff gate.
- (d) Real staff login (accounts, sessions, roles). The right answer before real customers; a separate, bigger card set with product decisions (who creates staff accounts?). Not planned here.

**Recommendation: (b), with (a)'s rule kept (no ungated editing) and (c) as an extra layer when hosted. (d) before real customers.** This card implements (b). If the owner chooses (a) only or (d), drop or rewrite this card before anything below runs. Go-live is blocked until this card is done AND the runbook sets `STAFF_TOKEN` on the server (see Deployment note).

## Why

Owner confirmed M1: staff edit the menu from the restaurant app. This is the backend half, contract-first (invariant 3): `CLAUDE.md` table, then backend, then client (`menu-item-available-and-staff-client`).

## Sources

`CLAUDE.md` "Backend" table and "Safety policy"; `backend/lib/menu_api.dart`, `backend/lib/orders_api.dart` (validation style from `docs/tasks/done/backend-orders-validate-input.md`, CORS/JSON headers, body-limit helper from `backend-request-body-limit`), `backend/bin/server.dart`.

## Decisions to confirm (owner), with recommendations

- MENU-EDIT1 scope of edits in the first release. Recommended: **change price and toggle sold-out only** (`PATCH /menu/{id}`). It covers the daily need, never changes what ids mean, and cannot orphan anything. Add item and rename are the next most useful (a later card, only if the owner wants it). Delete: not recommended. Orders store item names and prices by value so old orders survive a delete, but the id would vanish before the server-side price lookup (MENU-DB3), which will need ids; "sold out" already hides an item from ordering. If delete is ever wanted, make it a soft flag, not a row removal.
- MENU-EDIT2 who makes ids for new items (only matters if add is built later). Recommended: the server generates them (random, e.g. 8 hex chars from `Random.secure()`), client never supplies one, so no collision handling or id typos from tablets.
- MENU-EDIT3 validation rules (below). Recommended as written; the exact upper price cap (suggested 1,000,000) is the owner's to adjust.
- MENU-EDIT4 concurrent edits (two staff tablets). Recommended: last write wins. PATCH changes only the fields it names, so one tablet toggling sold-out and another changing the price do not overwrite each other. Same-field races just take the later one. No versioning or locking.

## Goal

1. `CLAUDE.md` -> "Backend" table (owner approval requested by this card): add `PATCH /menu/{id}` — header `X-Staff-Token: <token>`, body `{"price"?: number, "available"?: boolean}` (at least one field), 200 -> the updated item (same shape as `GET /menu` items). Errors: 400 invalid body, 401 missing/wrong token, 403 menu editing disabled (no token configured on the server), 404 unknown id, 413 too large (from the body-limit card). Add a "Menu editing" paragraph: the token is set when starting the backend, e.g. `STAFF_TOKEN=<long random value> dart run bin/server.dart` (owner generates, agents never see or write it), never committed. Update "Known limitations": no per-person auth, one shared token.
2. Backend: route mounted in `MenuApi` (same file; reads stay public). Token check before the body is parsed. Rules:
   - `STAFF_TOKEN` unset, empty, or shorter than 16 characters -> editing is disabled: every PATCH returns 403 even with a header. Fails closed.
   - Compare with a constant-time comparison (small helper, no new package). Never log or echo the token or the header.
   - Body must be a JSON object with only the keys `price` and `available`; any other key -> 400. `{}` -> 400. `price`: a JSON number, finite, `>= 0`, `<= 1000000` (note `1e999` decodes to infinity in Dart: reject). `available`: strictly a boolean (not `"true"`, not 1). Body not JSON / not an object -> 400. Error bodies are short fixed messages, not echoes of input.
   - Parameterised `UPDATE ... WHERE id = ?`; the id comes from the path and is only ever a bound parameter.
   - Only the named fields change, in one statement; response is the row after the update.
   - No SSE event for menu changes (see M5 decision in `customer-menu-sold-out-items`).
   - CORS: the apps are same-origin through Caddy, so do NOT add `X-Staff-Token` to allowed CORS headers or widen origins. Executor checks what the existing CORS helper does for preflight and reports; the point is not to invite cross-site menu writes.
3. `POST /menu` and `DELETE /menu/{id}` stay unimplemented (404/405).

## Non-goals

Add/rename/delete endpoints, login pages, per-user accounts, token rotation UI, rate limiting (mitigation: a long random token; brute-force limiting belongs to the real-auth card (d) or the proxy), changing orders, server-side price lookup on `POST /orders` (MENU-DB3, below), Flutter changes.

## Tests written with the change

In `backend/test/menu_api_test.dart` (`:memory:` database per test, token passed to `MenuApi` by constructor so tests never read the real environment):
- no header -> 401 and the row unchanged; wrong token -> 401; correct token on a different-length token (length mismatch) -> 401;
- token not configured, or configured too short -> 403 even with a header; row unchanged;
- valid price change -> 200, response has the new price, `GET /menu` shows it, other fields and other items unchanged; valid `available: false` and back to true; both fields together;
- invalid: `{}`, `[]`, non-JSON, extra key (`name`), `price` negative / string / null / `1e999` / `1000001`, `available` as string or number -> 400 and the row unchanged;
- unknown id -> 404; id containing `'; DROP TABLE menu_items;--` -> 404 and the table still intact;
- oversized body -> 413, row unchanged; `POST /menu` and `DELETE /menu/{id}` -> not 200;
- orders endpoints and SSE unchanged (existing tests pass); response headers never contain the token.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Writes rejected without a correct token; disabled when no token configured | `make backend-test` (gate) |
| Validation rules as listed, state unchanged on 4xx | `make backend-test` (gate) |
| Backend clean | `make backend-analyze` (gate) |
| Constant-time compare, token never logged/committed, parameterised SQL, CORS not widened, fail-closed default | `security-reviewer` (review; endpoint + auth trigger) |
| `CLAUDE.md` table and token instructions match code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| With `STAFF_TOKEN` set, `curl -X PATCH` with the token changes a price visible in `GET /api/menu`; without it, 401; without the env var, 403 | owner acceptance in the real environment - "unverified" until done |

## Deployment note (no edit to deploy cards)

`deploy-production-config` / `deploy-runbook` must supply `STAFF_TOKEN` to the backend through the server-only `EnvironmentFile` (same mechanism as `FOOD_ORDERS_AUTH_HASH`), never from the repo. Because the backend fails closed when it is unset, a deploy that forgets it simply has editing disabled, not open. Add this to the runbook when it is executed. `deploy-demo-access-gate` is an extra layer, not a replacement for this card.

## Environment limits

Agents never see or create the real token and never run the backend behind Caddy; the owner generates the token (e.g. `openssl rand -hex 24`), exports it, and runs the curls.

## Price changes vs open carts (MENU-EDIT5), and MENU-DB3

A customer who added a burger at the old price keeps the old price in their cart, and the order they send carries that price, because the server trusts the browser's price today (M3). Editing prices makes this honest mismatch likely, not just a theoretical attack. Recommendation: M1 makes the server-side price lookup (MENU-DB3: order items carry the menu `id`, server prices them, rejects sold-out/unknown ids) more urgent. Do it right after this set and before go-live. It is not a blocker for the local demo; until then a sold-out switch only affects the menu page, not an already-open cart or a hand-made request. It is a separate contract card (changes `POST /orders`, `Order.toJson()`, both apps); not written here.

## Added 2026-11-12: reuse the staff token gate

The owner chose a staff-token-protected HTTP export (EXP3 = b), so the token check now has its own card, `backend-staff-token-gate` (added to `blockedBy`). This card **reuses** its helper for `PATCH /menu/{id}` instead of writing a second check. The rules are the same as in Goal 2: fail closed under 16 characters, constant-time compare, nothing logged. Its tests cover the gate itself; this card only tests that the menu route uses it (401/403 cases, row unchanged). MENU-EDIT0 is still the owner's to confirm for **menu writes**, but option (b) is now the mechanism already built.

## Owner decisions and executor notes (2026-11-17)

- **Owner decisions:** the owner accepted MENU-EDIT0–4 as recommended:
  - MENU-EDIT0 = the shared staff token (`backend-staff-token-gate`);
  - MENU-EDIT1 = price and sold-out only;
  - MENU-EDIT2 = server-made ids if adding items comes later;
  - MENU-EDIT3 = price 0–1,000,000 VND;
  - MENU-EDIT4 = last write wins.
  - The owner approved the `CLAUDE.md` edits for this card.
- **Gate:** `MenuApi(db, {StaffGate? staffGate})`. With no gate, menu writes answer 403 (fail closed). `bin/server.dart` passes the server's gate.
- **413:** the body-limit card put the 64 KB limit only in the proxy, so this route also reads its body with its own cap (`maxMenuEditBytes` = 4096). It refuses a too-large `Content-Length` before reading, and stops reading as soon as the cap is passed. The token is checked before the body is read.
- **CORS:** checked against `shelf_cors_headers` 0.1.5 (`backend-staff-token-gate` review). Its default `Access-Control-Allow-Headers` (accept, accept-encoding, authorization, content-type, dnt, origin, user-agent) don't include `x-staff-token`, so a cross-site page can't send the token (the preflight fails). Nothing was widened.
- **SQL:** the `UPDATE`'s column names come from a fixed list in the code. The id and the values are always bound parameters.
- **From the `backend-menu-availability-column` security review:** `available` is checked as a strict JSON boolean (`"1"`, `0` and `null` are refused), because SQLite would otherwise coerce `"1"`.
- **Deployment note:** not yet added to `deploy-runbook`. As this card says, add it when the runbook is executed.
