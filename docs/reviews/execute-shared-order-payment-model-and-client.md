---
task: shared-order-payment-model-and-client
status: passed
p0: 0
p1: 0
---

# Execute review: shared-order-payment-model-and-client

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). The security review is in `docs/reviews/security-shared-order-payment-model-and-client.md`.

## Candidate

- `lib/shared/models/order.dart`:
  - `OrderStatus` is now `awaiting_payment, preparing, ready, delivered, cancelled`;
  - `PaymentMethod` is new;
  - `Order` gains `paymentMethod` and `paymentDueAt`;
  - new getters `expiredUnpaid` and `renewableUntil`;
  - `toJson` never sends `paymentDueAt`.
- `lib/shared/api/order_api_client.dart`: `switchToCash`, `renewPayment`, `staffSwitchToCash` and `confirmPayment` (the staff headers are a plain parameter, never stored).
- `lib/shared/api/order_repository.dart`: the same four calls, each merging the returned order; nothing is notified on failure.
- Compile fixes:
  - `lib/customer/pages/cart_page.dart` now posts `preparing` with cash;
  - `lib/restaurant/pages/orders_page.dart` no longer has an Accept action; its flow is `preparing` → `ready` → `delivered`, and the chime and badge fire on new `preparing` orders.
- Tests: `test/order_payment_test.dart` is new, and 6 older tests were rewritten from `pending`/`accepted` to `preparing`/`ready`.

## Gates

| Command | Exit code | Output tail | Run by |
|---|---|---|---|
| `make analyze` | 0 | `No issues found!` | executor |
| `make test` | 0 | `+374: All tests passed!` | executor |
| `make boundaries` | 0 | `boundaries: ok` | executor |
| `make format-check` | 0 | `Formatted 71 files (0 changed)` | executor |
| `make backend-test` | 0 | `+524: All tests passed!` | executor |
| `make check` | 0 | `0 changed`, `boundaries: ok`, analyze clean, Flutter `+374`, backend `+524: All tests passed!` | orchestrator, this session, final candidate |

## Findings

P0: none. P1: none.

The reviewer confirmed:
- the JSON matches the `CLAUDE.md` contract;
- client errors never echo the body, and ids are encoded;
- the repository merges and doesn't notify on failure;
- the getters match the backend rule;
- invariant 1 holds;
- the interim restaurant behaviour is safe, because only cash orders exist until the cart card;
- the rewritten tests keep their intent.

P2, deferred to the cards that rework the same code (notes added to each):

1. No test checks the body the cart posts (`preparing` + `cash`, no `paymentDueAt`). → `customer-cart-payment-method-choice`.
2. Stale "pending/Accept" comments and variable names in `orders_page.dart`. → `restaurant-orders-show-payment-method`.
3. The badge now counts every `preparing` order. → `restaurant-orders-show-payment-method` decides it (PAY10).
4. A transfer order is first seen as `awaiting_payment`, so it never chimes when it becomes `preparing` after payment. It isn't live yet (the cart is cash-only). → `restaurant-orders-show-payment-method` must chime when a transfer is confirmed.
5. `copyWith` can't clear `paymentDueAt`, and `paymentMethod: null` skips the order. Both are consistent with the backend; no action.
6. The apps skip unknown statuses, so against a backend that hasn't run schema step 8 yet, old `pending` orders would be invisible. → `docs-payment-and-reports`: restart the backend (after a backup) before reloading the apps.

## Unverified (owner acceptance)

- Place a cash order in the real customer app and see it on the restaurant screen, through Caddy.
- Live SSE in a browser.
