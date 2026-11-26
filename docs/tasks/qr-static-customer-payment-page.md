---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [qr-static-shared-model-client, qr-static-customer-png-download, qr-static-l10n-strings, status-finished-customer]
---

# Customer: the payment page for the QR without an amount

Planned 2026-11-26, revised after the `status-finished-*` chain (`finished` replaces `ready`/`delivered`; staff may set statuses; a cancelled order is final). Decisions QS2, QS3, QS7, QS11, QS13 in `qr-static-api-contract`. The owner's message and download button are the point of this card.

## Sources

`lib/customer/pages/payment_qr_page.dart` (look, listening to `OrderRepository`, QR fetch, switch to cash; its status `switch` as `status-finished-customer` left it), `lib/customer/pages/menu_page.dart` (the "Your orders" banner and status snackbars), `lib/customer/state/my_orders.dart`, `lib/customer/api/payment_client.dart` (`fetchInfo` gives `staticQrPayload`, bank name, account number, holder), `lib/customer/download/png_download.dart`, `lib/shared/money.dart`, `docs/tasks/done/customer-payment-qr-page.md`.

## Goal

A `StaticQrPaymentPage(orderId)` in `lib/customer/pages/static_qr_payment_page.dart`, a **separate file** from the existing page (no countdown, no renew question). It watches the order in `OrderRepository` with `ListenableBuilder`, and the info once via `PaymentClient.fetchInfo`.

By state:

1. **`awaiting_payment`, method static:** the message `paymentStaticMessage(formatVnd(order.total))` ("Vui lòng chuyển khoản 25.000 VNĐ vào tài khoản dưới đây hoặc quét mã được dán tại quán sau đó thông báo với chủ quán. Rất chân thành cảm ơn!"), the QR drawn from `staticQrPayload` with `qr_flutter` (white background, quiet zone), the bank name, account number and account holder as **selectable text**, the **"Tải mã QR"** button (hidden when `canSavePng` is false; a failure shows the short failure text), the **transfer-content line** (QS11: `paymentStaticReference(items)`, the order's items as `quantity name (toppings)` joined by `, `, accents removed, cut to 50 characters at a whole item, built from `order.items` in the repository, selectable, with a **"Sao chép nội dung"** button using `Clipboard`; the QR itself carries no reference), the line that tells them to inform the shop after paying, and the "switch to cash" note and button (reuse the existing wording and `OrderRepository.switchToCash`, with the same 409 handling: refresh from the repository).
2. **Paid** (`paid`, `preparing` or `finished`, method static): "payment received" view, no QR, back-to-menu button.
3. **Switched to cash** (by customer or staff): the existing cash view; no QR.
4. **`cancelled`:** a plain cancelled message and a back-to-menu button (no question, no renew; a cancelled order is final, so this view never changes back).
5. **Info failure** (`fetchInfo` fails, transfer disabled, or no `staticQrPayload`, e.g. an older server): a short message and a Retry button; the amount message stays visible.

Because staff may set statuses (SF6), the page follows **any** change from the repository without a stale view: a static order staff moved to `preparing`, `paid` or `finished` shows state 2; one moved back to `awaiting_payment` (allowed for static from a non-cancelled status) shows state 1 again.

The amount shown is `order.total` from the repository (what the server stored), never recomputed from the cart. Leaving the page never changes the order. No `Timer` and no new state class.

Menu banner: an `awaiting_payment` static order of this session is listed and opens this page (an existing-method order still opens the old page). The banner's "ended" rule (`finished`, `cancelled`) is the one from `status-finished-customer`; `paid` counts as live and the status snackbar names it with the localized label. A static order never shows an "expired" state.

The text builder is a small pure function in `lib/customer/` (e.g. `static_transfer_note.dart`). The copy button copies **only the items text** (`{items}`), not the "Nội dung chuyển khoản:" prefix.

## Non-goals

The cart change (`qr-static-customer-cart-choice`), any restaurant-side UI, a printable shop QR (QS6), a countdown.

## Tests written with the change (fake `PaymentClient`, repository test hooks)

- awaiting: shows the exact `vi` message with `25.000 VNĐ`, a `QrImageView` whose data is the payload it was given, the bank name, account number, holder, the download button (a fake `savePng` injected by constructor: one test with `canSavePng` true, one with false hiding the button).
- the QR data contains no amount: the payload given to the fake has no tag 54, and the page never builds a QR from anything but `staticQrPayload`.
- the transfer-content builder: `[2 x Xôi thịt + Thêm chả, 1 x Trà đá]` gives `2 Xoi thit (Them cha), 1 Tra da`; accents and `đ` removed; an empty topping list adds no brackets; a long order is cut at a whole item with `...` within 50 characters; a name with only symbols or control characters cannot break the line; the page shows it and the copy button puts exactly that text on the clipboard (fake clipboard channel).
- download tap calls `savePng` once with PNG bytes and the fixed file name; a false result shows the failure text.
- switch to cash success / 409 refresh / failure, like the existing page.
- order flips to `paid`, `preparing` or `finished` -> paid view; to cash `preparing` -> cash view; to `cancelled` -> cancelled view; `paid` back to `awaiting_payment` -> the QR view again; all non-awaiting views with no QR.
- info failure shows Retry; Retry refetches.
- banner lists and opens the right page for a static order; a `finished` one is not listed.
- no overflow at 360 px for text scales 1.0 to 2.0; no pending timers after `pumpAndSettle`.
- message renders in `en` and `ja` with the amount present.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates | `make analyze`, `make format-check`, `make boundaries` (gates) |
| QR only from the server's payload; amount from the stored order | `code-reviewer` (review) |
| A banking app scans the screen QR and the saved PNG and asks for the amount; the message reads right; download works on desktop Chrome and a phone | owner acceptance, "unverified" until done |
| The owner's wording (vi) is accepted | owner acceptance |
