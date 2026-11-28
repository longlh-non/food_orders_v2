---
task: status-finished-backend
status: passed
p0: 0
p1: 0
---

# Security review: status-finished-backend

Reviewer: security-reviewer (the card has `securityReview: required`). Read-only; no code run. **P0 0, P1 0, P2 2** (both already-known residuals, deferred).

## Checked and clean

1. **Staff check first.** `_gate.check(req)` is the first statement of the PATCH handler, before the body is read, before the status validation and before the lookup, so a 400 or 404 cannot leak validity or existence to an unauthenticated caller. The same `StaffGate` instance is shared with the menu routes, so failures on PATCH and the other staff routes share one counter and one lock; 401/403/429 (with `Retry-After`) and the fixed strings are identical. Only `router.patch('/orders/<id>')` writes `status`; other methods and trailing paths do not reach it. Nothing else writes `orders.status` without a gate except the internal sweep and the payment routes.
2. **Nothing got looser for an unauthenticated device.** The customer routes (`switch-to-cash`, `renew-payment`, `payment-qr`) use unchanged predicates that all require a `bank_transfer` order; only the PATCH handler changed. A cancelled order can come back only through `renew-payment` or `switch-to-cash` (expiry-cancelled transfer orders, 15-minute window) or `staff-switch-to-cash` (staff, no limit). PATCH on a cancelled order is 409 for every method, which is tighter than before (cancelled cash orders used to move freely). Option A is correct and guarded: after a staff cancel of an expired order its deadline is gone, so renew and switch-to-cash answer 409.
3. **Atomicity.** After the one `await` that reads the body there is no `await` between the lookup and the write; sqlite is synchronous and the sweep is a synchronous timer callback, so nothing can interleave. The `AND status = <read status>` guard is a second layer: no row matched means 409, so a stale read cannot overwrite a state a payment route just set.
4. **Cash order in `awaiting_payment`.** The sweep and lazy expiry filter on `payment_method = 'bank_transfer'`, and all five payment routes need a transfer method, so a cash order is never touched and answers 409; PATCH never writes the method; a transfer order cannot be PATCHed to `awaiting_payment`; a legacy NULL method reads as cash.
5. **Migration step 9.** Constant SQL with no interpolation, one transaction with rollback and rethrow, guarded by the version (idempotent), edits no shipped step, correct mapping, payment columns and row order untouched. The CSV neutralisation of a leading `=`, `+`, `-` or `@` is intact; the reports are a plain rename.
6. **Errors and logging.** The new 409 and 400 strings are fixed and never echo request or order data; no new logging.
7. **Backend deployed alone fails closed.** An old restaurant page sends empty headers and gets 401 (or 403 when staff routes are disabled); old apps sending `ready`/`delivered` get 400; no unsafe state is reachable. The effect is availability: each empty-header retry counts as a wrong attempt, so five in 60 seconds lock the staff routes for a minute (the known, accepted lockout). The card says not to deploy it alone.

## P2 residuals (deferred, written in the review report)

- PATCH does not run the lazy expiry first: for up to about 15 seconds an overdue but unswept transfer order can be moved by staff to `preparing` or `finished`, and the move clears its deadline. Staff behind the gate are allowed these moves by design and no money moves in the app. Optional hardening: call `_expireIfOverdue(id)` before the lookup.
- `awaiting_payment -> awaiting_payment` on an overdue order returns 200 with the stale status; harmless, fixed by the same call.

## Needs confirmation in a real environment

Step 9 on a copy of the owner's real `orders.db` after a dated backup; the restaurant page's 401/403/429 handling (restaurant card).
