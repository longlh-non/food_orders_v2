---
executor: task-executor
scopes: [backend, dev-infra, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-orders-validate-input]
securityReview: required
---

# Persist orders in a SQLite file

## Why

"Known limitations": orders live in process memory and vanish when `dart run bin/server.dart` restarts. The owner asked for a database to save orders.

## Sources

`backend/lib/orders_api.dart` (`_orders` list), `backend/bin/server.dart`, `backend/pubspec.yaml`, `backend/test/orders_api_test.dart`, `.gitignore` (repo root), `CLAUDE.md` "Backend" / "Known limitations" / "Running".

## Planning fixes applied (owner, 2026-11-09)

- `scopes` now includes `dev-infra` (the card edits the repo-root `.gitignore`).
- Sorting is `ORDER BY rowid DESC` only.
- The "no `.db` in git status" check is run by the executor, not a reviewer.
- Any build-time download of native SQLite gets a security review.
- (Fix 1, blocking on the formatting card, applied to validate-input, which is already done, so it's moot.)

## Decisions (owner, 2026-11-06)

- **Engine: SQLite file** (DB1, option A below).
- **Package: `sqlite3`** (DB2). Dependency approved per invariant 5. The native-library check in item 2 below still applies, and the owner runs any `sudo apt install`.
- **Storage shape: one `orders` table with `items_json`** (DB3, option A below).
- **Server-generated ids: later** (DB7). Out of scope here.
- Items 4–6 below (file location + `ORDERS_DB`, `PRAGMA user_version`, `:memory:` tests) were not put to the owner as separate questions. They are the planner's design and stand unless the owner changes them before execution.

The original options are kept below for context.

1. **Database engine.**
   - A. **SQLite file** (recommended). One file next to the backend, no server to install or run, fits one laptop and one backend process. Real SQL, transactions, easy to inspect with `sqlite3` CLI. Weakness: one writer at a time - fine here. Outgrown when several backend machines are needed.
   - B. **Postgres.** The "real" choice for production, but you must install, start and manage a separate server, and add a connection string/credentials (credentials handling = more security surface). Too heavy for local dev today.
   - C. **JSON file** (rewrite whole file on each change). No dependency, but no transactions, a crash mid-write can corrupt it, and it becomes slow and awkward as orders grow. A stopgap, not a database.
2. **Dart package** (if A): `sqlite3` (pub.dev, official-style bindings, synchronous API - simple in a small server). Recent versions are meant to bring SQLite with them via Dart build hooks rather than needing the system `libsqlite3`, but the executor must verify this on this machine and report it: does `dart pub get` + `dart test` work on a stock Ubuntu with no extra `apt install`, does it need a C compiler or network download at build time? If it only works with the system library, the card says so in "Running" and the owner decides whether `sudo apt install libsqlite3-dev` is acceptable (owner runs it, never the agent). Alternative `drift` is rejected: code generation and an ORM layer, too much for one table.
3. **Storage shape.**
   - A. One `orders` table: `id TEXT PRIMARY KEY, customer_name, status, placed_at, items_json TEXT, price REAL NOT NULL CHECK (price >= 0)` (items stored as a JSON string). Recommended - items are always read and written with their order and never queried alone; simplest round trip with `Order.toJson()`.
   - B. `orders` + `order_items` tables (normalised). Needed only for queries like "how many burgers sold"; adds joins and a transaction on every write. Pick later via a migration if reporting is wanted.
4. **File location.** Recommended `backend/data/orders.db`, overridable by an env var (e.g. `ORDERS_DB`), with the directory created on start. Must be git-ignored: add `backend/data/` to the repo-root `.gitignore`. The DB holds customer names, so it must never be committed.
5. **Schema versioning.** Recommended: SQLite `PRAGMA user_version`; on start, if 0 create the table and set it to 1. No migration framework; the next schema change adds an `if version < 2` step.
6. **Test database.** Recommended: in-memory SQLite (`:memory:`), fresh per test, same as today's fresh `OrdersApi` per test. One test uses a temp-directory file to prove data survives closing and reopening.
7. **Server-generated ids** stay out of scope (client still assigns `id`; duplicate -> 409 from the previous card, now backed by the primary key). A separate contract card if wanted.

## Goal

`OrdersApi` reads and writes orders through SQLite instead of the `_orders` list. HTTP/SSE behaviour is identical to after `backend-orders-validate-input`. Orders survive a backend restart.

Design (deliberately small): `OrdersApi` takes the database (or a path) as a constructor argument; `bin/server.dart` opens the real file, tests pass `:memory:`. No repository interface - SQLite in memory already gives tests a fast stand-in, so a second implementation would be a layer with no real boundary to protect (invariant 6). `GET /orders` returns newest first with `ORDER BY rowid DESC`: today's order is "newest *inserted* first", which is exactly rowid order. Don't sort by `placed_at`, which is client-supplied and could reorder the list. `close()` also closes the database. Use parameterised statements only - never build SQL by string concatenation with request data. SSE events still go out after a successful write.

Docs, in this same card (CLAUDE.md edit needs owner approval for this task): update "Backend" (storage, file location, env var, code description), delete the in-memory entry from "Known limitations" (leave the "no auth" line), and note the backend now needs `ORDERS_DB`/the data directory in "Running".

## Non-goals

Server-generated ids, normalised items table, auth, backups, pagination, body-size limit, Postgres, any Flutter change.

## Tests written with the change

In `backend/test/orders_api_test.dart` (existing tests keep passing against `:memory:`) plus one new test: write an order via a temp-file DB, close the `OrdersApi`, open a new one on the same file, `GET /orders` returns it, with PATCHed status preserved; order of results newest first; unusual characters in `customerName` (quotes, `'; DROP TABLE orders;--`) round-trip unchanged; a fresh file gets `user_version` 1.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| All previous API behaviour unchanged | `make backend-test` (gate) |
| Data survives reopen | `make backend-test` (temp-file test) |
| SQL injection safe (parameterised) | injection-string test (`make backend-test`) + `security-reviewer` |
| `backend/data/` ignored by git | executor runs the backend once, then `git status --short` shows no `.db`. Command and output go in the review report (reviewers can't run commands). |
| Dependency choice and native-library behaviour recorded | `code-reviewer` + `security-reviewer` (reviews); owner approval recorded under "Decisions" |
| Build-time downloads reviewed | If `dart pub get` / the first build downloads a prebuilt SQLite (build hooks), the executor records the URL/host and version, and `security-reviewer` checks the source and whether it's pinned/verified. If nothing is downloaded, say so. |
| `make check` green (backend analyze/test, boundaries) | `make check` exit 0 (gate) |
| Restart backend, orders still listed in the restaurant app | owner acceptance in the real environment (browser via Caddy) - "unverified" until done |
| New order still appears live in the restaurant app (SSE) | owner acceptance in the real environment |
| Docs match behaviour | `code-reviewer` (review) |

## Environment limits

CI and agents cannot check the restart-in-browser flow, and agents must not run `sudo apt install` if the system SQLite library turns out to be required.
