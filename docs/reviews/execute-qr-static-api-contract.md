---
task: qr-static-api-contract
status: passed
p0: 0
p1: 0
---

# Review: qr-static-api-contract

Changed: `CLAUDE.md` (owner-approved for this task only, 2026-11-26) and the card (an "Owner decisions" table and decisions QS15 to QS17). Docs only: no code, no runbook, no l10n README, no `dev/**` or `deploy/**`; `docs/deploy.md` (the owner's earlier uncommitted edit) was not touched. The contract now describes, as **agreed, not built**: the second bank-transfer option `bank_transfer_static` (no deadline, no expiry, no renew, staff confirm by hand), the new status `paid`, the suspension of the old `bank_transfer` (hidden in the cart, 503 "Bank transfer is suspended" in `POST /orders`), schema step 10 (rebuild of `orders` for the `payment_method` CHECK), the customer's transfer note built from the order's items, and the **QR as an image**: a third-party payment service's QR file in the images folder, named by the new setting `STATIC_QR_IMAGE` and returned as `staticQrImage` by `GET /payment-info`.

## Design change during the review (owner, 2026-11-26)

After round 1 the owner said the QR is a third-party payment service's code, not a bank QR. The planned backend-built payload (`vietQrStaticPayload`, tags 01=11, no 54, no 62, `staticQrPayload`, `qr_flutter`) was removed from the contract and replaced by the image design above. The owner chose: the image lives in the server images folder; the page shows no account text; the download saves the image file itself. QS3 is marked superseded; QS4, QS5 (enable condition) are revised; QS15 to QS17 are new. The downstream `qr-static-*` cards were rewritten to match (not part of this task's diff).

## Gates

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | re-run by the main session after the last fixes |
| `make boundaries` | 0 | re-run by the main session after the last fixes |
| `make check` | 2 | stops at `make analyze`: 30 known infos (`deprecated_member_use`), no Dart changed; the test and backend gates did not run. Not claimed as passed. |

## Round 1 (code-reviewer): P0 0, P1 1, P2 7, all fixed

- **P1 fixed:** the Notifications exception said a pre-existing transfer order rings when it becomes `preparing`, but the new method ends in `paid`. It now says `preparing` or `paid`, and that this is the only way the chime rings for `paid`.
- **P2 fixed:** the customer banner says which page a static order opens (the new no-amount page); the cancelled-final 409 wins for a cancelled cash order moved to `paid`; the 50-character cap says what happens when the first item alone is longer (cut inside it, end with `...`); the muddled reference to the old transfer bullet now names the heading; step 10 copies in `rowid` order, keeps all columns including `payment_due_at`, and lists the three methods in the CHECK; the "same code as the one posted in the shop" claim was replaced by the image text and the owner's printed code as the trust anchor.

## Round 2 / re-review (code-reviewer): P0 0, P1 0, P2 5, four fixed, one accepted

- Fixed: one page order stated once (message, QR image, download button, note line, then the accepted helper line and an optional switch-to-cash button); the 5-minute image cache caveat (use a new file name for a changed payee QR); "paid but not confirmed" reworded to "the customer has transferred but staff have not yet confirmed" (the status is still `awaiting_payment`); a note that the 409 "Use the payment routes" for a cancelled static order is the message shared with the old flow.
- Accepted: where the `static QR transfer:` startup line is built (the settings class does not know the images folder) is for the backend card to decide.

## Security review: see `security-qr-static-api-contract.md`.

## Deferred (written down)

- `qr-static-docs` must say the backend needs no write access to the images folder (read-only mount or owner-only host permissions); the note was added to that card.
- The backend and client cards must test: the file-exists check on each `GET /payment-info`, the two 503 texts and their check order, the schema step 10 migration on a copy of a real database, the 409 on every payment route for a cash `awaiting_payment` order, and the static customer switch-to-cash.

## Unverified (owner acceptance)

Nothing is implemented, so every rule is "agreed, not built". Whether the third-party QR image opens a transfer in the real payment app and lets the customer type the amount; whether the "Tải mã QR" download works on iOS Safari; the Vietnamese helper lines and the other nine languages (machine drafts).
