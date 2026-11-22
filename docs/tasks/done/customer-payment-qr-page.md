---
executor: task-executor
scopes: [customer, shared]
workKinds: [flutter, quality-gate]
blockedBy: [customer-cart-payment-method-choice]
securityReview: required
---

# Customer: the transfer page (QR, 5-minute countdown, note, switch to cash, and the question after expiry)

Planned 2026-11-19, updated the same day. **No open decisions block this card.** Security review is required because of the new dependency.

## Owner decisions (verbatim, 2026-11-19)

> If they pick "Chuyển khoản", generate a QR code for Vietnamese bank transfer with the exact same amount of money they need to pay. Tell them to transfer to the generated QR code within 5 mins to keep the order. Add a note below telling that "Đổi sang thanh toán tiền mặt nếu bạn chưa muốn thanh toán luôn" then adding a button to let them switch the payment method to Cash/Tiền mặt. Also cancel the generated QR code.
> (The owner typed "chwa"; the text is "chưa".)

- **PAY4, decided:** "approve both". The Flutter dependency **`qr_flutter`** is approved (it draws the payload the backend sends; no payment data leaves our servers). The executor picks and pins a current stable version, checks the licence and its transitive dependencies (e.g. the `qr` package), and the security review covers the supply chain. Any other new package still needs approval. If `qr_flutter` turns out unusable, stop and ask.
- **PAY5, decided:** "Hide it, a late transfer has to be handled by hand manually; ..." So "cancel the QR" means hide it. A bank QR can't be revoked, so a late transfer is handled by hand outside the app.
- **PAY7, decided ("7. Yes"):** show the bank name, account number, account holder and amount as selectable text beside the QR, with the transfer content. **PAY8, decided:** the transfer content is `DH` + the last 6 digits of the order id; the page shows the `reference` the backend sends, exactly.
- **PAY13, decided:** "also after it was cancelled". Staff can bring an expired order back as cash, so the page must handle a `cancelled` order turning into a cash `preparing` one.
- **PAY15, decided, verbatim:** "a cancelled bank-transfer order will be asked to user that if they want to switch to cash or not, if yes, switch to cash, else, generate another QR code." Planner's reading, for the owner to correct: only for an order cancelled by the 5-minute expiry (`Order.expiredUnpaid`, "Only expired"; staff-cancelled orders are not asked); the question is shown on this page; **Yes** = the customer's switch-to-cash, **No** = "generate another QR" = `renew-payment`.
- **PAY14 and PAY16, decided:** "within 15 minutes", and "yes, same 15 minutes". Both answers work only until 15 minutes after the order expired (server clock), with no count limit; after that the server answers 409.

## Sources

`lib/customer/pages/cart_page.dart`, `lib/customer/pages/menu_page.dart` (the "Your orders" banner and status snackbars), `lib/customer/state/my_orders.dart`, `lib/customer/api/payment_client.dart`, `lib/shared/api/order_repository.dart` (`switchToCash`, `renewPayment`, live order updates), `lib/shared/models/order.dart` (`expiredUnpaid`, `renewableUntil`), `test/menu_page_test.dart`, `test/cart_page_test.dart`.

## Goal

