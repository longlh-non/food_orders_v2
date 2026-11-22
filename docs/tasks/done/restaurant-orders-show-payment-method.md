---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [shared-order-payment-model-and-client]
---

# Restaurant: show each order's payment method, drop the Accept step, new-order chime and badge for the new statuses

Planned 2026-11-19, updated the same day with the owner's answers. **No open decisions block this card.**

## Owner decisions (verbatim)

- **PAY2, decided (owner, 2026-11-19):** "Get rid of 'pending' status, go straight to 'preparing' after finish the order." A cash order arrives `preparing`; a transfer order arrives `awaiting_payment` and becomes `preparing` when staff confirm.
- **PAY8, decided:** the transfer content is `DH` + the last 6 digits of the order id.
- **PAY10, decided ("OK" to the recommendation):** the bell badge counts `awaiting_payment` + `preparing`. `ready` is not counted. An expired order revived as cash is `preparing` again and counts again; a **renewed** order is `awaiting_payment` again and counts again.
- **PAY13, decided:** "also after it was cancelled". An expired transfer order can be brought back as cash by staff (button in `restaurant-confirm-bank-transfer`).
- **PAY15, decided (owner, 2026-11-19):** "a cancelled bank-transfer order will be asked to user that if they want to switch to cash or not, if yes, switch to cash, else, generate another QR code." So an expired order can also come back **as `awaiting_payment` with a fresh deadline** (customer renewed the QR, within 15 minutes, PAY14). This card only has to display it normally.

## What changes in the restaurant flow (plain words)

Today a new order is `pending`; the screen chimes and shows a snackbar with an **Accept** button, the bell badge counts `pending`, and the card's button walks `pending -> accepted -> preparing -> ready -> delivered`. With `pending` and `accepted` gone, nothing would ever chime or count. So: no Accept step; the flow on a card is `preparing -> ready -> delivered`, and the chime, snackbar and badge watch the new statuses.

## Sources

`lib/restaurant/pages/orders_page.dart` (`_onRepoChanged`, `_seenIds`, `_OrderCard._nextStatus`, `_actionLabel`, badge), `lib/shared/models/order.dart`, `lib/shared/chime.dart`, `test/` for the orders page tests, `CLAUDE.md` -> "Notifications".

## Goal

1. **Payment on every card:** a small chip/line with the method (`Tiền mặt` / `Chuyển khoản`) next to the status chip. For `awaiting_payment` also show the transfer content (`DH` + last 6 digits of the id) so staff can match it in the bank app, and that the order is not paid yet. For a `cancelled` transfer order that still has `paymentDueAt` (expired unpaid, `expiredUnpaid`), show "Hết hạn thanh toán" so staff know a late bank transfer must be handled by hand. **That card is no longer button-free:** it gets the "Chuyển sang tiền mặt" button from `restaurant-confirm-bank-transfer` (this card only shows the text and leaves room for the button).
2. **A renewed order** (`cancelled` -> `awaiting_payment`, new `paymentDueAt`) is shown **normally as awaiting payment**: the "Hết hạn thanh toán" text disappears, the transfer content stays the same (it does not change on renewal), and the card is counted by the badge again.
3. **New-order notification:** ring the chime and show the snackbar for every **new order id** that arrives as `preparing` or `awaiting_payment`. The snackbar is plain text ("New order from ...", no Accept action; add "chờ chuyển khoản" for `awaiting_payment`). Do **not** ring again when an order that was already seen changes status: not for `awaiting_payment -> preparing`, not when an expired (`cancelled`) order comes back as `preparing`/cash, **and not when an expired order is renewed back to `awaiting_payment`**. The rule is "a new id rings, a known id never rings". The initial load rings nothing, as today.
4. **Badge:** the number of orders in `awaiting_payment` or `preparing` (PAY10).
5. **Card button:** `preparing` -> "Mark ready"; `ready` -> "Mark delivered"; `awaiting_payment` and the expired transfer order get no status button (their payment buttons come from `restaurant-confirm-bank-transfer`); `delivered` and other `cancelled` none. Remove the Accept action, the `pending -> accepted` and `accepted -> preparing` steps and their labels.
6. Nothing else moves: toppings lines, totals, the export button and the failure snackbar stay.

New strings: Vietnamese for the payment texts (the owner's words), the surrounding screen stays in its current language; list them in the executor notes for `vi-translate-shared-and-restaurant-ui`.

## Non-goals

The "Đã nhận chuyển khoản" and "Chuyển sang tiền mặt" buttons, staff credentials, any backend or shared change, filters or tabs by status, sound changes.

## Tests written with the change

In the existing orders-page tests (repository test hooks, `playChime` stubbed as today; tests that used `pending` or Accept are rewritten):
- a cash order shows `Tiền mặt`, a transfer one `Chuyển khoản`; an order without the field shows `Tiền mặt`.
- new `preparing` order -> one chime and a snackbar without an action; new `awaiting_payment` -> one chime and the snackbar; `awaiting_payment -> preparing` -> no second chime; `cancelled` (expired) -> `preparing` with method cash -> no chime; **`cancelled` (expired) -> `awaiting_payment` (renewed) -> no chime**; the initial load rings nothing.
- the badge number for a mixed list (`awaiting_payment`, `preparing`, `ready`, `delivered`, `cancelled`) counts only the first two, including a revived and a renewed order.
- `awaiting_payment` card shows the transfer content and no status button; a renewed one looks the same, without "Hết hạn thanh toán"; `preparing` shows "Mark ready"; `ready` shows "Mark delivered"; an expired unpaid transfer shows "Hết hạn thanh toán" and no status button.
- No overflow at 360 px and text scales 1.3 and 2.0.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Format, analysis, boundaries | `make format-check`, `make analyze`, `make boundaries` (gates) |
| No leaked listeners; no new dependency; no code path still mentions `pending`, `accepted` or Accept | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Live: a cash order from the customer app rings and shows as being prepared; a transfer order rings and shows as awaiting payment; a renewed order shows as awaiting payment again without ringing | owner acceptance in the browser (the chime also needs a prior click) - "unverified" until done |

## Note from `docs/reviews/execute-backend-order-payment-transitions.md` (P2)

`GET /orders` and the stream can show an order as `awaiting_payment` for up to 15 s after its deadline (the sweep interval). The UI treats `paymentDueAt <= now` as expired.

## Carried in from `docs/reviews/execute-shared-order-payment-model-and-client.md` (P2)

- Rewrite the stale "pending/Accept" comments, and rename `newPending` and `pendingCount`.
- The interim code chimes only on a **new** id first seen as `preparing`. A transfer order is first seen as `awaiting_payment`, so it never chimes. Chime once when a known transfer order becomes `preparing` after payment, and never again for that id.
- The badge currently counts every `preparing` order. Apply PAY10 (`awaiting_payment` + `preparing`).
