---
task: backend-orders-handler-tests
status: passed
p0: 0
p1: 0
reviewedFiles:
  - backend/bin/server.dart
  - backend/lib/orders_api.dart
  - backend/test/orders_api_test.dart
  - backend/analysis_options.yaml
  - backend/pubspec.yaml
  - backend/pubspec.lock
---

# Security review — backend-orders-handler-tests

Independent first-pass review by `security-reviewer` (read-only; no other reviewer's conclusions shared). Date: 2026-10-30.

## Gates available to the reviewer (run by the caller this session)

| Command | Exit |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (13 tests) | 0 |
| `make analyze` / `make test` | 0 / 0 |

## Scope

Assets: in-memory order list, backend process availability, dependency graph. Attacker-controlled inputs: POST/PATCH bodies, `{id}` path segment, SSE connections — reachable from the LAN via `/api/*` on :80. No new capability: dev dependencies only, test server binds loopback.

## Findings

### P2-1 — No request-body size limit (pre-existing, not a regression) — deferred

- **Asset:** process memory / uptime. **Entry:** `POST` or `PATCH /api/orders…`.
- **Path:** `_readJsonObject` buffers the whole body (`backend/lib/orders_api.dart:112`); valid objects are retained forever (`:36`, `:46`) and fanned out to every SSE client (`:82`).
- **Impact:** a device on the wifi can exhaust memory with one huge body or many large orders.
- **Fix:** cap body size (length check before decode, or `request_body max_size` in Caddy / `client_max_body_size` in nginx).
- **Disposition:** deferred → follow-up card `docs/tasks/backend-request-body-limit.md`. HEAD had identical behaviour.

## Checked and clean

- Parsing: invalid JSON, non-object JSON, empty body, and invalid UTF-8 → `FormatException` → 400, store untouched (checked before insert/merge). Other errors are caught per request by shelf_io → 500, process stays up (no worse than HEAD).
- Output: fixed-string error bodies; no reflection, no stack traces. SSE frames use `jsonEncode`, which escapes newlines, so no event injection.
- PATCH can overwrite any field incl. `id` — unchanged from HEAD, explicit non-goal.
- Middleware order and binding unchanged (`logRequests` → CORS → router; `0.0.0.0:3000`; CORS `*`).
- SSE hijack code identical; subscription, timer, and sink released on disconnect.
- Test server: loopback on port 0, force-closed in `tearDown`.
- Dependencies: all 41 new lock entries are `source: hosted` from pub.dev with sha256; `lints 6.1.0` and `test 1.33.0` are `direct dev`; no `direct main` version changes; additions only; no git/path/override sources. Lock SDK floor moved `>=3.9.0` → `>=3.13.0` (toolchain note; local and CI use Dart 3.13.5).

## Needs real-environment confirmation (unverified)

- Whether port 3000 is reachable from the LAN directly (binds `0.0.0.0`; only 80/tcp is opened in ufw per CLAUDE.md). Owner: `sudo ufw status`. Unchanged by this task.
- Placing/updating orders live through Caddy in a browser — owner acceptance.

**Counts:** P0 0 · P1 0 · P2 1 (deferred).

## Re-review 1 (2026-10-30)

**Trigger:** reviewed files changed after code-review P2 fixes. The changes: `handler` became `late final`, `close()` was added, test teardown and a shared bad-body table, and `environment.sdk` went from `^3.3.0` to `^3.13.0` (`dart pub get` re-run).

**Gates after the changes:** `dart format --output=none --set-exit-if-changed backend` 0 · `make backend-analyze` 0 · `make backend-test` 0 (15 passed) · `make boundaries` 0 · `make analyze` 0 · `make test` 0.

**Result: still passed, no new findings.**

- Routes, parsing, error bodies, the SSE wire format and cleanup, and the middleware order are unchanged.
- `close()` is called only from tests, never from `bin/server.dart`.
- Lockfile: only additions (all hosted on pub.dev, with sha256), plus the SDK-floor line. No runtime dependency changed.

**Counts:** P0 0 · P1 0 · P2 1 (P2-1, deferred to `docs/tasks/backend-request-body-limit.md`).
