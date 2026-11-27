---
executor: task-executor
scopes: [shared]
workKinds: [flutter, documentation, quality-gate]
blockedBy: [qr-static-api-contract, status-finished-shared, staff-login-l10n]
---

# Strings for the QR-image transfer option, in all 10 languages

Planned 2026-11-26, revised: the cancel button and picker strings come from `status-finished-shared` (so there is **no cancel key here**), the login strings from `staff-login-l10n`, and the "Đã giao" key is gone. Revised again for the owner's image-QR design change (2026-11-26): the page shows no bank or account text, so **no label keys for bank name, account number or account holder** are added. Runs after both so no two cards ever edit the same ARB files at once. **Placed before the UI cards** because `PaymentMethod.localized` and the screens can't compile without their keys; unused keys are harmless. Independent of the backend cards.

## Sources

`lib/shared/l10n/app_*.arb` (10 files, `app_vi.arb` is the template with `@key` metadata), `lib/shared/l10n/README.md`, `test/shared/arb_completeness_test.dart`, `CLAUDE.md` "Languages" (adding a string = all 10 ARBs, regenerate with `flutter gen-l10n`, commit the generated files), and the existing menu-picture placeholder text and payment-page keys (to reuse).

## Goal

Add these keys (names are suggestions; keep the existing naming style) to **all 10** ARB files and regenerate:

- `paymentMethodBankTransferStatic`: "Chuyển khoản" (QS5). Used for the cart choice and the restaurant card.
- `paymentStaticMessage` with placeholder `{amount}` (a String, already `formatVnd`-formatted by the caller): the owner's text, **verbatim**: "Vui lòng chuyển khoản {amount} vào tài khoản dưới đây hoặc quét mã được dán tại quán sau đó thông báo với chủ quán. Rất chân thành cảm ơn!" The owner's "(then let them download the QR code)" is the download button, not text (QS7).
- `paymentStaticDownload`: "Tải mã QR". `paymentStaticDownloadFailed`: e.g. "Không tải được mã QR".
- `paymentStaticImageFailed`: e.g. "Không tải được mã QR. Vui lòng thử lại." for the page's info-failure state (QR image missing or failed to load). **Reuse** an existing "could not load / try again" key and the existing Retry key if their meaning fits; add this one only if none does (the executor lists what it reused). No new "Retry" key.
- `paymentStaticPaidMessage` / cash switched / unavailable texts: **reuse** the existing payment-page keys where the meaning is the same; add a key only where it isn't (the executor lists what it reused).
- `paymentStaticAwaitingStaff`: e.g. "Sau khi chuyển khoản, hãy báo với chủ quán để xác nhận." (suggested; owner approves). A restaurant-side counterpart only if the existing "Chưa thanh toán" text doesn't fit (it should).
- `paymentStaticQrSemantics`: the accessibility label of the QR image.
- `paymentStaticReference` with placeholder `{items}` (QS11): e.g. "Nội dung chuyển khoản: {items}" (owner approves). `paymentStaticReferenceCopy`: "Sao chép nội dung"; `paymentStaticReferenceCopied`: "Đã sao chép".
- **Status label (QS13):** `statusPaid` (the key style `status-finished-shared` used, e.g. `statusFinished`): "Đã thanh toán", used by `OrderStatus.localized`.

`vi` text for the message is the owner's; every other text is a draft. The other 9 languages are machine drafts: record them as "unverified" in `lib/shared/l10n/README.md` (the review log is updated in `qr-static-docs`).

Keep price words out of the sentence: the amount arrives already formatted ("25.000 VNĐ"), in every language.

## Non-goals

Using the keys in any screen; backend text (LANG6); the cancel, picker, finished and login keys (already added by their own cards); bank, account or holder labels.

## Tests written with the change

`test/shared/arb_completeness_test.dart` must pass unchanged. Add one test that `paymentStaticMessage` in `vi` renders the owner's exact sentence with `25.000 VNĐ`, and that the placeholder appears in all 10 languages' text.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| All 10 files have all keys; generated files are in sync and committed | `make test` (arb_completeness_test), `make analyze` (gates) |
| Vi sentence is verbatim | the new test, plus `code-reviewer` comparing with the request quoted in `qr-static-api-contract` |
| Format | `make format-check` exit 0 (gate) |
| Wording of the 9 machine drafts and of the new vi helper lines | owner acceptance, "unverified" until a fluent speaker checks |
