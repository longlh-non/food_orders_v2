---
task: customer-cart-place-order-shows-failure
status: passed
p0: 0
p1: 0
---

# Review: customer-cart-place-order-shows-failure

Independent reviewer: `code-reviewer` (read-only). No security review: customer UI only. The response handling and JSON parsing were reviewed in `shared-order-calls-report-failure`, and the card has no `securityReview`.

## Candidate

- **`lib/customer/pages/cart_page.dart`.** `_placeOrder` is async:
  - `_sending` disables the button and shows a spinner, which also prevents a double tap;
  - it awaits `OrderRepository.instance.placeOrder` and catches only `OrderRequestException`.
  - **On failure:** the cart and name are kept, the id isn't tracked, and red inline text says "Couldn't place your order. Try again." (`Semantics(liveRegion: true)`). It clears when the next try starts.
  - **On success:** `MyOrders.track`, then `cart.clear()`, then a `mounted` check. Only after the check: clear the name, show the 'Order placed, <name>!' SnackBar, pop.
- **`test/cart_page_test.dart`**, 9 new tests:
  - success;
  - failure for 400, 500 and no answer;
  - the pending state (button disabled, spinner, a second tap sends nothing);
  - retry with a new id;
  - leaving mid-request, after which the accepted order is still tracked with no error;
  - failure text fits at 360 px at text scale 1.0 and 1.3.

**Deviation, recorded in the card:** the failure is shown inline, not as a SnackBar. The retry test proved the SnackBar covers "Place Order", so the customer couldn't retry for about 4 seconds. The reviewer accepted it.

## Round 1: passed. P0 0, P1 0, P2 3

- **P2-1:** after an accepted order, `_nameController.clear()` ran even if the page had been left mid-request. The controller was already disposed by then, so debug builds threw.
- **P2-2:** a non-`OrderRequestException` error (a programming error) leaves `_sending` true. Accepted, because every real failure is converted to `OrderRequestException`.
- **P2-3:** the inline text wasn't announced to screen readers, and the layout at 360 px with large text was untested. The retry test didn't assert a new id.

Confirmed:
- Goals 1–6;
- track-after-success is correct;
- `context` is used only after a `mounted` check;
- the tests aren't vacuous;
- boundaries are clean;
- no new dependency.

## Fixes (P2-1, P2-3)

- **P2-1:** the name is cleared only after the `mounted` check. Test added: leave mid-request, then the order is accepted.
- **P2-3:**
  - `Semantics(liveRegion: true)` on the error;
  - the retry test asserts a different id;
  - fit test at 360 px for text scale 1.0 and 1.3.

## Re-review 1: passed. P0 0, P1 0

## Deferred follow-ups

- **Large text:** at text scale 1.6 and above on a 360 px phone, the cart's bottom strip doesn't scroll and overflows (45 px at 1.6, 220 px at 2.0 with the test font). The layout predates this card; the error line adds a little height.
  - New card: `docs/tasks/customer-cart-form-scrolls-at-large-text.md`.
  - The test comment points to it. Fix before real customers.
- **Leave and come back:** if the customer leaves the cart mid-request and comes back, they get a fresh page that can send a second order while the first is in flight. Accepted per the card (no extra lock).
- **Programming errors:** a non-`OrderRequestException` error leaves the spinner on. Accepted (P2-2).

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` (round 1 and after fixes) | 0 |
| `make test` (205 tests, then 208 after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `git diff --stat pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 208 app + 186 backend tests) | 0 |

## Unverified (owner acceptance)

- **Backend stopped:** at `http://customer.local`, placing an order shows the error and keeps the cart.
- **Backend running:** the order appears live on `http://restaurant.local`.
- **Large text:** the cart at text scale 1.6 and above (follow-up card).
