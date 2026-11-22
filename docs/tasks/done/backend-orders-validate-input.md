---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: []
securityReview: required
---

# Validate order input on POST and PATCH (contract tightening before the database)

## Why

A database table has fixed columns, so the backend must know what an order looks like. Today it stores any JSON object as-is, and PATCH merges any field (it can overwrite `id`, `items`, anything). That cannot survive a schema. This card tightens the contract first, while storage is still in memory, so the database card is a pure storage swap. Invariant 3: table first, then backend.

The Flutter client already conforms: `OrderApiClient.updateStatus` sends only `{"status": ...}` and `placeOrder` sends `Order.toJson()`. No client change is needed.

## Sources

`backend/lib/orders_api.dart`, `backend/test/orders_api_test.dart`, `lib/shared/models/order.dart` (`Order.toJson`, `OrderStatus` names), `lib/shared/api/order_api_client.dart`, `CLAUDE.md` "Backend".

## Goal

1. Update the API table in `CLAUDE.md` -> "Backend" (owner approval for this edit is requested by this card):
   - POST `/orders`: 400 unless the body has `id` (non-empty string), `customerName` (string), `items` (list of `{name: string, quantity: int, price: number}`), `status` (a known status name), `placedAt` (ISO-8601 string). **409** if an order with that `id` already exists. Unknown extra fields are rejected or dropped (see open decision 1).
   - PATCH `/orders/{id}`: body must contain `status` with a known status name, otherwise 400. Only `status` is applied; nothing else can change. 404 for unknown id (unchanged).
2. Implement in `OrdersApi` (still in memory). The list of valid status names lives in the backend as a small constant, because `backend/` may not import `lib/` (invariant 4). Add a comment pointing at `OrderStatus` so the two are kept in sync.
3. Tests first or alongside, in `backend/test/orders_api_test.dart`.

## Non-goals

- No database. No server-generated ids (a later, separate contract change if the owner wants it).
- No body-size limit (that is `backend-request-body-limit`).
- No Flutter-side handling of 400/409 responses. `OrderApiClient` does not check status codes today; with valid app traffic these errors cannot occur. Note as a follow-up if the owner wants it.

## Decisions (owner, 2026-11-06)

1. **Unknown extra fields on POST: reject with 400.** (DB4)
2. **Empty `items`: reject with 400.** (DB5) The executor still checks the cart flow first; if the app can currently send an empty order, stop and report rather than break it.
3. **Status transitions: not enforced.** (DB6, option A) PATCH accepts any known status name. Forward-only rules are a possible later card, most useful once there is auth.

## Tests written with the change

In `backend/test/orders_api_test.dart`: POST missing each required field -> 400; wrong types -> 400; unknown status -> 400; duplicate id -> 409 and original order unchanged; PATCH without `status` -> 400; PATCH with unknown status -> 400; PATCH with `{"status":"accepted","id":"other","customerName":"x"}` changes only status; existing 15 tests still pass (adjust fixtures only if they used invalid orders, and say so in the review).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Invalid POST/PATCH bodies get 400, duplicate id gets 409, state unchanged | `make backend-test`, `make backend-analyze` (gates) |
| PATCH can only change `status` | `make backend-test` (gate) |
| `CLAUDE.md` API table matches the code | `code-reviewer` (review) |
| Status list matches `OrderStatus` | `code-reviewer` (review) |
| No new exposure, no crash on odd JSON | `security-reviewer` (review; JSON parsing trigger) |
| `make check` green | `make check` exit 0 (gate) |
| Placing an order and accepting it still works in the apps | owner acceptance in the browser |
