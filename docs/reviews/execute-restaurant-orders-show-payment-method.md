---
task: restaurant-orders-show-payment-method
status: passed
p0: 0
p1: 0
---

# Execute review: restaurant-orders-show-payment-method

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). There was no security review: the card doesn't ask for one, and the diff is restaurant UI only. No endpoint, parsing, credential, dependency or exposure changed.

## Candidate

- `lib/restaurant/pages/orders_page.dart`:
  - **What the order card shows:** a method chip (Tiền mặt / Chuyển khoản). An awaiting order adds "Chưa thanh toán" and "Nội dung chuyển khoản: DH…". An expired order shows "Hết hạn thanh toán", counting as expired when `expiredUnpaid`, or when it is still awaiting with `paymentDueAt <= now`.
  - **Expiry timer:** one-shot, to the nearest deadline.
  - **Buttons:** `preparing` → "Mark ready" and `ready` → "Mark delivered". Accept is gone.
  - **Chime and snackbar:** a new id that arrives `preparing` or `awaiting_payment` (not lapsed) rings. An order that was awaiting at load and never rang rings once when it becomes `preparing`. Each id rings at most once; expired, revived and renewed orders never ring again.
  - **Badge:** `preparing` plus non-lapsed `awaiting_payment` (PAY10).
  - **Other:** a copy of `transferReference`; the `now` and `chime` hooks.
- `test/orders_page_test.dart`: 20 new tests.
- The earlier export-button work in the same file is intact.

## Gates

| Command | Exit code | Output tail | Run by |
|---|---|---|---|
| `make analyze` | 0 | `No issues found!` | executor |
| `make test` | 0 | `+518: All tests passed!` | executor |
| `make boundaries` | 0 | `boundaries: ok` | executor |
| `make format-check` | 0 | `Formatted 76 files (0 changed)` | executor |
| `make check` | 0 | `0 changed`, `boundaries: ok`, analyze clean, Flutter `+519`, backend `+524: All tests passed!` | orchestrator, this session, final candidate |

## Findings

P0: none. P1: none.

The reviewer confirmed:
- the timer and listener lifecycle (one timer, cancelled and re-armed, `mounted` guards, removed in dispose);
- the expiry boundary (`due == now` is expired) and the badge;
- no `pending`, `accepted` or Accept is left in `lib/`;
- the export work is intact;
- the 360 px fit at 1.0, 1.3 and 2.0;
- the tests are deterministic.

The duplicated `transferReference` is accepted. The backend can't be imported (invariant 4), and the customer app gets the reference from the server, so it doesn't belong in `lib/shared` (invariant 2).

P2:
1. **The `transferReference` copy was pinned on one side only. Fixed by the orchestrator:** `backend/test/vietqr_test.dart` now also pins `transferReference('abc') == 'DH920331'`. The reviewer checked that value independently (FNV-1a 32-bit of "abc"), so drift on either side fails a test.
2. **The chime rule.** It follows the card: a transfer order rings when it arrives (with "chờ chuyển khoản"), not when it is paid. Three cues say "unpaid" and there is no button, so the kitchen isn't invited to cook it. But an order that is paid later becomes `preparing` silently. **Open owner question**, asked on 2026-11-19: ring on arrival (current), on payment, or both. If the owner changes it, it becomes a small follow-up card.
3. `_seenIds` and `_awaitingUnrung` only grow. Harmless at this volume. Accepted.
4. **Before this card, an id shorter than 4 characters threw in the title** (`order.id.substring(order.id.length - 4)`). **Fixed by the orchestrator:** a short id is shown whole, with a test.

**For `docs-payment-and-reports`:** the `CLAUDE.md` "Notifications" text should say:
- the restaurant chimes, with a plain snackbar, for a new id that arrives `preparing` or `awaiting_payment`, and once when a transfer order that was already on screen and never rang becomes `preparing`;
- each id rings at most once;
- an expired, revived or renewed order never rings again;
- the badge counts `awaiting_payment` plus `preparing`;
- the card shows the method, and for an unpaid transfer, the content and "Chưa thanh toán";
- `paymentDueAt <= now` is treated as expired in the UI.

**Strings for `vi-translate-shared-and-restaurant-ui`:** "Mark ready", "Mark delivered", "New order from …", "Incoming Orders".

## Unverified (owner acceptance)

- The live restaurant screen in a browser: the chime with a real new order, expiry flipping at 5 minutes, and the badge.