A `PaymentPage(orderId)` in `lib/customer/pages/`, opened right after a transfer order is placed (the cart card's hand-over) and re-openable from the menu's "Your orders" banner while the order is `awaiting_payment` **or expired** (see state 4).

It watches the order in `OrderRepository` with `ListenableBuilder` (no new state class) and shows by state:

1. **Awaiting payment, before the deadline:**
   - the QR (`qr_flutter`, from the payload of `PaymentClient.fetchQr`; a failure shows a short message and a Retry button, never the server text);
   - as selectable text: the bank name, account number, account holder, the amount (`formatVnd`) and the transfer content (`DH` + 6 digits);
   - the line telling them to transfer **within 5 minutes to keep the order**, with a live `mm:ss` countdown to `paymentDueAt`;
   - below it the note **"Đổi sang thanh toán tiền mặt nếu bạn chưa muốn thanh toán luôn"** and a button **"Chuyển sang tiền mặt"**.
   - The QR is fetched when the page first sees this state **and again whenever `paymentDueAt` changes** (a renewal gives a new deadline).
2. **Switch to cash (customer):** the button calls `OrderRepository.instance.switchToCash(id)`. While it runs the button is disabled. On success the **QR and the transfer text are hidden** (the "cancel the QR" of PAY5), and the page shows that the order will be paid in cash. On a 409 (it just expired, or staff handled it) the page refreshes from the repository and shows that state; other failures show the short failure text.
3. **Paid or switched by staff** (the order is now `preparing`; the method is `bank_transfer` if staff confirmed the transfer, `cash` if switched): the page says the payment was received (transfer) or that the order will be paid in cash (cash). No QR. A button back to the menu.
4. **Expired** (`order.expiredUnpaid`): no QR. The page **asks the question** (suggested Vietnamese wording; the owner approves it): "Đơn của bạn đã hết hạn thanh toán. Bạn có muốn chuyển sang thanh toán tiền mặt không?" with two buttons:
   - **"Chuyển sang tiền mặt"** (yes): `switchToCash(id)`. Success -> the cash view of state 3.
   - **"Tạo mã QR mới"** (no, generate another QR): `renewPayment(id)`. Success -> the order is `awaiting_payment` again with a fresh `paymentDueAt`, the page shows state 1 with a **new QR and a new 5-minute countdown** (the old QR is not shown).
   - While a call runs both buttons are disabled. A **409** (more than 15 minutes since the expiry, or staff changed the order meanwhile) refreshes the page from the repository; if it is still expired the question is replaced by "Đã quá 15 phút. Hãy đặt lại đơn hoặc báo cho quán." (suggested wording) with a button back to the menu. A **503** from renew shows "Chuyển khoản tạm thời không dùng được" with the cash button still available. Other failures show the short failure text.
   - The page also **hides the two buttons once `now > renewableUntil`** (the 15 minutes, from the phone clock, for display only) and shows the "đã quá 15 phút" text; the server stays the judge, so a tap just before the line may still get a 409 and the refresh above.
   - A staff-cancelled order (`cancelled` without `paymentDueAt`) is **not** asked: a plain message that the order was cancelled, and a button back to the menu.
   - If staff switch the expired order to cash while this page is open, the live update replaces the question with the cash view of state 3.
5. Leaving the page (back) never changes the order. The menu's "Your orders" banner lists this session's orders that are `awaiting_payment` **and those that are expired within their 15 minutes**; tapping either re-opens this page (the expired one shows the question). An expired order past its 15 minutes, a staff-cancelled order and every other terminal order stay off the banner. A snackbar fires when an order of this session expires, so a customer who left the page sees it (reusing the existing status-change snackbar).

Countdown details (these are real bug sources, tested):
- Driven by one `Timer.periodic(1 second)` owned by the page state, **cancelled in `dispose`** and when the deadline passes; no timer survives the page (a leaked timer is a P1). It also drives the 15-minute check of state 4.
- The countdown uses the phone's clock against `paymentDueAt`, which is the server's clock. If the phone's clock is wrong, the number is off; the **server decides** (the order flips to `cancelled` over the live stream). The QR is hidden when the repository says the order is no longer `awaiting_payment`, or when the countdown reaches zero (then show "đang kiểm tra" until the server's event arrives, with a short grace re-read via the repository).
- Never negative; shown as `mm:ss`, like `04:59`.

New strings are Vietnamese; list them in the executor notes for `vi-translate-customer-ui`.

## Non-goals

Anything in the restaurant app, automatic detection of the bank transfer, saving the QR as an image, push notifications, changing the status from the customer side other than switching to cash and renewing, offering the question for staff-cancelled orders.

## Tests written with the change

