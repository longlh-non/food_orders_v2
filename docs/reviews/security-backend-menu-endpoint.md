---
task: backend-menu-endpoint
status: passed
p0: 0
p1: 0
reviewedFiles:
  - backend/lib/database.dart
  - backend/lib/menu_api.dart
  - backend/lib/orders_api.dart
  - backend/bin/server.dart
  - backend/test/menu_api_test.dart
  - CLAUDE.md
---

# Security review — backend-menu-endpoint

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-09, on the same frozen candidate as the code review.

## Scope

- **Assets:** `menu_items` rows, `orders` rows, and the listener on `0.0.0.0:3000`.
- **Attacker input:** only the path and method of a request to `/menu`. No request body is read, and no request data reaches SQL.
- **New capability:** one unauthenticated, read-only JSON endpoint, plus a schema step.

## Checked with no issues found

- **No write path to `menu_items`.** `MenuApi` registers only `GET /menu`, with a fixed `SELECT`. The only writes are the seed, a prepared statement over constants inside a transaction.
- **Path variants:** `/menu/`, `/MENU`, `/menu?x` and encoded paths either reach the same read-only handler or get a 404.
- **Cascade:** it retries only on 404 or 405. The SSE hijack throws rather than returning, so it isn't retried. Valid POST and PATCH requests are answered by Orders.
- **CORS:** headers stay on fall-through responses, and the `*` policy is unchanged.
- **Price trust:** unchanged. `POST /orders` still doesn't consult the menu (MENU-DB3 follow-up).
- **Unchanged since the last card:** SQL injection (placeholders only), database-handle ownership, SSE cleanup, and dependencies (none new).
- **CLI docs:** single-statement examples, each scoped with `WHERE`. Nothing encourages `DROP`, `.read` or piping in untrusted SQL.

## Findings (first pass): P0 0 · P1 0 · P2 3

- **P2-1** `backend/lib/database.dart:52`: the table didn't enforce types. An owner CLI edit like `price='abc'` was stored as text and still passed `CHECK (price >= 0)`. `9e999` became Infinity, so `jsonEncode` threw and `GET /menu` answered 500 (the process stays up). **Fixed:** `typeof` checks on price, name and description, plus `price <= 1e9`. Tests cover negative, `'abc'` and `9e999` prices, a binary name, and a NULL description.
- **P2-2** `backend/lib/database.dart`: an owner's CLI write while the server is running could make a read fail with `SQLITE_BUSY` (a transient 500). **Fixed:** `PRAGMA busy_timeout = 2000`, which a test asserts.
- **P2-3, output encoding for the next card:** `name` and `description` are owner-controlled free text. Flutter `Text` doesn't interpret markup, so they're safe as long as no HTML or rich-text rendering is used, and `id` never goes into a URL or path unescaped. **Carried** into `docs/tasks/customer-menu-client-and-state.md`.

## Re-review 1

**Still passed.** P2-1 and P2-2 are closed, and P2-3 is carried.

- **Cascade reorder** (Menu first, Orders last) is safe. Menu never reads a body, so POST and PATCH bodies reach Orders intact.
- **SSE and CORS** behave as before.
- **No new findings.**
- **Not re-read:** the updated CLI wording and the test file. The code-reviewer checked the docs in its re-review 2.

**Counts:** P0 0 · P1 0 · P2 0 open (1 carried to the next card).
