---
executor: task-executor
scopes: [docs]
workKinds: [documentation, quality-gate]
blockedBy: [qr-static-customer-cart-choice, qr-static-restaurant-orders, status-finished-docs, staff-login-docs, order-status-audit-log]
---

# Docs: runbook, language record and deploy notes for the owner's QR image transfer

Planned 2026-11-26, revised after the `status-finished-*` chain and the staff-login and audit-log plans: schema **step 10** is this feature's (9 = status, 11 = staff sessions, 12 = status log), `finished` instead of `delivered`, no cancel or "Đã giao" button of its own, staff actions use the login session. Revised again for the owner's image-QR design change (2026-11-26): the QR is a third-party payment service's **image** the owner copies into the images folder and names in the new `STATIC_QR_IMAGE` setting; no bank text on the page. It runs last, so the runbook can say which steps a first start applies. **Editing `CLAUDE.md` in this card needs the owner's explicit approval for this task** (the contract text was approved in `qr-static-api-contract`; this card only touches the "Languages" wording status, the "Layout" tree and "Known limitations"). Without that approval, do the other files and list the CLAUDE.md lines for the owner instead.

## Sources

`docs/runbook-local.md` (Shop and bank settings, "Language review log", and the sections `status-finished-docs`, `staff-login-docs` and `order-status-audit-log` added), `docs/deploy.md` (release steps, backup before schema steps, Docker update steps, the env file `/etc/food-orders/backend.env`, the data folder `/var/lib/food-orders/data`; it may carry uncommitted owner edits: run `git status` first), `lib/shared/l10n/README.md`, `CLAUDE.md`, `backend/lib/shop_settings.dart`.

## Goal

- `docs/runbook-local.md`: a short owner section "Chuyển khoản bằng mã QR của dịch vụ thanh toán" (the owner's own heading wording is fine), with numbered steps:
  1. Get the QR image from the payment service. Rename it to the picture-name rule: lowercase letters, digits and `-`, ending `.png`, `.jpg`, `.jpeg` or `.webp`, at most 1 MiB (for example `qr-thanh-toan.png`). Never put it in the repo.
  2. **Local:** copy it into `backend/data/images/` (`cp ~/Pictures/qr-thanh-toan.png backend/data/images/`).
  3. Set `STATIC_QR_IMAGE` with the file name: add it to the start command's `read` loop (type the name at the prompt; it is not a secret, but the runbook keeps all settings in one place), then restart the backend.
  4. Check the backend prints `static QR transfer: enabled` (if it says `disabled (missing or invalid: STATIC_QR_IMAGE)`: the name breaks the rule or the file is not in the folder).
  5. Check `http://customer.local/api/images/<file>` shows the picture.
  6. Open the customer app, add an item to the cart: the "Chuyển khoản" choice is now selectable.
  7. The owner scans the QR on the payment page, and the downloaded file, with their own payment app. **Unverified by agents** (they can't scan).
  - plus: how it differs from the first transfer option (no deadline, never expires, the image is the owner's, no account text on the page), what staff do after the customer says they paid (tap "Đã nhận chuyển khoản", the order becomes "Đã thanh toán", then "Đã phục vụ"; signed in, no password prompt), the cancel button and the status picker as on any order, how to try it with the demo (`lib/dev/demo.dart`), the first-start reminder (**steps 9 to 12 apply on the first start of the new backend**: stop the backend, dated backup, then start), and the **backup note: the images folder holds the QR image, so it is backed up together with `orders.db`**.
  - Changing the image: save the new file under a **new file name**, change `STATIC_QR_IMAGE`, restart (browsers keep the old picture up to 5 minutes under the same name).
- `docs/deploy.md`:
  - in the release checklist and the Docker update steps, make the existing step line say "steps 9 to 12 run on the first start: dated backup first".
  - a **new env var** `STATIC_QR_IMAGE` (the one setting this feature adds; it uses none of the `BANK_*` values): in the Docker section, copy the image to `/var/lib/food-orders/data/images/` on the server, `sudo chown 10001` it (the container user) and make it readable (`chmod 644`; the owner types these, agents never run `sudo`), add the line `STATIC_QR_IMAGE=qr-thanh-toan.png` (placeholder name) to `/etc/food-orders/backend.env`, then restart the backend container (the exact existing restart command in that guide), and check the container log for `static QR transfer: enabled`. For the systemd path, the same value goes in the service's environment file. State that the folder is covered by the existing backup step.
  - **Images folder safety (security review of `qr-static-api-contract`):** the folder is public and holds only pictures; never point `IMAGES_DIR` at the data folder and never put database backups there. The backend only reads the images folder, so in the Docker section mount it read-only for the backend if the compose layout allows it (or say that host write permission on the folder is owner-only), and say that whoever can write that folder or change `STATIC_QR_IMAGE` can swap the payee QR so customers pay someone else. For a changed QR use a new file name, change `STATIC_QR_IMAGE` and restart (browsers cache images for up to 5 minutes).
- `lib/shared/l10n/README.md` and the "Language review log": the new keys and that the 9 non-vi texts are machine drafts, unverified; the new vi helper lines await owner acceptance.
- `CLAUDE.md` (with approval): add `lib/customer/download/` (`image_download*.dart`) and `static_qr_payment_page.dart` to the Layout tree; add `STATIC_QR_IMAGE` where the settings are listed (if the contract card has not already); the wording-status sentence for the new strings; Known limitations: "the QR image proves nothing: staff confirm by looking at the payment service or bank app; a customer can type any amount" and "saving the QR image is unverified on iOS Safari".
- Also document: the new status `paid` and the backend restart-before-apps-reload order, the suspended old transfer and how to switch it back on (both constants, QS12/QS14), the staff choices for the new transfer order (paid, switch to cash, cancel; `finished` through the picker), the transfer note (items, no accents, 50 characters, QS11).

## Non-goals

Any code, the printable shop QR page, the staff-login and audit-log docs (their own cards).

## Tests

None. Re-read each command in the new text against the files it names.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Text matches the shipped behaviour and names real files, folders and the startup line | `code-reviewer` (review) |
| No `ready` / `delivered` and no step number clash (9 status, 10 method, 11 sessions, 12 log) | `grep` in the review |
| No real env value, secret or personal value appears in the text (only the placeholder image name) | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| The owner can follow the runbook section on their machine and the server | owner acceptance, "unverified" until done |
