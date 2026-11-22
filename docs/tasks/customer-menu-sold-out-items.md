---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [menu-item-available-and-staff-client, customer-menu-page-uses-backend-menu, vi-translate-customer-ui, customer-menu-topping-and-drink-sheet]
---

# Customer menu: show sold-out items as unavailable

Small new card on purpose: the just-revised customer menu cards stay untouched. It runs after them, after the customer Vietnamese translation, and **after the toppings/drink dialog** (revised 2026-11-11: the blocking card is now a small add-a-food dialog, TOP5; slug unchanged; that card rewrites the same grid, so this one adapts to it instead of conflicting). New text is written in Vietnamese directly (decision VI1/VI2).

## Why

A sold-out switch is useless if customers can still tap Add. This is the cross-app half of M1.

## Sources

`lib/customer/pages/menu_page.dart` (grid with category sections and the add-a-food dialogs, as left by the earlier cards), `lib/customer/state/menu_state.dart`, `lib/shared/models/menu_item.dart` (`available`), `lib/customer/state/cart.dart`.

## Decisions (owner), with recommendations

- M5 (how fast must customers see a menu change?). Recommended: **next time the menu is loaded (page reload / app start)**, which is what the menu cards already do. Reason: menu edits are rare (a few a day), a customer's visit is minutes, and a live push needs a new SSE event type (contract change, reconnect handling, more tests, a second stream) for little gain. Alternative: live push (a `menu` event on the SSE stream, or refetching when the tab regains focus). Not built; if the owner wants it, write it as its own contract-first card. A cheap middle option, not carded: reload the menu whenever the customer returns to the menu page from the cart.
- MENU-EDIT6 item already in the cart when it becomes sold-out. Recommended: leave it in the cart and let the order go through. The server cannot refuse it until item ids exist on orders (MENU-DB3); the restaurant sees the order and can cancel it. The page only stops new adds.
- Drinks offered in the drink dialog: a sold-out drink is shown as unavailable and cannot be selected (same rule as in the grid).

## Goal

1. In `MenuPage`, an item with `available == false` shows a clear "sold out" label (Vietnamese wording drafted by the agent, accepted by the owner), the Add button does not open the add-a-food dialog / does not add (foods and drinks alike), and the card looks dimmed. In the drink dialog, sold-out drinks are listed disabled (or hidden; executor picks the clearer, notes it). Available items behave exactly as before. Item order unchanged.
2. Nothing else changes: no new state class, no polling, no change to `Cart`.

## Non-goals

Live refresh, hiding sold-out items entirely, blocking checkout, server enforcement (MENU-DB3), restaurant UI, any `shared/` change, sold-out toppings.

## Tests written with the change

Widget test in `test/` (pumps `MenuPage(state: fakeState)` as in the page card): a sold-out food shows the label and tapping Add opens no dialog and changes nothing; a sold-out drink in the grid is not addable; a sold-out drink in the drink dialog cannot be chosen; an available item still works; a list with a mix renders both; the existing menu page and dialog tests still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Sold-out item labelled and not addable; others unchanged | `make test` (widget test) |
| Boundaries and analyzer clean | `make boundaries`, `make analyze` (gates) |
| `make check` green | `make check` exit 0 (gate) |
| Wording acceptable, dimmed look readable | owner acceptance in the browser at `http://customer.local` - "unverified" until done |
| Mark an item sold out (curl with the staff ID and password, or the restaurant UI) -> reload customer page -> item shows sold out | owner acceptance in the real environment |
| Same on iPhone Safari | owner acceptance on the phone - optional |

## Environment limits

Agents cannot judge wording or see the browser; the owner runs the end-to-end check.

## Note added 2026-11-17: tile redesign (UI refresh)

The tile is restyled by `customer-menu-tile-redesign`: the text "Add" button becomes a round dark-red "+" (`_AddButton`, tooltip "Add <name>", at least 48 px tap target) and the description line is gone. The "+" already supports a disabled state (`onPressed: null`, greyed circle, tooltip kept). So this card, when it runs, should: pass `null` for a sold-out item, put the "sold out" label where the description used to be or over the photo (not as a new tile row, to keep the fixed tile height), find the button in tests by `find.byTooltip('Add <name>')` instead of `widgetWithText(FilledButton, 'Add')`, and re-check the fit at 360 px and text scale 1.3/2.0. The category tabs (icon tiles) and the bottom cart bar are also changed by `customer-menu-category-icon-tabs` and `customer-bottom-nav-cart-button`. Recommended order: all three of those first, then this card. Add `customer-menu-tile-redesign` to `blockedBy` when this card is scheduled (it is not added now, so the owner can still choose).
