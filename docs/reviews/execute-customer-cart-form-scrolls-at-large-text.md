---
task: customer-cart-form-scrolls-at-large-text
status: passed
p0: 0
p1: 0
---

# Execute review: customer-cart-form-scrolls-at-large-text

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). No security review: plain UI layout. The card doesn't ask for one and the diff crosses no Safety-policy trigger.

## Candidate

- `lib/customer/pages/cart_page.dart`: the body is now one `ListView`, in this order: the cart lines, the name field, the total, the Place Order button, then the failure line when an order failed. The place-order logic (`_placeOrder`, `_sending`, `_failed`) is unchanged.
- **One layout change beyond the card:** the total now sits above a full-width `FilledButton` instead of beside it in a `Row`. At text scale 2.0 the button alone overflowed the row by 5.1 px. The reviewer judged this justified and in scope.
- `test/cart_page_test.dart`: the fit test runs at 1.0, 1.3, 1.6 and 2.0 (360 px wide, three lines, failure line shown). It scrolls to and taps the button at 2.0. The pointer comment is removed.

## Gates

Run by the executor in this session on the candidate as reviewed.

| Command | Exit code | Output tail |
|---|---|---|
| `make analyze` | 0 | `No issues found!` |
| `make test` | 0 | `+343: All tests passed!` |
| `make format-check` | 0 | `Formatted 62 files (0 changed)` |
| `make boundaries` | 0 | `boundaries: ok` |

## Findings

P0: none. P1: none.

P2, deferred as follow-ups:

1. `lib/customer/pages/cart_page.dart:166-180`: the failure line is now the last item, under the button, and nothing scrolls to it. At large text, a customer may tap Place Order and not see "Couldn't place your order" below the fold. Screen readers still announce it. **Follow-up:** do it in `customer-cart-payment-method-choice`, which reworks this same area. Either put the failure line above the button, or call `Scrollable.ensureVisible` on it after a failure, and add a test without a manual scroll.
2. `test/cart_page_test.dart:226-283`: no test checks that a typed name survives being scrolled off-screen and back. The code is correct, because the controller is owned by the State. **Follow-up:** add the test in the same card.
3. `test/cart_page_test.dart:278-282`: overflow is checked once at the end. Optionally also check `takeException()` right after the first pump.

## Unverified (owner acceptance)

On the iPhone with the largest text setting, the cart is usable (Safari, real device).

## Final gate before archiving

| Command | Exit code | Output tail |
|---|---|---|
| `make check` | 0 | format-check `0 changed`, analyze clean, `boundaries: ok`, Flutter and backend tests `All tests passed!` (backend +411) |

Run 2026-11-19 in this session on the final candidate, with no fix round needed. The tree also held the frozen `backend-xlsx-writer` candidate at the time. Card moved to `docs/tasks/done/`.
