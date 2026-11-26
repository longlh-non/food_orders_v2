---
executor: task-executor
scopes: [docs]
workKinds: [documentation, quality-gate]
blockedBy: [qr-static-customer-cart-choice, qr-static-restaurant-orders, status-finished-docs, staff-login-docs, order-status-audit-log]
---

# Docs: runbook, language record and deploy notes for the QR without an amount

Planned 2026-11-26, revised after the `status-finished-*` chain and the staff-login and audit-log plans: schema **step 10** is this feature's (9 = status, 11 = staff sessions, 12 = status log), `finished` instead of `delivered`, no cancel or "Đã giao" button of its own, staff actions use the login session. It runs last, so the runbook can say which steps a first start applies. **Editing `CLAUDE.md` in this card needs the owner's explicit approval for this task** (the contract text was approved in `qr-static-api-contract`; this card only touches the "Languages" wording status, the "Layout" tree and "Known limitations"). Without that approval, do the other files and list the CLAUDE.md lines for the owner instead.

## Sources

`docs/runbook-local.md` (Shop and bank settings, "Language review log", and the sections `status-finished-docs`, `staff-login-docs` and `order-status-audit-log` added), `docs/deploy.md` (release steps, backup before schema steps, Docker update steps; it may carry uncommitted owner edits: run `git status` first), `lib/shared/l10n/README.md`, `CLAUDE.md`.

## Goal

- `docs/runbook-local.md`: a short owner section "Chuyển khoản không kèm số tiền": how it differs from the first transfer option, what staff do after the customer says they paid (tap "Đã nhận chuyển khoản", the order becomes "Đã thanh toán", then "Đã phục vụ"; signed in, no password prompt), that it never expires, the cancel button and the status picker work as on any order, how to try it with the demo (`lib/dev/demo.dart`), and the first-start reminder: **steps 9 to 12 apply on the first start of the new backend** (stop the backend, dated backup, then start).
- `docs/deploy.md`: in the release checklist and the Docker update steps, make the existing step line say "steps 9 to 12 run on the first start: dated backup first". No change to env vars: it uses the same four `BANK_*` values.
- `lib/shared/l10n/README.md` and the "Language review log": the new keys and that the 9 non-vi texts are machine drafts, unverified; the new vi helper lines await owner acceptance.
- `CLAUDE.md` (with approval): add `lib/customer/download/` and `static_qr_payment_page.dart` to the Layout tree; the wording-status sentence for the new strings; Known limitations: "the static QR proves nothing: staff confirm by looking at the bank app; a customer can type any amount" and "saving the QR as a PNG is unverified on iOS Safari".
- Also document: the new status `paid` and the backend restart-before-apps-reload order, the suspended old transfer and how to switch it back on (both constants, QS12/QS14), the staff choices for the new transfer order (paid, switch to cash, cancel; `finished` through the picker), the transfer note (items, no accents, 50 characters, QS11).

## Non-goals

Any code, the printable shop QR page, the staff-login and audit-log docs (their own cards).

## Tests

None. Re-read each command in the new text against the files it names.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Text matches the shipped behaviour and names real files | `code-reviewer` (review) |
| No `ready` / `delivered` and no step number clash (9 status, 10 method, 11 sessions, 12 log) | `grep` in the review |
| No env var, secret or personal value appears in the text | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| The owner can follow the runbook section on their machine | owner acceptance, "unverified" until done |
