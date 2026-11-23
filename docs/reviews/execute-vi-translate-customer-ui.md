---
task: vi-translate-customer-ui
status: passed
p0: 0
p1: 0
---

# Review: vi-translate-customer-ui

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | 552 tests |
| `make backend-analyze` | 0 | (executor run) |
| `make backend-test` | 0 | (executor run) |
| `make analyze` / `make check` | 2 | 19 pre-existing `deprecated_member_use` infos (`material_ui` SDK issue); none in this card's changes. format-check and boundaries, the steps before it, pass |

## Changed paths

`lib/customer/pages/menu_page.dart`, `cart_page.dart`, `add_food_dialog.dart`; `test/widget_test.dart`, `menu_page_test.dart`, `cart_page_test.dart`, `cart_lines_test.dart`, `add_food_dialog_test.dart`. Hardcoded Vietnamese, no package, no logic change (reviewer confirmed every `lib/` hunk is a string literal or comment).

## Findings (code-reviewer): P0 0, P1 0, P2 2

1. Stale English quotes in doc comments (`add_food_dialog.dart:27,33`, `menu_page.dart:20,23,355,591`, `cart_page.dart:130`, `state/my_orders.dart:4`). Deferred: covered by the pending `comments-customer` card.
2. Gate wording: `make check` exit 2 comes from the pre-existing analyze infos (see table), not from this change.

Notes: `ensureVisible` added to one cart test is a legitimate test-scroll fix (the overflow and on-screen assertions still stand). "Menu" → "Thực đơn" while the payment page's "Về menu" button still says "menu": owner may align. No test pins the empty-tab message (predates this card).

## Unverified (owner acceptance)

Wording, diacritics and layout in a real browser at `http://customer.local` and on iPhone Safari.

## Verdict

**Passed**, P0: 0, P1: 0.
