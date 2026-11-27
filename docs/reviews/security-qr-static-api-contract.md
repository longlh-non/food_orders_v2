---
task: qr-static-api-contract
status: passed
p0: 0
p1: 0
---

# Security review: qr-static-api-contract

Reviewer: security-reviewer, run on the contract text in `CLAUDE.md` (the card has `securityReview: required`). Read-only; nothing run. Round 1: P0 0, P1 0, P2 4. Round 2 (after the owner changed the QR to an image): P0 0, P1 0, P2 2. All fixed or accepted in the text.

## Round 1 (P2, all stated in the text)

1. **Unbounded customer switch-to-cash on static orders.** A static order has no deadline, so any device on the wifi can flip it to cash for as long as it stays `awaiting_payment`, including an order whose customer has already transferred and is waiting for staff (staff then get 409 on `confirm-payment` and sort the real transfer out by hand). **Accepted and written** into the accepted-risk bullet and Known limitations (part of the existing no-authentication risk, now without a time window).
2. **Never-expiring static orders and the 10,000-order cap.** Unauthenticated POSTs of static orders never expire, count toward the cap (like cash orders) and inflate the staff badge until cancelled by hand. **Accepted and written**, no mitigation now.
3. **Staff back-move to `awaiting_payment`** makes a finished or paid static order customer-switchable again. **Accepted and written** (needs a prior staff action).
4. **Step 10 rebuild detail.** **Fixed:** `rowid` order, all columns incl. `payment_due_at`, the new CHECK, dropped hand-made indexes stated, backup advice and "steps 9 to 12 run together".

## Round 2 (image design)

1. **P2 fixed: "the images folder holds only pictures".** The image route checks name, extension, size, regular file and symlinks but not content, so a database backup renamed `x.png` in `IMAGES_DIR` would be served publicly. The text now says the folder is public, holds only public pictures, is never the data folder and never holds backups.
2. **P2 fixed: substitution trust root.** Whoever can write `IMAGES_DIR` or change `STATIC_QR_IMAGE` can swap the payee QR so customers pay someone else. The text names that as the trust root (the owner or whoever controls the server), says there is no upload route, and says the deploy docs must keep the backend's access to the folder read-only (the note was added to `qr-static-docs`). The 5-minute browser cache on images is documented, with the advice to use a new file name for a changed payee QR.

## Checked and clean

`POST /orders` strict method/status pairing (no client can create `paid`, `finished` or an unpaid order that skips payment; a differently spelled or null method is 400; unknown fields are 400, so a client cannot send `paymentDueAt`); the check order 400, then suspension (`bank_transfer` only), then not-set-up, with fixed messages that echo nothing; PATCH never changes the method, so no route turns a static order into an old `bank_transfer` order; `renew-payment` and `payment-qr` answer 409 for static and a cash `awaiting_payment` order answers 409 on every payment route; a cancelled static order cannot use the expired-order switch (it has no deadline); `confirm-payment` for a static order is behind the staff check and sets `paid`; the sweep and lazy check ignore static orders; the guarded UPDATE and cancelled-final rules hold with the new targets; `GET /payment-info` stays `no-store`; `staticQrImage` is only a file name and the QR image is public by design with no per-order data; `nosniff` and extension-based content types mean a renamed HTML file is not rendered; no traversal path through the setting or the route; a missing image disables the option and breaks no existing order; the items text is built in the app, never sent to the server; no secret, env var carrying a secret, or log of one.

## Needs confirmation in a real environment

That a banking or payment app opens a transfer from the image QR and lets the customer type an amount; the same-origin fetch and Blob download on iOS Safari; that `docs/deploy.md` really keeps the images folder read-only for the backend; a migration run of steps 9 and 10 on a copy of a real database.
