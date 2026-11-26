---
task: status-finished-contract
status: passed
p0: 0
p1: 0
---

# Security review: status-finished-contract

Reviewer: security-reviewer, run on the contract text in `CLAUDE.md` (the card has `securityReview: required`). Read-only; nothing run. Round 1: P0 0, P1 0, P2 5. Round 2: P0 0, P1 0, P2 2 (one fixed, one accepted).

## Round 1 findings (all P2, all fixed in the text)

1. **Lockout freezes the kitchen.** PATCH is now a staff route, so five wrong attempts a minute from any device block every status change and cancel for 60 seconds. **Fixed:** stated in the 429 bullet; how failed session tokens are counted is an open point for `staff-login-contract`.
2. **An expiry-cancelled order stayed revivable after a staff cancel.** `cancelled -> cancelled` was a no-op that kept `paymentDueAt`. **Fixed:** with `paymentDueAt` set it is a real staff cancel that clears it and ends the customer's renew/switch window (planner's recommendation, the owner may overrule); with none it is the plain 200 no-op.
3. **PATCH write not guarded.** **Fixed:** one `UPDATE ... WHERE id = ? AND status = <status just read>`, 409 when no row matched.
4. **Rollback reopens an unauthenticated PATCH.** **Fixed:** the deploy-order text says an old program has no staff check, to restore the dated backup together with it and not to leave it on a reachable network.
5. **Dangling session reference.** **Fixed:** names `staff-login-contract` and the order staff check, then body, then lookup (no 404 before the gate). SF19 wording added: the record holds session or device identifiers only, never the password or the token.

## Round 2

- **N1 (P2) fixed:** the `switch-to-cash` and `staff-switch-to-cash` table rows did not say `bank_transfer`, so a cash order held in `awaiting_payment` by staff could in principle be pushed to `preparing` by a customer route. All five payment rows now say they answer 409 for a cash order, and the backend card must test it.
- **N2 (P2) accepted:** the global lockout reaching the kitchen stays a known weak point, stated in the text and left open for `staff-login-contract`.

## Checked and clean

PATCH is closed to unauthenticated callers; the gate runs before the body and the lookup, and before the no-op decision; no path lets a customer route revive a staff-cancelled order (a staff cancel clears the deadline, cash orders never have one); POST cannot create `finished` or `cancelled` orders; the sweep and lazy check only touch `awaiting_payment` orders with a deadline; the stale-tab text fails closed (401 / 400); no secret or credential in the diff; nothing in the text would make an implementer log the password or token.

## Needs confirmation in a real environment

That the implemented PATCH really does the gate, then body, then lookup in that order, with a guarded UPDATE (checked in the `status-finished-backend` review); the staff-session and rate-limit behaviour once `staff-login-*` ships; a stale restaurant tab after deploy.
