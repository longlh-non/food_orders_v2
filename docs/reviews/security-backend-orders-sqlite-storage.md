---
task: backend-orders-sqlite-storage
status: passed
p0: 0
p1: 0
reviewedFiles:
  - backend/lib/database.dart
  - backend/lib/orders_api.dart
  - backend/bin/server.dart
  - backend/test/orders_api_test.dart
  - backend/pubspec.yaml
  - backend/pubspec.lock
  - .gitignore
  - CLAUDE.md
---

# Security review — backend-orders-sqlite-storage

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-09, on the same frozen candidate as the code review.

## Scope

- **Assets:** customer names and orders in `backend/data/orders.db`, the backend process (the build hook runs code at build time), and disk space.
- **Inputs:** the POST and PATCH bodies and the `<id>` path segment (remote); `ORDERS_DB` (set by the operator, not remote); and the network path of the build-time download.

## Checked with no issues found

- **SQL injection:** every statement uses `?` placeholders. The only interpolated SQL is fixed DDL text in `database.dart`. An injection-style string round-trip test passes.
- **What the API can change:** POST requires the exact validated shape, and PATCH writes only an allow-listed `status`. There is no route that deletes or rewrites data.
- **Duplicate ids:** there's no race. The duplicate check and the insert run synchronously in the single isolate, and the primary key is a backstop.
- **Stored JSON:** prices must be finite, so a stored row can't break later GET or SSE output.
- **Migration:** runs in a transaction, with rollback.
- **`ORDERS_DB`:** set by the operator only; it isn't reachable over HTTP.
- **Supply chain:**
  - The lockfile pins `sqlite3` 3.9.1 and its hook packages as `source: hosted`, with the url `pub.dev`, each with a sha256.
  - The expected hash of the native binary ships inside the pub-verified package. It is not trusted on first use and not fetched at runtime.
  - Downloads are hashed as they stream, and a mismatch fails the build.
  - No `url_pattern` or `source` override is configured.
- **Git:** `backend/data/` and `.dart_tool/` are both git-ignored, confirmed by the caller with `git check-ignore`.

## Findings (first pass): P0 0 · P1 0 · P2 3

- **P2-1, data at rest:** the database holds customer names and was created with mode `0644` in a `0755` directory, so any local user can read it. Low impact on a single-user dev laptop. **Deferred** to `deploy-production-config` (`UMask=0077`, or a `0700` directory and `0600` file).
- **P2-2, flood risk now persists:** an accepted risk (no body limit and no order cap) is now worse. A flood fills the disk permanently, and `GET /orders` returns every row. **Deferred:** added to `backend-request-body-limit`, marked more urgent and needed before deploy.
- **P2-3, build hook trust:** the hook downloads a native library from `github.com/simolus3/sqlite3.dart/releases` and loads it into the server, so we rely on the package maintainer; the download itself is hash-pinned. **Recorded:** keep the lockfile committed, review the hook on any `sqlite3` bump, and note that an offline first build fails. Also noted on `deploy-production-config`.

## Re-review 1

`backend/bin/server.dart` changed: an empty `ORDERS_DB` now counts as unset. Nothing else changed.

**Still passed.** No new findings. The three P2 dispositions are accepted.

**Counts:** P0 0 · P1 0 · P2 3 (deferred or recorded).
