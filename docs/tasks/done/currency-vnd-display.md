---
executor: task-executor
scopes: [shared, customer, restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [backend-menu-category-and-toppings]
---

# Show all prices in VND (e.g. `10.000 VNĐ`) in both apps

## Why

The owner decided on 2026-11-11: **switch the app to VNĐ** (CUR1, which is also VI3 from the translation plan). The owner's real toppings and drinks are priced in VND, while every price on screen is still formatted as US dollars with 2 decimals.

## Sources

Every place that formats a price today (found with `grep`):

- `lib/customer/pages/menu_page.dart:286`: banner order total.
- `lib/customer/pages/menu_page.dart:348`: grid tile price.
- `lib/customer/pages/cart_page.dart:84`: "… each".
- `lib/customer/pages/cart_page.dart:121`: cart total.
- `lib/restaurant/pages/orders_page.dart:169`: line subtotal.
- `lib/restaurant/pages/orders_page.dart:179`: order total.

Toppings cards that land before or after this one add more price text. Search again when this card starts.

## Why it waits for `backend-menu-category-and-toppings`

Display and data must switch together. If the display flips first, today's USD prices (burger `9.5`) would show as "10 VNĐ". That card puts the owner's VND prices into the database. Per the open "food list" decision there, it should also replace or re-price the 5 USD foods. Only after it runs is every stored price in VND.

## Goal

1. **One shared formatter**, e.g. `lib/shared/money.dart` with `String formatVnd(num amount)`, used by both apps, so no screen formats prices on its own.
   - Rounds to whole đồng; VND has no decimals.
   - Thousands separator `.`, Vietnamese style.
   - Suffix ` VNĐ`.
   - Examples: `4000` → `4.000 VNĐ`, `25000` → `25.000 VNĐ`, `1250000` → `1.250.000 VNĐ`, `0` → `0 VNĐ`.
   - No new package: a few lines of Dart, not `intl`, because invariant 5 requires owner approval for new dependencies.
2. **Replace all 6 call sites above,** plus any new ones, with `formatVnd(...)`. No `$` and no `toStringAsFixed(2)` left for prices.
3. **Grid tile:** VND prices are longer strings (`125.000 VNĐ`). The tile's price is already one line that shrinks to fit, and the existing layout tests at 360 px and text ×1.3/×2.0 must still pass with the longest real price.
4. **`CLAUDE.md`:** a short "Prices are VND, whole numbers" note in Backend's order rules or Storage, and point to `formatVnd`. The owner's approval for this `CLAUDE.md` edit is requested by this card.

## Non-goals

- Changing any stored data. That's the category card or a `sqlite3` step.
- Translating labels like "Total:". That's `vi-translate-*`.
- A currency setting or multiple currencies.
- Backend price validation. It still accepts finite numbers ≥ 0, which covers whole-number VND.

## Notes

- **Old test orders:** the two orders in the owner's database were placed in USD (e.g. 9.5), so after this card they show as "10 VNĐ". They're test data. Either accept it, or delete them with `sqlite3 backend/data/orders.db "DELETE FROM orders"` (owner's choice; the agent doesn't run it).
- **Price cap:** `backend-menu-staff-write-endpoint` plans an upper price cap of 1,000,000 (MENU-EDIT3). In VND that's about 1 million đồng, probably fine for one dish, but the owner should confirm the cap when that card runs.

## Tests written with the change

- `test/money_test.dart`: the examples above, plus rounding (`9999.6` → `10.000 VNĐ`) and large values.
- Widget tests: the menu tile, the cart and the restaurant order show `… VNĐ` and never `$`. Update any existing test that expects `$9.50`, and name each one in the review.
- A grid test at 360 px, text ×2.0, with a price of `1250000`: no overflow.

## Acceptance criteria → verification

| Criterion | Verified by |
|---|---|
| Formatter output exactly as specified | `make test` (gate) |
| No `$` or 2-decimal price formatting left in `lib/` | `make analyze`, plus a `grep` the executor records in the review; `code-reviewer` (review) |
| Layout still fits on a phone with VND prices | `make test` (widget tests) |
| `make check` green | `make check` exit 0 (gate) |
| Menu, cart and restaurant all show VNĐ correctly | owner acceptance in the browser and on iPhone; "unverified" until done |
