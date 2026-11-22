---
task: customer-cart-payment-method-choice
status: passed
p0: 0
p1: 0
---

# Execute review: customer-cart-payment-method-choice

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). There was no security review: the card doesn't ask for one, and the diff changes only customer UI that calls existing, already-reviewed client methods. No endpoint, parsing, dependency or exposure changed.

## Candidate

- `lib/customer/pages/cart_page.dart`:
  - a Tiền mặt / Chuyển khoản choice (`RadioGroup`, cash by default);
  - `fetchInfo` runs once, and transfer is disabled with "Chuyển khoản chưa được bật" while loading, when it is off, or on error;
  - posted bodies: cash → `preparing` + `cash`, transfer → `awaiting_payment` + `bank_transfer`, and `paymentDueAt` is never sent;
  - a transfer order is tracked, then the cart is cleared, then `pushReplacement` opens `PaymentQrPage(orderId)`;
  - the failure line sits above the button and is scrolled into view.
- `lib/customer/pages/payment_qr_page.dart` (new): a minimal stub showing the order id. `customer-payment-qr-page` replaces its body.
- `test/cart_page_test.dart`: the posted-body tests, disabled transfer, a 503, the name surviving a scroll, and fit tests at 1.0-2.0. Two fit cases at 2.0 were added after review.

## Gates

| Command | Exit code | Output tail | Run by |
|---|---|---|---|
| `make analyze` | 0 | `No issues found!` | executor |
| `make test` | 0 | `+430: All tests passed!` (first round), `+432` (after the P2-2 tests) | executor |
| `make boundaries` | 0 | `boundaries: ok` | executor (first round) |
| `make format-check` | 0 | `Formatted 74 files (0 changed)` | executor |
| `make check` | 0 | `0 changed`, `boundaries: ok`, analyze clean, Flutter `+432`, backend `+524: All tests passed!` | orchestrator, this session, final candidate |

## Findings

P0: none. P1: none.

The reviewer confirmed:
- every requirement and every carried-in follow-up is met;
- a late `fetchInfo` and the post-frame callback are guarded by `mounted`, and only an owned client is closed;
- `RadioGroup` is the current, non-deprecated API;
- a failure or 503 keeps the cart and the name;
- the sending state blocks a double order;
- after `pushReplacement` the stack is menu → QR page, so back returns to the menu;
- the tests decode the exact posted body.

P2:
1. The "failure line visible without a manual scroll" test passes without `ensureVisible`, because the line sits right above the just-tapped button. Placing it there is the real fix. Accepted; the callback stays as a harmless extra.
2. The fit tests didn't render the disabled subtitle or the transfer choice at 2.0. **Fixed:** two cases were added at 2.0, and neither overflowed, so no layout change was needed.
3. The button moves down one line when the failure line appears. Accepted (low impact).

**Ship-together note:** on its own, this card lets a customer place a transfer order and see only the stub, with no QR. `customer-payment-qr-page` must land before transfer is used for real.

**Strings for `vi-translate-customer-ui`:** "Tiền mặt", "Chuyển khoản", "Chuyển khoản chưa được bật", and the stub's "Đơn <id>".

## Unverified (owner acceptance)

The cart on a phone at `http://customer.local` at the largest text size, with both choices.
