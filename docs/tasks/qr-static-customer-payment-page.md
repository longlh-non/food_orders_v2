---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [qr-static-shared-model-client, qr-static-customer-png-download, qr-static-l10n-strings, status-finished-customer]
---

# Customer: the payment page for the owner's QR image

Planned 2026-11-26, revised after the `status-finished-*` chain (`finished` replaces `ready`/`delivered`; staff may set statuses; a cancelled order is final), and again after the owner's design change (2026-11-26): the QR is a **third-party payment service's image** served from the images folder; the page shows no bank or account text and draws no QR. Decisions QS2, QS3, QS7, QS11, QS13 in `qr-static-api-contract`. The owner's message and the download button are the point of this card.

## Sources

`lib/customer/pages/payment_qr_page.dart` (look, listening to `OrderRepository`, switch to cash; its status `switch` as `status-finished-customer` left it), `lib/customer/pages/menu_page.dart` (the "Your orders" banner and status snackbars, and how the menu tile loads its picture with `Image.network`, its placeholder and error handling), `lib/customer/state/my_orders.dart`, `lib/customer/api/payment_client.dart` (`fetchInfo` gives `staticQrImage`), `lib/shared/api/order_api_client.dart` (`imageUrlFor`), `lib/customer/download/image_download.dart`, `lib/shared/money.dart`, `docs/tasks/done/customer-payment-qr-page.md`.

## Goal

A `StaticQrPaymentPage(orderId)` in `lib/customer/pages/static_qr_payment_page.dart`, a **separate file** from the existing page (no countdown, no renew question). It watches the order in `OrderRepository` with `ListenableBuilder`, and the info once via `PaymentClient.fetchInfo`.

By state:

1. **`awaiting_payment`, method static:** only these things, top to bottom:
   - the message `paymentStaticMessage(formatVnd(order.total))` (vi: "Vui lòng chuyển khoản 25.000 VNĐ vào tài khoản dưới đây hoặc quét mã được dán tại quán sau đó thông báo với chủ quán. Rất chân thành cảm ơn!");
   - the **QR image**: `Image.network(OrderApiClient.imageUrlFor(info.staticQrImage))` (never a hand-built URL), with the same placeholder while loading and on error as the menu tile; with the semantics label `paymentStaticQrSemantics`; sized to fit a 360 px phone and scale-able, not cropped (`BoxFit.contain`);
   - the **transfer-note line** (QS11: `paymentStaticReference(items)`, the order's items as `quantity name (toppings)` joined by `, `, accents removed, cut to 50 characters at a whole item, built from `order.items` in the repository, selectable) with a **"Sao chép nội dung"** button using `Clipboard` that copies **only the items text**, not the "Nội dung chuyển khoản:" prefix;
   - the **"Tải mã QR"** button (hidden when `canSaveImage` is false) that calls `saveImageFile` with the image URL and the picture name; a false result shows the short failure text;
   - the line that tells them to inform the shop after paying;
   - the "switch to cash" note and button (reuse the existing wording and `OrderRepository.switchToCash`, with the same 409 handling: refresh from the repository).
   - **No** bank name, account number or account holder text anywhere (they are not in the contract for this option), and no `qr_flutter`.
2. **Paid** (`paid`, `preparing` or `finished`, method static): "payment received" view, no QR, back-to-menu button.
3. **Switched to cash** (by customer or staff): the existing cash view; no QR.
4. **`cancelled`:** a plain cancelled message and a back-to-menu button (no question, no renew; a cancelled order is final).
5. **Info failure** (`fetchInfo` fails, or `staticQrImage` is absent or null because the owner removed the setting or the file, or the **image fails to load**): the amount message stays visible; the QR area is replaced by a short message (reuse the existing "picture could not be loaded" placeholder text if one exists, otherwise the key from `qr-static-l10n-strings`) and a **Retry** button. Retry refetches the info and reloads the image (a new `Image.network` key). The transfer-note line, the copy button and switch to cash stay usable in this state; the download button is hidden because there is no file to save.

Because staff may set statuses (SF6), the page follows **any** change from the repository without a stale view: a static order staff moved to `preparing`, `paid` or `finished` shows state 2; one moved back to `awaiting_payment` (allowed for static from a non-cancelled status) shows state 1 again.

The amount shown is `order.total` from the repository (what the server stored), never recomputed from the cart. Leaving the page never changes the order. No `Timer` and no new state class.

Menu banner: an `awaiting_payment` static order of this session is listed and opens this page (an existing-method order still opens the old page). The banner's "ended" rule (`finished`, `cancelled`) is the one from `status-finished-customer`; `paid` counts as live and the status snackbar names it with the localized label. A static order never shows an "expired" state.

The text builder is a small pure function in `lib/customer/` (e.g. `static_transfer_note.dart`).

## Non-goals

The cart change (`qr-static-customer-cart-choice`), any restaurant-side UI, a printable shop QR (QS6), a countdown, drawing or decoding a QR, bank or account text.

## Tests written with the change (fake `PaymentClient`, repository test hooks, `Image.network` replaced by the test image provider the existing menu tests use)

- awaiting: shows the exact `vi` message with `25.000 VNĐ`, an image whose URL is the `imageUrlFor` result for the file name the fake client gave, the transfer-note line, the copy button, the download button (a fake `saveImageFile` injected by constructor: one test with `canSaveImage` true, one with false hiding the button).
- no bank name, account number or holder text appears, and no `QrImageView` is in the tree.
- the transfer-content builder: `[2 x Xôi thịt + Thêm chả, 1 x Trà đá]` gives `2 Xoi thit (Them cha), 1 Tra da`; accents and `đ` removed; an empty topping list adds no brackets; a long order is cut at a whole item with `...` within 50 characters; a name with only symbols or control characters cannot break the line; the page shows it and the copy button puts exactly that text on the clipboard (fake clipboard channel).
- download tap calls `saveImageFile` once with the image URL and the picture name; a false result shows the failure text.
- switch to cash success / 409 refresh / failure, like the existing page.
- order flips to `paid`, `preparing` or `finished` -> paid view; to cash `preparing` -> cash view; to `cancelled` -> cancelled view; `paid` back to `awaiting_payment` -> the image view again; all non-awaiting views with no image.
- info failure (fetch throws, `staticQrImage` null, image load error) shows the message and Retry, the amount message stays, download hidden; Retry refetches and shows the image when it works.
- banner lists and opens the right page for a static order; a `finished` one is not listed.
- no overflow at 360 px for text scales 1.0 to 2.0; no pending timers after `pumpAndSettle`.
- message renders in `en` and `ja` with the amount present.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates | `make analyze`, `make format-check`, `make boundaries` (gates) |
| Image only from the server's `staticQrImage` through `imageUrlFor`; amount from the stored order; no bank text | `code-reviewer` (review) |
| The owner's own payment app scans the QR image on screen and the saved file; the message reads right; download works on desktop Chrome and a phone | owner acceptance, "unverified" until done |
| The owner's wording (vi) is accepted | owner acceptance |
