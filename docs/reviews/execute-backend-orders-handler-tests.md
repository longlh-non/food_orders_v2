---
task: backend-orders-handler-tests
status: passed
p0: 0
p1: 0
---

# Execute review — backend-orders-handler-tests

Independent first-pass review by `code-reviewer` (read-only, no other reviewer's conclusions shared), 2026-10-30. A security review ran in parallel on the same frozen candidate: `docs/reviews/security-backend-orders-handler-tests.md` (passed).

## Gates — first candidate

| Command | Exit |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (13 tests) | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` (2 tests) | 0 |
| `dart format --output=none --set-exit-if-changed backend` | 0 |
| `make format-check` (whole repo) | 2, already failing before this task: 12 `lib/` files, out of scope per card → `docs/tasks/format-flutter-sources.md` |

## Findings (first pass): P0 0 · P1 0 · P2 5

- **P2-1** `backend/lib/orders_api.dart:24`: the `handler` getter rebuilt the Router on every access. Fix: `late final`.
- **P2-2** `backend/lib/orders_api.dart:19`: `_events` was never closed; test instances were left open. Fix: add `close()`, call it in `tearDown`.
- **P2-3** `CLAUDE.md` Backend table: the new 400 and the existing 404 weren't in the API contract table. Fix: add a Responses column.
- **P2-4** `backend/pubspec.yaml:7`: `sdk: ^3.3.0` was lower than the resolved graph needs (`>=3.13.0`). Fix: raise it to `^3.13.0`.
- **P2-5** `backend/test/orders_api_test.dart:118`: PATCH 400 coverage was narrower than POST's. Fix: share one bad-body table.

**Checked with no issues found:**
- Paths, methods, response bodies, port and bind address are unchanged.
- The SSE response is byte-identical; CORS applies to both normal and hijacked responses.
- The effective middleware order is unchanged.
- The 400 path leaves state untouched.
- The client contract still holds (`OrderApiClient` ignores `:` lines and parses `data:`).
- The SSE test is deterministic: loopback on port 0, 5s timeouts, the listener is attached before `: connected` is written, and the client is force-closed so the hijacked socket and timer are released.

## Re-review 1

All five P2s are fixed in one batch, since they are small and inside the card's scope.

**Side effect:** raising the SDK constraint changed the package language version, so the formatter re-wrapped the two new files (whitespace only).

**Invalidation:**
- `code-reviewer` re-ran because its findings were fixed.
- `security-reviewer` re-ran because files it had reviewed changed. The result is in that report: still passed.
- Gates re-ran for everything in `backend/`, plus the Flutter analyze and test runs.

| Command | Exit |
|---|---|
| `dart format --output=none --set-exit-if-changed backend` | 0 |
| `make backend-analyze` | 0 |
| `make backend-test` (15 tests) | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` | 0 |

**Result:** P2-1 through P2-5 are resolved, with no new findings. **P0 0 · P1 0 · P2 0.**

## Final candidate: `make -k check`

The overall exit is 2, from `format-check` only: the same 12 `lib/` files, already failing before this task and outside its scope. `boundaries`, `analyze`, `test` (2 passed), `backend-analyze` and `backend-test` (15 passed) all pass.

## Unverified

Owner acceptance: placing and accepting an order live on `customer.local` / `restaurant.local` through Caddy after this refactor. Not done in this session.
