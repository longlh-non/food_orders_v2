---
executor: task-executor
scopes: [shared]
workKinds: [flutter, quality-gate]
blockedBy: [backend-menu-category-nibble]
securityReview: required
---

# `MenuItem` reads `category` and `allowToppings` (small slice, so the tabs don't wait for toppings)

No visible UI change. Invariant 3: the backend first, then the model. Split out of `shared-order-and-menu-models-toppings` (2026-11-11) because the category tabs only need these two fields, while the rest of that card (Topping, order-item toppings, `fetchToppings`) waits for `backend-order-item-toppings`.

## Why

`GET /menu` already returns `category` and `allowToppings`, but `lib/shared/models/menu_item.dart` ignores them, so the customer grid cannot split items into tabs.

## Sources

`lib/shared/models/menu_item.dart`, `backend/lib/menu_api.dart` (what the server sends), `backend/lib/database.dart` step 4 from `backend-menu-category-nibble`, `test/menu_client_test.dart`, `CLAUDE.md` "Backend" table.

## Goal

1. `enum MenuCategory { food, snack, drink, nibble }` in `menu_item.dart` (`snack` = "Ăn nhẹ", `nibble` = "Ăn vặt"). The enum order is not the tab order; the UI card decides tab order.
2. `MenuItem` gets `final MenuCategory category`. Constructor default `food` so existing `const MenuItem(...)` calls and tests keep compiling. `fromJson`: key missing -> `food` (old backend); a present value that is not one of the four strings (a number, null, `"cake"`) -> `FormatException` naming the field, like the other fields. Equality stays by id.
3. `MenuItem` gets `final bool allowToppings`. Constructor default `true`. `fromJson`: missing -> `true` for `food` and `false` for the others; present but not a bool -> `FormatException`.
4. Unknown category decision (TAB4, recommended: **strict**): the menu fails to load with the generic "Couldn't load the menu" + Retry, like any other bad field. Why: the database CHECK makes an unknown value impossible today, and a silent fallback would show a mystery item in the wrong tab (as food it would even offer toppings), while hiding would drop an item without anyone noticing. A loud failure is found immediately. If the owner prefers leniency, change goal 2 to "unknown -> food + `debugPrint`".

## Non-goals

`Topping`, `OrderItem` changes, `fetchToppings`, any UI, restaurant changes, `image`/`available` (their own cards).

## Tests written with the change

In `test/menu_client_test.dart` (or a new `test/menu_item_test.dart`; executor picks):
- `category`: each of `food`, `snack`, `drink`, `nibble` parses; missing -> `food`; `"cake"`, `""`, `7`, `null` -> error;
- `allowToppings`: `true`, `false`, missing (food -> `true`; snack, drink, nibble -> `false`), `"yes"`/`1`/`null` -> error;
- equality by id unchanged; a whole `GET /menu` mock reply (food + snack + drink + nibble) parses through `fetchMenu` and keeps order; existing tests pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Parsing behaves as listed, old JSON (no category) still parses | `make test` (gate) |
| `shared/` imports neither app | `make boundaries` (gate) |
| Analyzer and format clean, no new dependency | `make analyze`, `make format-check` (gates) + empty `pubspec.yaml` diff (code-reviewer) |
| Malformed-reply handling | `security-reviewer` (review; JSON parsing trigger) |
| `make check` green | `make check` exit 0 (gate) |

## Environment limits

None; no browser step.
