---
executor: task-executor
scopes: [shared]
workKinds: [flutter, quality-gate]
blockedBy: [backend-menu-category-and-toppings, backend-order-item-toppings, shared-menu-item-category-parsing]
securityReview: required
---

# Flutter side of the contract: `Topping`, order-item toppings, `fetchToppings` (category parsing moved out)

No visible UI change. Invariant 3: after the table and the backend, the models and `OrderApiClient`.

**Revised 2026-11-11 (category tabs request):** `MenuCategory`, `MenuItem.category` and `MenuItem.allowToppings` moved to the small card `shared-menu-item-category-parsing`, so the customer tabs do not have to wait for this card. This card now waits for that one and only builds on it. Nothing of this card was started.

## Why

Both apps need these types: the customer builds orders with toppings, the restaurant displays them (invariant 2: both need them today, so they live in `lib/shared/`).

## Sources

`lib/shared/models/menu_item.dart` (with category already parsed), `lib/shared/models/order.dart` (`OrderItem`, `Order.total`), `lib/shared/api/order_api_client.dart` (`fetchMenu`), the two backend cards, `CLAUDE.md`.

## Goal

1. (Moved out: category and `allowToppings` on `MenuItem` are done by `shared-menu-item-category-parsing`.)
2. New shared `Topping {id, name, price}` with `fromJson` validated like `MenuItem` (non-empty id, string name, finite price >= 0), equal by id. New small `OrderTopping {id, name, price}` used inside `OrderItem`. `id` is the topping's menu id, nullable only so old stored orders still parse.
3. `OrderItem` gets `final String? menuItemId` (JSON key `id`) and `final List<OrderTopping> toppings` (default empty).
   - `menuItemId` is nullable only so old stored orders without ids still parse. New orders built by the app always set it (TOP3, owner 2026-11-10).
   - `toJson` writes `id` when it isn't null. `toJson` omits `toppings` when empty (so a plain item is byte-for-byte what it is today); `fromJson` treats missing as empty and rejects wrong types with a clear error. `subtotal` = `(price + toppings sum) * quantity`; `Order.total` follows.
4. `OrderApiClient.fetchToppings()` -> `List<Topping>` (same error handling and parse style as `fetchMenu`; reject duplicate ids).

## Non-goals

State classes, UI, restaurant display, server pricing (MENU-DB3), category parsing (other card). Building order lines with ids from the cart is card `customer-state-cart-lines-and-toppings`.

## Tests written with the change

In `test/` with `MockClient`:
- (`MenuItem` category and `allowToppings` tests moved to `shared-menu-item-category-parsing`; existing menu tests still pass.)
- `Topping.fromJson`: valid; empty id, non-string name, negative / infinite / string price -> error;
- `OrderItem`: `toJson` omits `toppings` when empty and includes them otherwise; `id` is written when set and omitted when null, for items and toppings alike; round trip `fromJson(toJson())` keeps the ids; an old JSON without `toppings` or ids parses (ids become null); an empty or non-string `id` -> error; subtotal and `Order.total` with toppings and quantity 2; floating sums compared with a tolerance;
- `fetchToppings`: success, non-200, non-list body, bad element, duplicate ids.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Parsing and serialisation behave as listed | `make test` (gate) |
| Old JSON (no toppings) still parses | `make test` (gate) |
| `shared/` imports neither app | `make boundaries` (gate) |
| Analyzer, format clean, no new dependency | `make analyze`, `make format-check` (gates) + empty `pubspec.yaml` diff (code-reviewer) |
| Malformed-reply handling | `security-reviewer` (review; JSON parsing trigger) |
| `make check` green | `make check` exit 0 (gate) |

## Environment limits

None; no browser step.

## Added by `backend-menu-category-and-toppings` security review (2026-11-10, P2-2)

Topping names are free text the owner edits by hand, like menu names. `Topping.fromJson` must clean them the same way `MenuItem.fromJson` does: reuse `_displayText` (move it somewhere both can use), and reject a name with no visible text. Show them only in plain `Text`.