Widget tests with a fake `PaymentClient`, the repository's test hooks and `tester.pump(Duration)` (no real waiting):
- awaiting: shows the QR widget with the payload text it was given, the bank name, account number, holder, the exact amount, the transfer content, the owner's note text and the button; the countdown shows `05:00` -> `04:59` after a second.
- switch to cash success: QR and transfer text gone, cash message shown, repository order is cash; failure keeps the QR and shows the failure text; 409 refreshes.
- order flips to `preparing` (transfer) through the repository -> paid view, no QR; `preparing` with method cash -> cash view, no QR.
- **expired question:** an order flipping to `cancelled` with `paymentDueAt` set shows the question and two buttons, no QR. "Chuyển sang tiền mặt" calls `switchToCash` and shows the cash view. "Tạo mã QR mới" calls `renewPayment`; when the order comes back as `awaiting_payment` with a new `paymentDueAt` the page fetches a **new** QR and the countdown restarts at `05:00`.
- renew/switch answering 409 refreshes and shows "đã quá 15 phút" when still expired; renew answering 503 shows the unavailable text and keeps the cash button; both buttons are disabled while a call runs.
- with the fake clock past `paymentDueAt + 15 min` the buttons are hidden and the "đã quá 15 phút" text shows; at +14:59 they are shown.
- a `cancelled` order **without** `paymentDueAt` shows the plain cancelled message and no question.
- staff switch the expired order to cash while the page is open (`cancelled` -> `preparing` cash) -> the question is replaced by the cash view.
- the countdown reaches zero -> QR hidden, checking message, no negative number.
- `fetchQr` failing -> message and Retry; Retry refetches.
- leaving the page cancels the timer (`tester.pumpAndSettle` leaves no pending timers; test with `flutter_test`'s pending-timer check).
- banner: an `awaiting_payment` order and an expired order within 15 minutes appear and open the page; an expired order past 15 minutes, a staff-cancelled order, a `delivered` one do not.
- no overflow at 360 px for text scales 1.0 to 2.0 (including the question view).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Format, analysis, boundaries | `make format-check`, `make analyze`, `make boundaries` (gates) |
| Only `qr_flutter` added (version pinned, licence and transitive packages checked); QR shows only while payable | `security-reviewer`, `code-reviewer` (reviews) |
| Timer cancelled on dispose; no leaked listeners | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| A real banking app scans the QR on screen and fills in the exact amount and the content | owner acceptance - "unverified" until done |
| After the 5 minutes the question appears; "Chuyển sang tiền mặt" turns the order into a cash order; "Tạo mã QR mới" shows a new working QR and countdown; after 15 minutes neither is offered | owner acceptance - "unverified" until done |
| The countdown, the confirm from the restaurant side and an expired order brought back as cash by staff behave as described on a real phone | owner acceptance - "unverified" until done |
| The QR, the text details and the question are readable on a small phone at large text sizes | owner acceptance - "unverified" until done |

## Environment limits

Agents can't scan a QR with a banking app or wait real minutes.

## Note from `docs/reviews/execute-backend-order-payment-transitions.md` (P2)

`GET /orders` and the stream can show an order as `awaiting_payment` for up to 15 s after its deadline (the sweep interval). The UI treats `paymentDueAt <= now` as expired.

## Note from `docs/reviews/security-backend-payment-qr-endpoint.md`

A QR already on screen stays scannable at the bank. The page must clear it at `dueAt` and as soon as the order's status changes on the stream (switched, confirmed, cancelled), and fetch a fresh one only after a renew.

## Note from `docs/reviews/security-shared-order-payment-model-and-client.md` (P2)

Guard `Order.renewableUntil` against an out-of-range date (try/catch, or treat it as not renewable).

## Note from `docs/reviews/execute-customer-payment-client.md` (P2)

`PaymentClient` has no request timeout. Give the page a timeout or a "Thử lại" (retry) state, so a hung request never leaves the customer staring at a spinner.
