---
executor: task-executor
scopes: [shared, restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [backend-menu-staff-write-endpoint, customer-menu-client-and-state, shared-order-and-menu-models-toppings]
securityReview: required
---

# Flutter side of the contract: `available` on MenuItem and a staff menu client

No visible UI change in this card.

**Revised 2026-11-10:** also blocked by `shared-order-and-menu-models-toppings`, which already added `category` to `MenuItem` (same file, so they must not run in parallel). `available` is added next to it; keep `category` and its tests intact.

## Why

Invariant 3: after the table and the backend, the client. Two pieces: the shared model learns `available` (both apps need it: customer disables sold-out items, restaurant shows the switch), and the restaurant gets a way to call `PATCH /api/menu/{id}` with the staff token.

## Sources

`lib/shared/models/menu_item.dart` and `fromJson` / `==` (now with `category`), `lib/shared/api/order_api_client.dart` (`fetchMenu`), `CLAUDE.md` table as updated by the backend cards.

## Goal

1. `MenuItem` gets `final bool available` (constructor default `true`, so existing const items and tests keep compiling). `fromJson` reads `available` as a bool; a missing field means `true` (old backend); a present non-bool value throws the same clear parse error as other bad types. Equality stays by `id` (a refreshed item with a changed price is still the same cart line; the cart keeps whatever price it had, see MENU-EDIT5 in the backend write card).
2. A small restaurant-only client, for example `lib/restaurant/api/menu_admin_client.dart` (restaurant only, so not in `lib/shared/`, invariant 2): `Future<MenuItem> updateItem(String id, {double? price, bool? available})`, constructor takes an optional `http.Client` and the token comes in as an argument per call (the client does not store it). Sends `PATCH /api/menu/{id}` with `Content-Type: application/json` and `X-Staff-Token`. Typed errors: wrong/missing token (401), editing disabled (403), not found (404), invalid (400), other. It must not print or log the token. Refuses (throws) before sending if neither field is given.
3. Shared reads: `fetchMenu` (existing) now returns `available` through `fromJson`; nothing else changes.

Trade-off, plainly: putting the write calls in `OrderApiClient` would be fewer files, but customers would carry code they never use and the shared folder would hold staff-only logic. A separate small restaurant class keeps the boundary clean at the cost of one file.

## Non-goals

UI, token entry screen, the state notifier, any customer change, storing the token anywhere (no `localStorage`, no cookie).

## Tests written with the change

In `test/` using `MockClient` (already-used `http` package):
- `MenuItem.fromJson`: `available` true/false, missing -> true, string/number/null -> clear error; equality still by id; default constructor `available == true`; `category` tests still pass;
- `updateItem`: sends PATCH to the right URL with the JSON body containing only the given fields and the token header; returns the parsed item; maps 400/401/403/404/500 to the typed errors; bad JSON in a 200 reply throws; calling with no fields throws without a request; the token string never appears in a thrown error's message.
- Existing client/state/cart tests pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Parsing and client behave as listed | `make test` (gate) |
| Restaurant-only code stays out of `shared/`, no boundary violation | `make boundaries` (gate) |
| Analyzer clean, no new dependency | `make analyze` (gate) + empty `pubspec.yaml` diff (code-reviewer) |
| Token handling and malformed-reply handling | `security-reviewer` (review; JSON parsing + credentials) |
| `make check` green | `make check` exit 0 (gate) |

## Environment limits

None; no browser step.

## Executor notes (2026-11-17)

- **`MenuItem.available`:** the constructor default is `true`. In `fromJson`, a missing key means `true`; a present non-bool (including `null`) throws `FormatException('menu item available must be true or false')`. Equality is still by id.
- **Client:** `lib/restaurant/api/menu_admin_client.dart`, `MenuAdminClient.updateItem(id, {required String token, double? price, bool? available})`.
  - The token is a named argument on every call and is never stored.
  - The URL is `Uri(path: '/api/menu/${Uri.encodeComponent(id)}')`.
  - The body holds only the given fields.
  - No fields → `ArgumentError` before anything is sent.
- **Failures:** `MenuAdminException` with `MenuAdminFailure`:
  - 400 → `invalid`;
  - 401 → `wrongToken`;
  - 403 → `editingDisabled`;
  - 404 → `notFound`;
  - other status, network error or unreadable 200 reply → `other`.
  - The message is fixed text plus the status. It never includes the token or the server's reply.
- **Not used yet:** nothing in the app calls the client yet; `restaurant-menu-editing-page` will. No dependency added.
