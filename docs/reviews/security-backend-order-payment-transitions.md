---
task: backend-order-payment-transitions
status: passed
p0: 0
p1: 0
---

# Security review: backend-order-payment-transitions

Date: 2026-11-19. Reviewer: `security-reviewer` (independent, read-only, first pass). It did not see the code review.

## Scope

New routes `POST /orders/{id}/switch-to-cash` and `renew-payment` (customer, no login), and `staff-switch-to-cash` and `confirm-payment` (staff gate). The 15-second expiry sweep, the lazy expiry check, the SIGINT handler, and the `CLAUDE.md` contract.

## Gates (first round)

Same as `docs/reviews/execute-backend-order-payment-transitions.md` (all exit 0, run by the executor in this session).

## Findings

P0: none. P1: none.

P2 (both fixed in "Fix round 1" below):

1. **The sweep cost** (`orders_api.dart:92-131`). The sweep loads and decodes every waiting transfer order, due or not, every 15 s. A wifi client filling storage with large bank-transfer orders would turn that into a stall of several seconds, every 15 s. **Fix:** select only `id` and `payment_due_at` for orders that are actually due.
2. **The accepted risk is understated in `CLAUDE.md`** (`CLAUDE.md:206`). Order ids aren't secret: `GET /orders` and the stream give them to anyone. So any device on the wifi can switch **every** unpaid transfer order to cash (and the kitchen starts it), or renew expired ones. `confirm-payment` only stops casual mistakes, not an attacker. **Fix:** say this plainly.

## Checked and clean (summary)

- **No unpaid path to the kitchen:** an unpaid transfer order can't reach `preparing` or later except by the owner's designed switch to cash. That holds for PATCH, renew, POST and races with the sweep. It also holds for confirming an overdue order the sweep hasn't reached yet: the lazy check runs first, so confirm answers 409.
- **Races:** every write is conditional on the state it read, and there is no `await` between read and write.
- **Time:** only the server clock is used, and the body whitelist means a client can't send a time.
- **Staff gate:**
  - It runs before any lookup, so an id's existence doesn't leak without credentials.
  - Its error bodies are fixed text.
  - `MenuApi` and `OrdersApi` share one gate, so the lock-out counts across both.
  - The known accepted lock-out nuisance now also delays `confirm-payment`.
- **Ids:** only bound as SQL parameters, with no echo.
- **SIGINT:** it can only come from a local process.
- **SSE:** reuses the existing subscribe and cancel path.

## Unverified (needs a real run)

- The sweep timing with 10,000 rows.
- `/orders/%zz/switch-to-cash` answers cleanly and the process survives.
- The 5- and 15-minute behaviour through Caddy.

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
