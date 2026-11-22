---
task: backend-order-payment-transitions
status: passed
p0: 0
p1: 0
---

# Execute review: backend-order-payment-transitions

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). The security review is in `docs/reviews/security-backend-order-payment-transitions.md`.

## Candidate

- `CLAUDE.md`:
  - API table rows for `switch-to-cash`, `renew-payment`, `staff-switch-to-cash` and `confirm-payment`;
  - the PATCH 409 cell now covers cancelled `bank_transfer` orders;
  - the new "Payment expiry and the payment routes" rules.
- `backend/lib/orders_api.dart`: the four routes, `expireOverdue()`, `startExpirySweep()` (every 15 s), `close()`, a lazy expiry check on the payment routes, and conditional UPDATEs (409 when 0 rows change).
- `backend/bin/server.dart`: starts the sweep and adds a SIGINT handler.
- `backend/test/orders_payment_transitions_test.dart` (new, 36 tests).

## Gates (first round)

Run by the executor in this session.

| Command | Exit code | Output tail |
|---|---|---|
| `make backend-analyze` | 0 | `No issues found!` |
| `make backend-test` | 0 | `+481: All tests passed!` (the first run had 1 failure in the new test's own helper, fixed before the final run) |
| `make format-check` | 0 | `Formatted 67 files (0 changed)` |
| `make analyze` | 0 | `No issues found!` |
| `make test` | 0 | `+343: All tests passed!` |
| `make boundaries` | 0 | `boundaries: ok` |

## Findings

P0: none. P1: none.

The reviewer confirmed:
- the routes, responses and check order match the card;
- expiry and the 15-minute window are inclusive (`now <= due + 15 min`), compare UTC instants, and store milliseconds;
- the staff-cancel marker is reliable;
- races resolve to the first request (no `await` between read and write, plus conditional UPDATEs);
- there is one SSE event per transition and none on a 409;
- `CLAUDE.md` matches the code;
- the timer lifecycle is right and leaks no timer;
- the app client isn't changed, which is acceptable only while `shared-order-payment-model-and-client` and `customer-payment-client` stay open (invariant 3).

P2 (items 1, 2, 4 and 5 are fixed in "Fix round 1" below, together with the security P2s):

1. **The sweep can crash the backend in a loop.** It decodes every waiting order (`orders_api.dart:70, 93-101`), and the timer only catches `SqliteException`. One hand-edited row with broken `items_json` would kill the backend 15 s after every restart.
2. **The SIGINT handler (`server.dart:78-83`):**
   - if something inside it throws, `exit(0)` is never reached and Ctrl-C does nothing;
   - a second Ctrl-C runs it twice;
   - the exit code changes from 130 to 0.
3. `GET /orders` and the stream don't run the lazy expiry, so an overdue order shows `awaiting_payment` for up to 15 s. Accepted. **Follow-up:** the app cards treat `paymentDueAt <= now` as expired in the UI (noted in `restaurant-orders-show-payment-method` and `customer-payment-qr-page`).
4. The sweep and SSE tests use fixed sleeps and could flake on a slow machine. Use bounded polling.
5. Exact-boundary tests are missing (+15:00 for renew and for the customer switch).
6. The 503 test setup is roundabout. Deferred (cosmetic).

## Unverified (owner acceptance)

- A real 5-minute expiry and a renew on the running backend.
- The new routes through Caddy.
- Ctrl-C behaviour under `dart run`.

## Fix round 1 and Re-review 1

The P2s were fixed in one batch before archiving. The sweep reads only `id` and `payment_due_at`, catches errors per row and in the timer, and publishes only rows it changed. The SIGINT handler has a re-entry guard and ends with `try/finally exit(130)`. The tests poll instead of using fixed sleeps, and new tests pin the boundary at exactly +15:00. `CLAUDE.md` states the accepted risk plainly: order ids are public, so any device on the wifi can switch unpaid transfer orders to cash or renew expired ones.

Both reviewers re-checked the fix diff independently. **Verdict: passed (P0 0, P1 0), no new findings.** One residual note, accepted: a hand-corrupted `items_json` still makes a route answer 500 (it existed before, and nothing leaks).

| Command (final candidate) | Exit code | Output tail | Run by |
|---|---|---|---|
| `make backend-analyze` | 0 | `No issues found!` | executor |
| `make backend-test` | 0 | `+486: All tests passed!` | executor |
| `make format-check` | 0 | `Formatted 67 files (0 changed)` | executor |
| `make analyze` | 0 | `No issues found!` | executor |
| `make test` | 0 | `+343: All tests passed!` | executor |
| `make boundaries` | 0 | `boundaries: ok` | executor |
| `make check` | 0 | `0 changed`, `boundaries: ok`, analyze clean, Flutter `+343`, backend `+486: All tests passed!` | orchestrator, this session |

Card moved to `docs/tasks/done/`.
