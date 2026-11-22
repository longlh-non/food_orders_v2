---
task: restaurant-orders-show-toppings
status: passed
p0: 0
p1: 0
---

# Review: restaurant-orders-show-toppings

Independent reviewer: `code-reviewer` (read-only). No security review: restaurant UI only, with no endpoint, parsing, network, dependency or permission change. The card has no `securityReview`.

The owner invoked the card as `docs/tasks/restaurent-orders-show-toppings.md`. That path doesn't exist, so the existing card `docs/tasks/restaurant-orders-show-toppings.md` ran.

## Candidate

- `lib/restaurant/pages/orders_page.dart` (only the item-line `Row` in `_OrderCard` changed):
  - The name, plus an optional toppings line (`+ A, + B`), sit in an `Expanded` `Column` and wrap.
  - Then `SizedBox(width: 8)` and `formatVnd(item.subtotal)`, which includes the toppings.
- `test/orders_page_test.dart` (new), 5 widget tests:
  - toppings appear only on the item that has them;
  - the subtotal is (25.000 + 10.000 + 8.000) × 2 = 86.000 and the total is 90.000 VNĐ, with no `$`;
  - an order without toppings renders as before;
  - a long name, 4 toppings and a 1.750.000 VNĐ price fit at 360 px at text scale 1.0 and 1.3.
  - The fit test fails when the `Expanded` is replaced with a `SizedBox`, so it isn't vacuous.

Executor choices, accepted by the reviewer and recorded in the card:
1. **Test seam:** the tests use the existing `OrderRepository.setOrdersForTest` instead of a new `OrdersPage(repository:)` parameter, so `lib/shared/` doesn't change.
2. **Wrap, not ellipsis:** this overrides the card's layout note, because the kitchen needs the whole text.
3. **Text scale:** the fit test runs at scale 1.0 and 1.3 only. See the follow-ups.

## Round 1: passed. P0 0, P1 0, P2 3

Checked and correct:
- the toppings line and subtotal match the card's Goal;
- the chime, badge, SnackBar and status buttons are unchanged;
- the diff stays restaurant-scoped and boundaries are clean;
- tests are isolated (reset in `setUp`/`tearDown`; orders are seeded before the pump, so no chime or SnackBar path runs);
- every item on the card's test list is covered.

## Deferred follow-ups (P2)

1. **Price at text scale 2.0 (`orders_page.dart`, the price `Text`):** the price is non-flex.
   - With the test font (every glyph 1 em wide), "1.750.000 VNĐ" at 2× is about 364 px, wider than a 360 px card's content, so it overflows. With real fonts it's about 200 px and fits.
   - Cheap fix if staff use very large text: make the price `Flexible` with `textAlign: TextAlign.end`, and test at 2.0.
2. **Test comment pointer:** `test/orders_page_test.dart` refers to "the review" for item 1. That's this section.
3. **Notification test gap (not required by the card):** no test proves a genuinely new pending order still fires the "New order from …" SnackBar and bumps the badge.
   - The logic is unchanged, so the risk is low.
   - A later card can add one: call `setOrdersForTest` with an extra pending order after the pump.

## Gates (final candidate, this session)

| Command | Exit code |
|---|---|
| `make analyze` | 0 |
| `make test` (181 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `git diff --stat pubspec.yaml` (empty: no new dependency) | 0 |
| `make check` (181 app + 170 backend tests) | 0 |

## Unverified (owner acceptance)

- **Live flow:** place an order with toppings on `http://customer.local` and see it live on `http://restaurant.local` with its toppings. An old order without toppings should still render.
- **Staff device:** readable on the tablet or phone staff will use (optional).
