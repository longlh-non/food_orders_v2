---
executor: task-executor
scopes: [shared, customer]
workKinds: [flutter, quality-gate]
blockedBy: [backend-menu-endpoint, format-flutter-sources]
securityReview: required
---

# Fetch the menu in the Flutter client and hold it in customer state

Includes review fixes from planning (testable client, injectable state). Menu data now comes from the database via `GET /menu`; the contract is unchanged: `{id, name, description, price}`.

## Why

The backend now serves `GET /menu` from its database. Before the page can show it, the app needs a way to fetch and parse it, and a place to keep the result. No visible UI change in this card.

## Sources

`lib/shared/api/order_api_client.dart`, `lib/shared/models/menu_item.dart`, `lib/customer/state/cart.dart` (uses `MenuItem` as a Map key), `lib/customer/state/my_orders.dart` (example of a small customer-side singleton), `lib/shared/api/order_repository.dart` (creates `OrderApiClient()`), existing tests under `test/`.

## Goal

1. `MenuItem.fromJson` (shared model; parsing must reject wrong types with a clear error rather than crash later; menu rows can be edited by hand in the database, so do not assume well-formed data).
2. Add `==` and `hashCode` to `MenuItem` based on `id`. Why: `Cart` stores `Map<MenuItem, int>`. Today items are `const` objects so identity works; items parsed from the server are new objects on every fetch, so without this the cart would treat the same burger as different items after a refresh.
3. **Testable client (review fix).** `OrderApiClient` takes an optional `http.Client` in its constructor (`OrderApiClient({http.Client? client}) : _client = client ?? http.Client()`) and its methods call `_client.get/post/patch` instead of the top-level `http.get/...`. Existing callers (`OrderRepository` uses `OrderApiClient()`) keep compiling unchanged. Behaviour of the existing methods does not change.
4. `OrderApiClient.fetchMenu()` calling `GET /api/menu` through that client. Unlike the existing methods it checks the status code: non-200 throws a clear error. Bad JSON or wrong types also throw (caught by the state below).
5. A small customer-only `ChangeNotifier` (for example `lib/customer/state/menu_state.dart`) with: the list, a loading/error state, and `load()` that can be retried (ignore a second `load()` while one is running). Customer-only, so it lives in `lib/customer/`, not `lib/shared/` (invariant 2). No repository interface, no new package (invariants 5, 6).
6. **How `MenuPage` will get its state (review fix, decided here).** `MenuState` has a shared singleton `MenuState.instance` (same style as `Cart` and `MyOrders`) and a normal constructor `MenuState(OrderApiClient api)` so tests can build one with a fake client. The next card makes `MenuPage` take an optional `MenuState? state` constructor parameter defaulting to `MenuState.instance`. This card only provides the class and the instance.

## Non-goals

No UI changes, no deletion of `sample_menu.dart` yet (next card), no caching to disk, no polling or SSE for menu changes, no change to `Order.toJson()`, no menu editing calls.

## Tests written with the change

In `test/`:
- `MenuItem.fromJson` happy path and bad types (missing field, string price, null name).
- Equality by id (same id equals, different id not, usable as Map key).
- `fetchMenu` using `OrderApiClient(client: MockClient(...))` from `package:http/testing.dart` (part of the already-used `http` package, no new dependency): success, non-200, bad JSON, wrong element type.
- Menu state with a fake client goes loading -> loaded and loading -> error, and recovers on retry; a second `load()` while loading does not start another request.
- `Cart` keeps one entry when the same menu item is added from two separately parsed copies.
- Existing tests that use the client or repository still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Parsing, client and state behave as listed | `make test` (gate) |
| `OrderApiClient()` with no argument still works for existing callers | `make test`, `make analyze` (gates) |
| Cart merges equal items | `make test` (gate) |
| No boundary violation, analyzer clean | `make boundaries`, `make analyze` (gates) |
| Handles malformed server data without crashing | `security-reviewer` (review; JSON parsing trigger) |
| `make check` green | `make check` exit 0 (gate) |

## Environment limits

None beyond the usual; nothing is user-visible yet.

## Added by `backend-menu-endpoint` reviews (2026-11-09)

- `price` comes from a `REAL` column, so the JSON normally carries a double (`12.0`). Parse with `(json['price'] as num).toDouble()` anyway, and treat any non-number as a parse error (that's the defensive parsing this card already asks for).
- `name` and `description` are free text the owner edits by hand. Show them only with plain `Text` widgets: no HTML or markdown rendering. Never put `id` into a URL or file path without encoding it.
