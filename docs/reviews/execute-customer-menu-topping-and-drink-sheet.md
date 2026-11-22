---
task: customer-menu-topping-and-drink-sheet
status: passed
p0: 0
p1: 0
---

# Review: customer-menu-topping-and-drink-sheet

Independent reviewer: `code-reviewer` (read-only). No security review: customer UI only. It touches no endpoint, JSON parsing, network setting, dependency or permission. The card has no `securityReview`.

## Candidate

- `lib/customer/pages/add_food_dialog.dart` (new):
  - `showAddFoodDialog` returns an `AddFoodChoice` (toppings, optional drink), or null on any cancel or dismiss.
  - `addFoodAsks` decides whether a food asks anything.
- `lib/customer/pages/menu_page.dart`:
  - `_MenuTile` and `_TabContent` get the `MenuState`.
  - `_MenuTile._add` opens the dialog for foods only, then changes the cart after the confirm.
- `test/add_food_dialog_test.dart` (new): 24 widget tests.

Executor choices, accepted by the reviewer:
1. **One dialog:** a single `AlertDialog` whose content changes per step (ask, toppings, drink) instead of stacked dialogs. "Back" keeps the ticks, and any dismiss ends the whole flow.
2. **"Next":** a step followed by another shows "Next"; the last step shows "Add".
3. **Drink required:** the drink step's "Add" is disabled until a drink is chosen.
4. **Radio list:** `RadioGroup` + `RadioListTile`, because the old `groupValue`/`onChanged` are deprecated in Flutter 3.47.
5. **SnackBar text:** "Added <dish>" or "Added <dish> + <drink>".
6. **Toppings total:** the toppings step shows one unit's price, "<dish>: <dish + toppings>".

New text is in English, as the card's "Order change" section asks. ADD5 = no: snacks, Ăn vặt items and drinks are added directly.

## Round 1: passed. P0 0, P1 0, P2 5

- **P2-1:** `_add` returned before changing the cart when the tile was unmounted after the dialog. A confirmed add could be lost on a rare menu-reload race.
- **P2-2:** a dish plus a drink is two `Cart.add` calls, so listeners are notified twice. This is harmless today.
- **P2-3:** a test found the dialog's "Add" with `.last`, which can also match tile buttons.
- **P2-4:** the fit test didn't check for overflow at every step, nor with a topping ticked.
- **P2-5:** no test for Back from the drink step when only a drink was ticked, and none for unticking after Back.

Checked and correct:
- the step machine;
- the cart changes only on confirm, and every dismiss path returns null;
- rows are hidden or the item is added directly, as the card says;
- no listeners or controllers to dispose;
- boundaries;
- no new dependency.

## Fixes (P2-1, P2-3, P2-4, P2-5)

- **P2-1:** the cart is changed after a confirm in every case. `context.mounted` now guards only the SnackBar.
- **P2-3:** the button lookup is scoped to the dialog.
- **P2-4:** the fit test ticks a topping and calls `takeException()` after every step, including the final Add.
- **P2-5:** two new tests:
  - "Back from the drink step (no toppings ticked) goes to the start";
  - "unticking after Back drops that choice".

## Re-review 1: passed. P0 0, P1 0, P2 0 open

All four fixes resolve their findings. No new issues were found.

## Deferred follow-up

- **P2-2:** if a cart listener ever needs one notification per confirm, add a batch `Cart.addAll` (or similar) and use it in `_MenuTile._add`. Nothing needs it today.

## Gates (final candidate, this session)

| Command | Exit code |
|---|---|
| `make analyze` | 0 |
| `make test` (176 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `git diff --stat pubspec.yaml` (empty: no new dependency) | 0 |
| `make check` (176 app + 170 backend tests) | 0 |

## Unverified (owner acceptance)

- **Whole flow at `http://customer.local`:** add a food, tick toppings and a drink, pick them, open the cart, check the lines and the total, place the order.
- **iPhone Safari:** the dialogs are usable with one thumb.
- **Wording:** the English wording is acceptable until the Vietnamese translation.
