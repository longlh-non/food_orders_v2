---
task: restaurant-orders-status-update-shows-failure
status: passed
p0: 0
p1: 0
---

# Review: restaurant-orders-status-update-shows-failure

Independent reviewer: `code-reviewer` (read-only). No security review: restaurant UI only. The response handling was reviewed in `shared-order-calls-report-failure`, and the card has no `securityReview`.

The owner invoked the card as `docs/tasks/restaurent-orders-status-update-shows-failure.md` (no such file), so this card ran.

## Candidate

- **`lib/restaurant/pages/orders_page.dart`:**
  - New `_OrdersPageState._changeStatus(id, status)`: it awaits `OrderRepository.instance.updateStatus` and catches `OrderRequestException` only. On failure, if still mounted, it shows the fixed SnackBar "Couldn't update the order. Try again." and never the exception text.
  - Both call sites use it: the new-order SnackBar's "Accept" action, and the card's action button.
  - `_OrderCard` stays stateless and gets an `onChangeStatus` callback from the page.
- **`test/orders_page_test.dart`:** the reset restores a real client; a new group "status changes report failure":
  - the button with a 500 or no answer shows the message, leaves the status pending and shows no server text;
  - with a 200, no message, the status becomes accepted, and the button reads "Start preparing";
  - the new-order SnackBar's Accept with a 404 shows the message and leaves the status pending.

## Round 1: passed. P0 0, P1 0, P2 2

- **P2:** exceptions other than `OrderRequestException` still become unhandled future errors, by design. The earlier card turns every transport, status and parse failure into that one type.
- **P2:** no test for the unmounted case (the `mounted` guard). Low risk.

Confirmed:
- Goals 1–3;
- `context` is used only behind `mounted`;
- **`hideCurrentSnackBar`:** it can hide another order's "New order" SnackBar. Accepted: the page already does this, and that order keeps its own button in the list;
- the chime and new-order detection are unchanged;
- the tests aren't vacuous (the SnackBar test first checks "New order from An" appeared);
- restaurant-only.

## Deferred (optional)

- A test for a failure that arrives after the page is gone.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` | 0 |
| `make test` (303 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make check` (first run; 12 add-food dialog tests failed, see below) | 2 |
| `make check` (after the test update; 303 app + 306 backend tests) | 0 |

## Note: unrelated `make check` failure, fixed with the owner's approval

The first `make check` failed in `test/add_food_dialog_test.dart`, not in this card's files. The owner had renamed the add-food dialog's checkbox from "A drink" to "Add drinks" in `lib/customer/pages/add_food_dialog.dart`, and the tests still looked for "A drink".

- The executor had already moved the card to `done/` in the same command. It was moved back as soon as the failure showed.
- The owner chose to keep "Add drinks". The tests were updated to the new label (the drink step's title is still "A drink", as the owner left it), and `vi-translate-customer-ui` got a note to translate it.
- This card's own code was unchanged by that fix.

## Unverified (owner acceptance)

At `http://restaurant.local`, with the backend stopped, pressing Accept should show the message.
