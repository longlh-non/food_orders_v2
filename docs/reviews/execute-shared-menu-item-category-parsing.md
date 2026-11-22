---
task: shared-menu-item-category-parsing
status: passed
p0: 0
p1: 0
---

# Execute review — shared-menu-item-category-parsing

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-11. It ran in parallel with `security-reviewer`, and neither saw the other's conclusions. Security report: `docs/reviews/security-shared-menu-item-category-parsing.md`. Owner decision applied: TAB4 is strict (an unknown category fails the menu load).

## Implementation notes

- **New enum `MenuCategory { food, snack, drink, nibble }`,** with each value's Vietnamese tab name in its doc comment.
- **`MenuItem` gains `category` (default food) and `allowToppings` (default true).** The `const` constructor stays compatible.
- **`fromJson`, category:**
  - A missing key means food (an older backend).
  - A present value must exactly match one of the four names; anything else is a `FormatException` (`null`, `''`, `7`, `"cake"`, `"FOOD"`).
- **`fromJson`, allowToppings:**
  - A missing key gives `category == food`.
  - A present value must be a bool.
  - **After the review fix,** a present bool becomes `raw && category == food`, so a non-food item never offers toppings, whatever the server says.
- **Equality** is still by id.
- **No UI change, no dependency.**

## Gates

| Command | Exit |
|---|---|
| `make analyze` | 0 |
| `make test` (88 = 65 + 23 new) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make backend-analyze` | 0 |
| `make backend-test` (107) | 0 |

## Findings (first pass): P0 0 · P1 0 · P2 2

- **P2-1** `menu_item.dart:30`: the doc said `allowToppings` is "only ever true for food", but nothing enforced it. Raised independently by both reviewers. **Fixed:** `fromJson` forces false for non-food. New tests check that a server `true` for snack, drink and nibble each parses as false. Left alone: the const constructor default, which only tests use directly; the doc now scopes the guarantee to `fromJson`. The reviewer agreed.
- **P2-2:** "the `CLAUDE.md` Layout still lists `data/sample_menu.dart`". **Stale note:** `grep` finds no such line, because it was removed by `customer-menu-page-uses-backend-menu`. The reviewer confirmed.

## Re-review 1

| Command | Exit |
|---|---|
| `make analyze` | 0 |
| `make test` (91) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make check` (final candidate) | **0** (91 app tests, 107 backend tests) |

**Result:** both findings are resolved, with no new ones. **P0 0 · P1 0 · P2 0.**
