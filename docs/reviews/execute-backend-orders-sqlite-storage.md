---
task: backend-orders-sqlite-storage
status: passed
p0: 0
p1: 0
---

# Execute review — backend-orders-sqlite-storage

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-09. It ran in parallel with `security-reviewer` on the same frozen candidate, and neither saw the other's conclusions. Security report: `docs/reviews/security-backend-orders-sqlite-storage.md`.

## Implementation notes

- `sqlite3: ^3.9.1` was added with `dart pub add` (owner-approved, DB2). The lockfile was written by the tool.
- New `backend/lib/database.dart`: `openDatabase(path)` and `migrate(db)`. Schema steps are numbered with `user_version`; step 1 creates `orders` inside a transaction.
- `OrdersApi(Database)` owns and closes the database, and every SQL statement uses `?` placeholders. GET sorts with `ORDER BY rowid DESC`.
- `server.dart`: the database is `ORDERS_DB` if set and not empty, otherwise `backend/data/orders.db`, found relative to the script.
- `.gitignore`: `backend/data/`.
- `CLAUDE.md`: updated Backend (storage, file location, `ORDERS_DB`, the build-time download), Run it, and Known limitations (the in-memory line is removed).

## Native library: how SQLite gets onto the machine

The executor read the package's build hook. By default it **downloads** a precompiled SQLite:

| Item | Value |
|---|---|
| Source | `https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.9.1/libsqlite3.x64.linux.so` |
| Expected SHA-256, shipped in the package (`lib/src/hook/asset_hashes.dart`) | `0a65852703763619a7a34633b4959b3b86c4103804a4dfe4e8b27b5de1c0647b` |
| On a hash mismatch | the build fails (`StateError`) |

- **Not needed:** a system `libsqlite3` or a C compiler.
- **Needed:** network access on the first build.
- The security review accepted this; see that report.

## Gates — first candidate

| Command | Exit |
|---|---|
| `make backend-analyze` | **2** on the first attempt: 4 infos for the deprecated `Database.dispose()`. Replaced with `close()`, then **0**. |
| `make backend-test` (51 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` (2 tests) | 0 |

## Runtime check (card row "`backend/data/` ignored by git")

```
$ cd /tmp && timeout 5 dart run <repo>/backend/bin/server.dart
orders database: <repo>/backend/data/orders.db
$ ls -la backend/data/              → orders.db, 12288 bytes, -rw-r--r--
$ git status --short | grep -E "data|\.db"
 M lib/shared/data/sample_menu.dart   (unrelated; no .db listed)
$ git check-ignore -v backend/.dart_tool backend/data/orders.db
.gitignore:29:.dart_tool/    backend/.dart_tool
.gitignore:51:backend/data/  backend/data/orders.db
```

Running the server from `/tmp` also proves the default path doesn't depend on the current directory.

## Findings (first pass): P0 0 · P1 0 · P2 4

- **P2-1** `backend/bin/server.dart:14`: the default path relies on `Platform.script`, which is right under `dart run` but not for a compiled binary. Also, an empty `ORDERS_DB` would open an anonymous temporary database, and orders would silently vanish. **Fixed:** an empty value now counts as unset, and a comment says compiled binaries must set `ORDERS_DB`. The same note is on `deploy-production-config`.
- **P2-2** `backend/lib/database.dart:42`: "a failed `BEGIN` would trigger `ROLLBACK` outside a transaction." **No change needed.** `BEGIN` already runs before the `try`. The reviewer agreed in re-review that it was a false positive.
- **P2-3** `backend/bin/server.dart`: the database isn't closed on SIGINT. Safe with SQLite's default rollback journal. **Deferred**, optional.
- **P2-4** `backend/test/orders_api_test.dart:320`: `first.close()` runs inline, not through `addTearDown`. **Deferred.** The test must close before reopening, and also adding a teardown would close twice. A handle leaks only on a test that is already failing.

**Checked with no issues found:**
- Status codes and JSON shape are unchanged. Ints and doubles survive the `items_json` round trip.
- Events are emitted only after a successful write.
- Ordering, parameterised SQL, and races (none in the single isolate) were all checked.
- Resources: every test closes its database, and temp directories are removed.
- The docs match the code.
- The migration's "add a step, never edit" design leaves room for the menu card's step 2.

## Re-review 1

The P2-1 fix changed only `backend/bin/server.dart`.

**Evidence:** `ORDERS_DB=` (empty), run from `/tmp`, printed `…/backend/data/orders.db`.

| Command | Exit |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (51) | 0 |
| `make format-check` | 0 |

**Re-review 1 (code-reviewer):** P2-1 is resolved, P2-2 is agreed as a false positive, and P2-3 and P2-4 stay deferred. No new findings.

## Final candidate

`make check` → **exit 0** (format, boundaries, analyze, 2 app tests, backend analyze, 51 backend tests).

## Unverified (owner acceptance)

- Restart the backend and check that orders are still listed in the restaurant app (browser via Caddy).
- Place a new order and check it still appears live in the restaurant app (SSE).

**Note:** the runtime check left an empty `backend/data/orders.db`. It's git-ignored, and the real backend will use it.
