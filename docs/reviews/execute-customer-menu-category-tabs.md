---
task: customer-menu-category-tabs
status: passed
p0: 0
p1: 0
---

# Review: customer-menu-category-tabs

Independent reviewer: `code-reviewer` (read-only). No security review: plain UI, no endpoint, parsing, network or permission change (card has no `securityReview`).

## Round 1 (2026-11-11): changes requested. P0 0, P1 1, P2 2

- **P1, missing required test:** no widget test for the "Your orders" banner on two tabs and absent without an active order. Cause: `OrderRepository` had no way to seed orders without the network.
- **P2, scroll position:** `TabBarView` pages had no keep-alive or page storage, so each tab went back to the top when revisited.
- **P2, wide screens:** with `isScrollable: true` and `TabAlignment.start`, the tabs sit on the left on a laptop. Owner to confirm.

Checked and correct in round 1: labels and order, category filtering in server order, empty message wording, start tab, nothing seeded into Ăn vặt, banner as first sliver of each tab, listeners and disposal, selected tab kept across the cart page and loading/error states, `isScrollable` choice.

## Owner decisions (2026-11-12)

Add the banner test (scope widened to test-only seams in `OrderRepository` and `MyOrders`, owner approved); keep each tab's scroll position; keep tabs left-aligned. Recorded in the card.

## Fix round 1

- `lib/shared/api/order_repository.dart`: `@visibleForTesting setOrdersForTest(List<Order>)`.
- `lib/customer/state/my_orders.dart`: `@visibleForTesting clearForTest()`.
- `lib/customer/pages/menu_page.dart`: `PageStorageKey('menu-tab-<category>')` on each tab.
- `test/menu_page_test.dart`: shared state reset in `setUp`/`tearDown`; banner tests (shown on Đồ ăn and Đồ uống; absent for a delivered tracked order plus an untracked pending one); scroll-position test. The scroll test was confirmed to fail with a `ValueKey` instead (Expected 600, Actual 0.0), then the fix was restored.

## Re-review 1 (2026-11-12): passed. P0 0, P1 0, P2 0

All three findings resolved. The seams are called only from tests (grep over `lib/`), and `@visibleForTesting` makes `--fatal-infos` flag any misuse. Singleton state is reset around every test and can't cross test files (separate isolates).

## Gates (fix round 1, this session)

| Command | Exit code |
|---|---|
| `make analyze` | 0 |
| `make test` (152 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make check` (final candidate; 152 app + 170 backend tests) | 0 |

## Unverified (owner acceptance)

The look and tab switching at `http://customer.local`; Ăn vặt empty message, then an item after a `sqlite3` INSERT and reload; iPhone Safari (readable labels, swipe, no clipping); Vietnamese diacritics rendering.
