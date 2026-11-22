---
executor: task-executor
scopes: [customer, restaurant, shared]
workKinds: [flutter, quality-gate]
blockedBy: []
---

# Apply `dart format` to the existing Flutter sources

## Why

`make format-check` (and therefore `make check` and CI) fails on the code as it was first committed: 12 files under `lib/` were never run through `dart format`. Found while getting a baseline during the Harness adoption on 2026-10-30.

Files: `lib/customer/{main.dart,pages/cart_page.dart,pages/menu_page.dart,state/cart.dart}`, `lib/dev/demo.dart`, `lib/restaurant/{main.dart,pages/orders_page.dart}`, `lib/shared/{api/order_api_client.dart,api/order_repository.dart,data/sample_menu.dart,models/order.dart,theme.dart}`.

## Goal

Run `dart format lib test`. Whitespace and line-wrapping only — no other edits.

## Non-goals

Any rename, refactor, lint fix, or behaviour change.

## Acceptance criteria → verification

| Criterion | Verified by |
|---|---|
| Whole repo formatted | `make format-check` exit 0 (gate) |
| Nothing else changed | `make analyze`, `make test` exit 0 (gates); `git diff --stat` touches only the files above; `code-reviewer` confirms whitespace-only (review) |
| `make check` green end to end | `make check` exit 0 (gate) |

Ideally a commit of its own (`style: apply dart format`) so `git blame` stays readable.
