---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-menu-category-and-toppings]
securityReview: required
---

# Order contract: an order item may carry chosen toppings

Contract-first (invariant 3 and 4): `CLAUDE.md` Order rules, then backend validation. The Flutter models follow in `shared-order-and-menu-models-toppings`. No schema change: items are stored as JSON text in `items_json`.

## Why

A customer who picks "Burger + bacon + extra cheese" must be able to send that to the kitchen. Today an item is exactly `{name, quantity, price}`, so there is no place for toppings.

## Sources

`backend/lib/orders_api.dart` (`_orderProblem`, `_itemFields`, `_orderFromRow`), `backend/test/orders_api_test.dart`, `lib/shared/models/order.dart` (`Order.toJson()` is the contract shape, invariant 4), `CLAUDE.md` "Order rules".

## Design (plain words)

- An item gets two new **optional** fields:
  - `id`: the menu item's id, as a non-empty string.
  - `toppings`: a list of `{id, name: string, price: number}`, where the topping's `id` is likewise optional and a non-empty string when present. Absent or `[]` means no toppings.
- `price` on the item stays the **base unit price of the dish, without toppings**. The cost of one unit is `price + sum(topping prices)`; the line is that times `quantity`. Reason: the kitchen and the customer can see what each part cost, and nothing old changes meaning.
- A plain item is sent exactly as today (the client omits `toppings` when empty). So an old cached web build still works against the new backend, and old orders already stored (no `toppings`) read back unchanged. Nothing is rewritten in the database.
- The drink is just another item line; it needs no special field.
- **Ids now, price check later (TOP3, decided by the owner 2026-11-10).**
  - Items and toppings carry the menu `id`, so the later server-side price check (MENU-DB3) is a backend-only change: look the ids up in the tables, then price or reject.
  - The ids are **optional** in this card, because this backend card runs before the app card that starts sending them. Requiring them now would reject every order until `shared-order-and-menu-models-toppings` lands. MENU-DB3 makes them required.
  - This card does **not** check that an id exists in `menu_items` or `toppings`; that's MENU-DB3.
  - **The server still trusts client prices** until MENU-DB3. Toppings add one more field with the same weakness, not a new kind of hole.

## Goal

1. `CLAUDE.md` "Order rules" (owner approval for the edit is requested by this card): an item is `{name, quantity, price}` plus optional `id` (non-empty string) and an optional `toppings` list of `{name: string, price: number}` objects with an optional `id` (non-empty string). Same price rule: finite, at least 0. At most 10 toppings per item. Say the ids become required with MENU-DB3. State that `price` is the base price and how a line total is computed. Add "Known limitations": prices are trusted from the client until MENU-DB3.
2. `orders_api.dart`: item keys must be `name`, `quantity` and `price`, plus optionally `id` and/or `toppings`. Topping keys must be `name` and `price`, plus optionally `id`. Validate as above; any other key or shape -> 400 with a fixed message (no echo). Stored and returned as sent (round-trips through `items_json`).
3. No limit on name length is added here (items have none today; length caps belong to `backend-request-body-limit`, whose card already tracks this). The 10-per-item cap is the only new bound.

## Non-goals

Requiring ids or checking they exist (MENU-DB3), server-side pricing (MENU-DB3), any schema step, Flutter changes, restaurant display.

## Tests written with the change

In `backend/test/orders_api_test.dart`:
- order with an item with `toppings: [{name, price}]` -> 200, echoed, and `GET /orders` returns the same toppings; `toppings: []` and absent both accepted;
- items and toppings with an `id` are accepted, echoed and stored; items without one are still accepted;
- an order stored in the old shape (inserted directly with `items_json` without toppings) still reads back identically (backwards compatibility);
- 400 for: `toppings` not a list, null, an element that is a string, extra key in a topping (e.g. `note`), missing `name` or `price`, an item or topping `id` that is empty or not a string, `price` negative / string / `1e999`, 11 toppings; an unknown extra key on the item;
- after any 400 the store is unchanged; existing order, SSE and status tests pass; error bodies do not contain request text.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Valid shapes accepted, all invalid shapes rejected, store unchanged on 4xx | `make backend-test` (gate) |
| Old-shape stored orders still readable | `make backend-test` (gate) |
| Backend clean | `make backend-analyze` (gate) |
| Exact-shape validation, finite prices, bounded list, no echo | `security-reviewer` (review; endpoint + JSON parsing trigger) |
| `CLAUDE.md` Order rules match code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |

## Environment limits

None beyond `make`; no browser step.

## Note 2026-11-11: dishes with "no toppings" (TOP2c)

Some dishes will have `allow_toppings = 0`. This card does **not** reject toppings on such a dish, because that needs the menu lookup by item `id`, which is MENU-DB3. The customer app won't offer toppings for those dishes, but a hand-made request could still send them. Add "reject toppings on a dish with `allow_toppings = 0`" to the MENU-DB3 card when it's written.

## Added by `backend-menu-category-and-toppings` security review (2026-11-10, P2-3)

For MENU-DB3: with toppings, the client computes totals that include topping prices, which the server can't verify. The 5 `an-nhe-*` snacks also duplicate topping prices, so the two can drift apart. MENU-DB3 must recompute every price from `menu_items` and `toppings` by id, and reject unknown ids.
