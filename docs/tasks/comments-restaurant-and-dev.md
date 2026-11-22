---
executor: task-executor
scopes: [restaurant, dev-infra]
workKinds: [documentation, flutter, quality-gate]
blockedBy: [comments-shared]
---

# Code comments: lib/restaurant and lib/dev

## Why

Same goal as `comments-shared`. Follow "The bar" in `docs/tasks/comments-shared.md` exactly. These two folders are small, so they share one card.

## Sources

`lib/restaurant/main.dart`, `lib/restaurant/pages/orders_page.dart`, `lib/dev/demo.dart`. Note `lib/dev/demo.dart` is Dart code under `lib/dev/`, not the `dev/` infra folder (Caddy, nginx, mDNS); do not touch `dev/**`. (Scope `dev-infra` is listed only because the folder is named dev; no infra file changes.)

## Goal

Every in-scope declaration has a doc comment per the bar. In `orders_page.dart` explain the new-order detection (IDs not seen on the previous tick), the SnackBar plus chime, and the pending-count Badge. In `demo.dart` explain why it may import both apps and why they share state.

## Non-goals

No logic, rename, or formatting change beyond `dart format`. No changes to `dev/**`, `Makefile`, `.github/**`, `.claude/**`. No tests.

## Requirements

1. Comments only, per the bar.
2. Active cards edit `orders_page.dart` (`vi-translate-shared-and-restaurant-ui`, `restaurant-orders-month-export-button`, `restaurant-menu-editing-page`). Recommendation: run after the translate and export-button cards merge, or accept a cheap redo of comments on conflict. Never resolve a conflict by editing code.

## Tests written with the change

None new.

## Acceptance criteria and verification

- `make format-check`, `make analyze`, `make test`, `make boundaries` exit 0, recorded in the review.
- Comment-only diff; accurate comments (`code-reviewer`).
- `git diff --stat` shows no path outside `lib/restaurant/` and `lib/dev/demo.dart`.
- Owner acceptance: readable and helpful. Unverified until confirmed.

## Environment limits

No sudo, no commits by the agent.

## Decided by the owner (2026-11-12)

L1-L7 were accepted as recommended. They are recorded in `comments-shared` (in `docs/tasks/done/` once it is archived): no lint, no tests, no generated files, skip trivial members, English, one short clause per Flutter idea, and run when the files are quiet.
