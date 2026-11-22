---
task: currency-vnd-display
status: passed
p0: 0
p1: 0
---

# Execute review — currency-vnd-display

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-11. No security review: display formatting only (no parsing, endpoints or dependencies). Owner decision applied: CUR1/VI3 = VND, written "VNĐ" as the owner writes it.

## Implementation notes

- **New `lib/shared/money.dart`:** `formatVnd(num)`.
  - Rounds to whole đồng and puts a `.` between thousands.
  - Adds a `-` for negatives, and the ` VNĐ` suffix.
  - Non-finite input gives `— VNĐ`, a safety net so the UI can't crash.
- **All 6 price sites now use it:**
  - cart: "… each" and "Total: …";
  - the "Your orders" banner;
  - the menu tile;
  - the restaurant line subtotal and order total.
- **`CLAUDE.md`:**
  - a "Prices:" paragraph (VND, whole numbers, always through `formatVnd`);
  - a Layout line for `money.dart`.

## Gates

| Command | Exit |
|---|---|
| `make analyze` | 0 |
| `make test` (65 = 51 + 14 new) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make backend-analyze` | 0 |
| `make backend-test` (91) | 0 |
| `make check` (final candidate) | **0** |

**The "no `$` left" search.** The reviewer asked for a narrower pattern, so it was re-recorded:
- `grep -rnE "toStringAsFixed" lib` finds nothing;
- `grep -rnF "'\$" lib` (a literal dollar sign at the start of a Dart string) finds nothing;
- there are 6 `formatVnd(` call sites outside `money.dart`.

The first search, `\\\$`, matched an escaped `\$` only, which is how Dart writes a literal dollar sign, so it was also correct. The narrower patterns just remove any doubt.

## Tests

- **`test/money_test.dart`:** 0, 500, 4.000, 25.000, 125.000 and 1.250.000; a double input; rounding (9999.6 → 10.000, 9999.4 → 9.999); a negative; no `$` or comma; non-finite input.
- **`test/cart_page_test.dart` (new):** 2 × Xôi thịt and 1 × Trà đá show "25.000 VNĐ each", "4.000 VNĐ each" and "Total: 54.000 VNĐ", with no `$`.
- **`test/menu_page_test.dart`:** the fixtures now use VND, and the test expects "25.000 VNĐ" and "4.000 VNĐ" with no `$`. A new test puts `1.250.000 VNĐ` on a 360 px screen at text ×2.0 and checks for no overflow.

**Deviation from the card:** no widget test for the restaurant order page or the customer "Your orders" banner. Both read `OrderRepository.instance`, which tests can't fill without a network call, and adding a test-only hook to it was out of scope. Both sites call the unit-tested `formatVnd`. The reviewer judged this acceptable on condition that a follow-up adds a seam, and that follow-up is carried to `restaurant-orders-show-toppings`.

## Findings: P0 0 · P1 0 · P2 2 (both carried)

- **P2-1** `lib/restaurant/pages/orders_page.dart:168`: the order-line name `Text` isn't `Expanded`, so a long name plus a long VND subtotal could overflow at narrow widths. The row itself was already like this before the card, but the longer price strings raise the risk. **Carried** to `restaurant-orders-show-toppings`, which reworks that row: `Expanded` plus ellipsis, and a 360 px test.
- **P2-2:** the test gap above. **Carried** to the same card: an `OrdersPage` repository seam, plus the restaurant VNĐ test.

**Checked with no issues found:**
- **Formatter:** grouping traced (100, 1.000, 999.999, 1.000.000); rounding rounds a half away from zero; negative zero prints `0`; non-finite input is guarded before rounding.
- **VNĐ** is used consistently everywhere; there's no ₫.

## Unverified (owner acceptance)

Menu, cart and restaurant showing VNĐ correctly in the browser and on an iPhone. This needs the web apps restarted to pick up the change.
