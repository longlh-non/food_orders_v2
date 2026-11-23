---
executor: task-executor
scopes: [backend]
workKinds: [documentation, backend, quality-gate]
blockedBy: [comments-shared]
---

# Code comments: backend/lib and backend/bin

## Why

Same goal as `comments-shared`, for the Dart `shelf` server. Follow "The bar" in `docs/tasks/comments-shared.md` exactly (the Flutter-specific lines about widgets simply do not apply). `backend/lib/staff_gate.dart` and `backend/lib/orders_export.dart` already have good `///` comments; keep the correct ones and fill gaps only.

## Sources

`backend/lib/orders_api.dart`, `menu_api.dart`, `database.dart`, `orders_export.dart`, `staff_gate.dart`, `backend/bin/server.dart`.

## Goal

Every in-scope function, method and class has a doc comment. Specifically explain: each route handler (method, path, status codes returned, matching the table in `CLAUDE.md`), the validation helpers (which rule they enforce), numbered schema steps in `database.dart` (what each step changes; never edit step logic), and why `/orders/stream` uses `request.hijack()`.

## Non-goals

No logic, SQL, rename, or formatting change beyond `dart format`. No change to the HTTP/SSE contract, so the `CLAUDE.md` Backend table is not touched. No `backend/test/**`, no `pubspec.*`. No SQL text changes: comments inside SQL strings would change runtime behaviour, so put comments only in Dart `///` or `//` lines outside strings.

## Requirements

1. Comments only, per the bar.
2. Do not describe behaviour that is not in the code today (for example staff write endpoints or image columns, which are other active cards).
3. Active cards edit these files (`backend-menu-*`, `backend-orders-month-export-*`, `backend-request-body-limit`, `deploy-production-config`). Recommendation: run when none is mid-flight; on conflict redo the comments on the new code and never resolve by editing code.
4. No secrets: do not paste a real staff ID or password, real customer names or real order rows into comments. Use placeholders.

## Tests written with the change

None new. `make backend-test` passing shows behaviour is unchanged.

## Acceptance criteria and verification

- `make backend-analyze`, `make backend-test`, `make format-check` exit 0, recorded in the review. Also `make boundaries` (backend must not import Flutter or `lib/`).
- Comment-only diff; no string literal (especially SQL) changed (`code-reviewer`).
- Comments accurate against the code and the `CLAUDE.md` API table; a wrong comment is P1.
- Owner acceptance: readable and helpful. Unverified until confirmed.

## Environment limits

`dart test` needs network on first build to download SQLite (see `CLAUDE.md`). If the sandbox has none, say so: gate "unverified", not "passed". No sudo, no commits by the agent.

## Decided by the owner (2026-11-12)

L1-L7 were accepted as recommended. They are recorded in `comments-shared` (in `docs/tasks/done/` once it is archived): no lint, no tests, no generated files, skip trivial members, English, one short clause per Flutter idea, and run when the files are quiet.
