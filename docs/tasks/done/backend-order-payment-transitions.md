---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-order-payment-method]
securityReview: required
---

# Backend: switch to cash (customer, or staff), renew the transfer, staff confirm, 5-minute expiry

Planned 2026-11-19, updated the same day with the owner's answers. **No open decisions block this card.** Changes the `CLAUDE.md` API table first (owner approval needed for this card). No schema change: everything uses the shipped `payment_method` and `payment_due_at` columns.

## Owner decisions (verbatim)

> Tell them to transfer to the generated QR code within 5 mins to keep the order. Add a note below telling that "Đổi sang thanh toán tiền mặt nếu bạn chưa muốn thanh toán luôn" then adding a button to let them switch the payment method to Cash/Tiền mặt. Also cancel the generated QR code.

- **PAY1, decided (owner, 2026-11-19):** staff confirm "Đã nhận chuyển khoản" in the restaurant app after checking the bank app. No bank webhook. (Follow-up only, not planned: a bank-notification service such as SePay, Casso or payOS could confirm automatically, but it needs a public endpoint and a backend reachable from the internet.)
- **PAY3, confirmed (owner, 2026-11-19):** the **backend** owns the 5-minute deadline and the expiry, using the **server clock**; an unpaid transfer order is cancelled (`cancelled`).
- **PAY5, decided (owner, 2026-11-19):** "Hide it, a late transfer has to be handled by hand manually; If so let the staff change the payment type to CASH by hand." An expired order is cancelled and its QR is no longer served or shown. A bank QR can't be revoked, so anyone who already scanned it can still send money. **Staff can NOT confirm a cancelled order in the app** (`confirm-payment` on it is 409); late transfers and refunds are handled by hand, outside the app, and the app never moves money.
- **PAY13, decided (owner, 2026-11-19):** "also after it was cancelled". Staff can change the payment type to cash on an `awaiting_payment` order **and** on a `cancelled` order that was cancelled by the 5-minute expiry (method `bank_transfer`, never confirmed). Either way the result is `paymentMethod: cash` and status `preparing`. **Staff have no time limit.** Not allowed on any other status, nor on a cancelled cash order, nor on a transfer order that staff cancelled on purpose.
- **PAY15, decided (owner, 2026-11-19), verbatim:** "a cancelled bank-transfer order will be asked to user that if they want to switch to cash or not, if yes, switch to cash, else, generate another QR code." Planner's reading, for the owner to correct:
  - **Yes, switch to cash:** the **customer's** switch-to-cash now also works on an expired order. Result: cash + `preparing`, the same as the staff switch.
  - **No, generate another QR:** a new customer route `POST /orders/{id}/renew-payment` moves the order back to `awaiting_payment` with a **fresh** `paymentDueAt` (server clock + 5 minutes). Same order id and same amount, so the QR payload is rebuilt from the stored order; the old QR is just hidden (it can't be revoked, see PAY5).
  - **Unchanged:** PATCH still can't revive a cancelled transfer order; `confirm-payment` on a cancelled order is still 409.
- **Scope, decided (owner, 2026-11-19, "Only expired"):** only an order cancelled **by the 5-minute expiry** is offered the question (`cancelled`, `bank_transfer`, `paymentDueAt` still set; in the apps `Order.expiredUnpaid`). A staff-cancelled order (its `paymentDueAt` was cleared) is not.
- **PAY14, decided (owner, 2026-11-19):** "within 15 minutes". Renewing is allowed only within **15 minutes after the order expired**, by the server clock: `now <= paymentDueAt + 15 minutes`, using the `paymentDueAt` of the expired window. There is **no count limit**. Each renewal sets a new `paymentDueAt`, so the 15 minutes count from the latest expiry. After that the renew route answers 409.
- **PAY16, decided (owner, 2026-11-19, "yes, same 15 minutes"):** the **customer's** switch-to-cash on an expiry-cancelled order uses the **same 15-minute window** (`now <= paymentDueAt + 15 minutes`); after it, 409. The customer's switch from a live `awaiting_payment` order has no extra limit. The staff switch (PAY13) stays unlimited.

## Sources

`backend/lib/orders_api.dart`, `backend/lib/staff_gate.dart` (`StaffGate.check`), `backend/lib/shop_settings.dart` (`transferEnabled`), `backend/test/orders_api_test.dart`, the shipped columns `payment_method` and `payment_due_at` and the rule that a staff cancel clears `paymentDueAt`, so a `cancelled` order that still has it was cancelled by expiry, `CLAUDE.md` -> "Backend".

## Goal

### Contract (table rows first)

Two terms. **Expired**: `bank_transfer` and `cancelled` with `paymentDueAt` set; an `awaiting_payment` order past its `paymentDueAt` that the sweep hasn't cancelled yet counts as expired too (the routes run the expiry check first). **In window**: `now <= paymentDueAt + renewWindow`, where `renewWindow` is a constant of 15 minutes.

| Method | Path | Who | What |
|---|---|---|---|
| POST | `/orders/{id}/switch-to-cash` | customer, no staff ID | For a live `awaiting_payment` order (any time before its deadline), **or** an **expired** order that is **in window** (PAY15, PAY16). Sets `paymentMethod: cash`, `paymentDueAt: null`, status `preparing`. **200** with the order. **404** unknown id; **409** any other state (paid, cash, `preparing` or later, staff-cancelled) **and an expired order past the 15 minutes**. |
| POST | `/orders/{id}/renew-payment` | customer, no staff ID, no body | Only for an **expired** order that is **in window**. Sets status `awaiting_payment`, `paymentDueAt` = server now + 5 minutes. Same id, same amount, method stays `bank_transfer`. **200** with the order; **404**; **409** any other state: a live `awaiting_payment` order not yet due, cash, paid, `preparing` or later, staff-cancelled, **or expired more than 15 minutes ago**; **503** bank transfer is not set up (`transferEnabled` false). |
| POST | `/orders/{id}/staff-switch-to-cash` | **staff only** (`X-Staff-Id` + `X-Staff-Password`) | `awaiting_payment` or **expired** (no time limit, PAY13). Same result as the customer switch. **200**; **401 / 403 / 429** as the staff gate; **404**; **409** otherwise. |
| POST | `/orders/{id}/confirm-payment` | **staff only** | Only for a `bank_transfer` order that is `awaiting_payment` and not past its deadline (a **renewed** order counts: its deadline is the fresh one). Sets status `preparing`, `paymentDueAt: null`, method stays `bank_transfer`. **200**; **401 / 403 / 429**; **404**; **409** otherwise, **including a cancelled (expired) order**. |

- Order of checks in the customer routes: id lookup (404), expiry check (lazy), state and window (409), `transferEnabled` (503, renew only).
- Ids in the path are URL-decoded and used only as bound SQL parameters, like PATCH.
- All four routes publish the updated order on the SSE stream, so the customer's page and the restaurant screen update live.
- The staff gate is checked **first**, before any lookup, like the export route.
- **Races** (first one wins; every write is `UPDATE ... WHERE id = ? AND <expected status, method and paymentDueAt>` and the route answers 409 when `updatedRows` is 0, so it is also safe if the owner edits the database by hand): there is no `await` between a route's read and its write, so two requests in this process can't interleave.
  - renew vs staff switch-to-cash: if the switch lands first the order is cash + `preparing` and renew answers 409; if renew lands first the order is a live `awaiting_payment` and the staff switch then makes it cash + `preparing`.
  - renew vs the sweep: the sweep only cancels an `awaiting_payment` order whose deadline has passed; a renewed order has a fresh deadline, so the sweep can't cancel it again. A renew that arrives before the sweep handles the overdue order itself.
  - renew twice quickly: the first sets a live `awaiting_payment`, the second answers 409.
  - confirm vs renew: confirm needs a live `awaiting_payment` order; on an expired one it is 409 whatever happens.
- **Security note:** the customer routes have no authentication (accepted risk, as for the existing customer switch-to-cash). Anyone on the wifi who knows or guesses an order id can renew or switch it, within the 15 minutes. The window and the counter handover of cash orders bound the harm; real login is still needed before real customers.
- Why the staff switch is separate from the customer one: the customer route has the 15-minute window, the staff route has none and needs the staff ID and password.

### Expiry

- An `awaiting_payment` order whose `paymentDueAt` is at or before the server's now becomes `cancelled`; `paymentDueAt` is **kept** (it marks "cancelled by expiry" and starts the 15-minute window).
- A sweep runs on a periodic timer in `OrdersApi` (every 15 seconds; the interval a constant), cancelling every overdue order and publishing each on SSE. `close()` cancels the timer. The clock and an `expireOverdue()` method are injectable/public so tests don't wait.
- A cancelled order is never moved by the sweep again until it is renewed; a renewed order that expires again starts a new 15-minute window from its new `paymentDueAt`.

## Non-goals

The QR (card `backend-payment-qr-endpoint` serves a renewed order), the apps' UI, automatic bank notifications, refunds, a "paid at" timestamp, retry or reminder messages, confirming a cancelled order, letting PATCH revive an order, a renewal counter or schema change.

## Tests written with the change

With an in-memory database and an injected clock:
- customer switch: live transfer order -> 200, cash, `paymentDueAt` null, `preparing`, one SSE event; on an **expired** order at expiry + 14:59 -> **200** cash + `preparing`; at expiry + 15:01 -> **409** and the order stays `cancelled`; on a staff-cancelled transfer order -> 409; a second call -> 409; on a cash order -> 409; unknown id -> 404.
- renew: expired order **at expiry + 14:59 -> 200**, `awaiting_payment`, `paymentDueAt` = now + 5 min, one SSE event, same id and items; **at expiry + 15:01 -> 409** and the order stays `cancelled`; renew again while live -> 409; after the renewed window expires, renew at its expiry + 14:59 -> 200 again (the window counts from the latest expiry; no count limit, e.g. five renewals in a row work); a staff-cancelled order -> 409; cash, `preparing`, `delivered` -> 409; transfer disabled -> 503; unknown id -> 404; an overdue but not yet swept order is renewed correctly; the amount and items are unchanged.
- races: renew then staff switch -> cash `preparing`; staff switch then renew -> 409; renew then sweep at the old deadline -> order stays `awaiting_payment`; renew twice -> second is 409.
- staff switch: no headers 401, wrong 401, gate disabled 403, lock-out 429; live transfer order -> 200 cash + `preparing`; an **expired** order, also hours later (no limit) -> 200; a staff-cancelled transfer order -> 409; `preparing`, `ready`, `delivered` -> 409; cash or cancelled cash -> 409; unknown id -> 404; the staff check happens before the lookup.
- confirm-payment: the same gate cases; live order -> 200 `preparing`, method still `bank_transfer`; a **renewed** live order -> 200; **expired (cancelled) order -> 409, still `cancelled`**; cash order -> 409; twice -> 409; unknown id -> 404.
- `expireOverdue()` at deadline minus 1 ms leaves the order; at the deadline cancels it; cancels several at once; ignores `cash`, confirmed and already cancelled orders; emits one event each; an order revived as cash or renewed is not cancelled again by the old deadline.
- The timer is cancelled by `close()` (no timer left running after the test).
- Ids like `a/b`, `%`, a 64-char id, and `'; DROP TABLE orders;--` give 404, never an error or a changed row count.
- Existing PATCH (including the refusal to move a cancelled transfer order), POST, GET and SSE tests still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour and status codes as listed | `make backend-test` (gate) |
| Backend clean; no new dependency | `make backend-analyze` (gate) |
| Staff routes fail closed and check first; customer routes only move live or in-window expired orders; renew can't touch a staff-cancelled, cash or paid order; conditional updates; server clock only; no request data in logs or replies | `security-reviewer` (review) |
| `CLAUDE.md` table rows and the "late transfers are handled by hand; an expired order can be renewed or switched to cash by the customer within 15 minutes; staff have no limit" rule match the code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| With the real backend: a transfer order is cancelled about 5 minutes after it is placed; renew within 15 minutes gives a working new 5-minute window; after 15 minutes renew and the customer's switch are refused; staff can still switch | owner acceptance - "unverified" until done |

## Environment limits

Agents don't wait real minutes; the clock is injected.

## Carried in from `docs/reviews/execute-backend-order-payment-method.md` and `security-backend-order-payment-method.md`

- `backend-order-payment-method` now refuses a PATCH that moves a `bank_transfer` order out of `cancelled` (409 "Use the payment routes"). It clears `payment_due_at` only when an `awaiting_payment` order is cancelled. So "cancelled with `paymentDueAt` set" reliably means cancelled by expiry.
- `CLAUDE.md` API table, PATCH row: add "or a `bank_transfer` order that is `cancelled` and the target isn't `cancelled`" to the 409 cell (the order rules already say it).
- Known limitation: a paid transfer order (`preparing` or later) that staff cancel by mistake can't be moved back. This is handled by hand, consistent with PAY5. Write it in the docs card.
