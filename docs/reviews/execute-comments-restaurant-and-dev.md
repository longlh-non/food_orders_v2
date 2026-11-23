---
task: comments-restaurant-and-dev
status: passed
p0: 0
p1: 0
---

# Review: comments-restaurant-and-dev

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | 552 tests |
| `make analyze` / `make check` | 2 | 19 pre-existing `deprecated_member_use` infos (`material_ui` SDK issue); nothing new from these files |

Comment-only proof: with comment lines, blank lines and whitespace stripped, each of the three files equals its pre-edit snapshot (implementer: IDENTICAL; orchestrator re-check: SAME for all three). `dart format` changed 0 files.

## Changed paths (comments only)

`lib/restaurant/main.dart`, `lib/restaurant/pages/orders_page.dart`, `lib/dev/demo.dart`. Not in the card's Sources, untouched: `lib/restaurant/api/export_client.dart`, `pages/export_month_dialog.dart`, `widgets/staff_login_dialog.dart`, `state/staff_credentials.dart`, `download/*`. The card's Goal text is stale (pending/accept orders); comments describe what the code does today.

Older comment corrected: the `demo.dart` doc claimed the demo works "without any backend"; it needs the backend (`OrderRepository.init()` fetches `/api/orders` and opens SSE; `MenuState.load()` fetches the menu).

## Findings (code-reviewer): P0 0, P1 0, P2 4 — deferred

Every comment was verified true against the code (and against `order_repository.dart`, `order.dart`, `vietqr.dart`, `dev/Caddyfile`, `.vscode/launch.json`). Deferred wording P2s:
1. `orders_page.dart:250-251`: "turns every failure into a fixed outcome" — a 401 is thrown as `_WrongCredentials`, and non-`OrderRequestException` errors pass through.
2. `orders_page.dart:74-75`: badge job says "`awaiting_payment` plus `preparing`"; should add "not yet lapsed" (the `build` doc already does).
3. `orders_page.dart:58-59`: "hash * 0x01000193" loosely paraphrases `(hash ^ unit) * 0x01000193`.
4. `demo.dart:21-26`: plain `localhost:8082` has no `/api` proxy (`dev/Caddyfile` has no demo host), so orders and menu stay empty; say so. Whether the demo works in a browser is unverified.

## Unverified

Owner acceptance that the comments are readable and helpful.

## Verdict

**Passed**, P0: 0, P1: 0.
