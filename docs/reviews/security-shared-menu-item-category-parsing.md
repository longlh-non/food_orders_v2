---
task: shared-menu-item-category-parsing
status: passed
p0: 0
p1: 0
reviewedFiles:
  - lib/shared/models/menu_item.dart
  - test/menu_item_test.dart
---

# Security review — shared-menu-item-category-parsing

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-11.

## Scope

**Input:** the `GET /menu` body, which an attacker can influence: a hand-edited database row, or a man-in-the-middle on the LAN (plain HTTP). It passes through `jsonDecode`, then `MenuItem.fromJson`, then the UI. This card adds `category` and `allowToppings`.

## Checked with no issues found

- **Wrong types:** a list, map, number, null or bool as `category` never matches and throws a `FormatException`. Matching is exact, so case and whitespace tricks fail. `allowToppings` must be a real bool: `"true"` and `1` are rejected.
- **Missing keys:** handled with `containsKey`.
- **No crash path:** every failure is a `FormatException`, which `MenuState` catches at the UI boundary. The page shows the constant "Couldn't load the menu" plus Retry, and a test asserts that the raw error body isn't shown.
- **Nothing new is reflected** back to the user: the new fields are an enum and a bool.

## Findings: P0 0 · P1 0 · P2 2

- **P2-1:** `allowToppings` trusted a server `true` on snack, drink or nibble. **Fixed:** it's now forced false unless the item is food, with tests.
- **P2-2: one bad row blanks the whole menu.** The strict rule (TAB4) means a single mis-edited database row stops the menu loading for every customer until it's fixed. **Accepted** as a trade-off: the database CHECK already blocks bad categories at the source, and the failure is a generic error with Retry, not a crash. An attacker able to alter the response could return an error anyway, so this adds no new capability. **For the owner:** if the customer menu suddenly shows "Couldn't load the menu", check your latest `sqlite3` edit first.

## Re-review 1

**Still passed.** P2-1 is fixed, and P2-2 is accepted. No new findings. **Counts:** P0 0 · P1 0 · P2 0 open.
