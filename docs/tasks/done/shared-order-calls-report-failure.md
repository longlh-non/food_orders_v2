---
executor: task-executor
scopes: [shared]
workKinds: [flutter, quality-gate]
blockedBy: []
securityReview: required
---

# Order calls report failure (client and repository)

## Why

Found 2026-11-12: orders placed from the customer app never reached the restaurant. The backend answered `POST /orders` with 400 (the running process was older than the `backend-order-item-toppings` change and rejected the new optional item fields; restarting the backend fixes that part). The real defect is that nobody was told.

`OrderApiClient.placeOrder` and `updateStatus` never look at `response.statusCode`. They `jsonDecode` the body even on 400/409/500. The backend's 400 body is plain text, so this throws a `FormatException` into a future nobody awaits. Only `fetchMenu` and `fetchToppings` check the status today. This card fixes the shared half; the two UI cards use it.

## Sources

`lib/shared/api/order_api_client.dart` (`placeOrder`, `updateStatus`, and `fetchMenu` as the style example), `lib/shared/api/order_repository.dart` (`_api` field, `placeOrder`, `updateStatus`, `setOrdersForTest`), `test/menu_client_test.dart` (how `MockClient` is used), `.claude/memories/catch-type-selection.md`, `CLAUDE.md` "Backend" table (read only: the contract does not change).

## Goal

1. A small typed error `OrderRequestException` in `order_api_client.dart` with a `statusCode` (nullable: null means no HTTP answer) and a short developer message. UI code never shows that message to the customer.
2. `placeOrder` and `updateStatus` return the parsed order only on 2xx with a valid order body. Otherwise they throw `OrderRequestException`:
   - non-2xx status (400, 404, 409, 500 ...): `statusCode` set;
   - the request could not be sent or the connection failed (`http.ClientException`): `statusCode` null;
   - a 2xx whose body is not a valid order (`FormatException` / `TypeError`): `statusCode` set to the 2xx status.
   So UI code needs to catch only one type.
3. `OrderRepository.placeOrder` and `updateStatus` keep awaiting and merging on success, and let the exception propagate (no catch there). Behaviour on success is unchanged.
4. Test seam (shared-scope change, stated on purpose): make `_api` replaceable with a `@visibleForTesting` method, in the same style as the existing `setOrdersForTest`, so widget tests can give the repository an `OrderApiClient(client: MockClient(...))`. Smallest form: drop `final` on `_api` and add a method that assigns it. No new class, no interface, no dependency (`package:http/testing` ships with `http`).
5. 409 (id already exists) is not special-cased: it is one more non-2xx failure. Ids are millisecond timestamps, so a clash is practically impossible.

## Non-goals

No backend or `CLAUDE.md` change (the contract is unchanged). No retry or queueing. No UI. No change to `fetchOrders`, `streamUpdates`, `fetchMenu`, `fetchToppings`. No new package.

## Tests written with the change

In a new `test/order_calls_test.dart` (or next to `menu_client_test.dart`), using `MockClient`:
- `placeOrder`: 200 with a valid order returns it; 400 with a plain-text body, 409, 500, a thrown `http.ClientException`, and a 200 with garbage body each throw `OrderRequestException` with the expected `statusCode` (null for the network case).
- `updateStatus`: 200, 404 and a network error.
- Repository: with the seam set to a failing client, `placeOrder` throws and the cached `orders` is unchanged; with a succeeding client it merges the order.
- All existing tests still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Non-2xx, network error and bad 2xx body all throw `OrderRequestException` | `make test` |
| Success path unchanged; failed call leaves the cache untouched | `make test` |
| Only `lib/shared/` (and tests) touched; no new dependency | `make boundaries`, `git diff` of `pubspec.yaml` empty (review) |
| `make check` green | `make check` exit 0 (gate) |
| Security: no response body or server text leaks into UI-visible messages; no broader catch than needed | `security-reviewer` (required: HTTP response handling and JSON parsing) |

## Environment limits

Agents cannot run the backend against the browser. Unit tests with `MockClient` cover the client; the end-to-end check is in `customer-cart-place-order-shows-failure`.

## Notes for later cards

`comments-shared` documents these two files; running it after this card avoids a redo of the comments.
