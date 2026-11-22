---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: []
securityReview: required
---

# Add backend handler tests for the orders API

## Why

`backend/` has no tests and no lint config of its own, so `make backend-test` has nothing to run and `dart analyze` in `backend/` inherits the Flutter `analysis_options.yaml` (package-resolution warning). The router and state are top-level globals inside `bin/server.dart`, so nothing can be tested in isolation. This is also the first real task run through the adopted Harness workflow.

`securityReview: required` because it adds dependencies (`test`, `lints`) and changes how request bodies are parsed.

## Sources

- `CLAUDE.md` → "Backend" (API table), "Why SSE uses `request.hijack()`", "Architecture invariants" #3–4.
- `backend/bin/server.dart`, `lib/shared/models/order.dart` (`Order.toJson()` shape), `lib/shared/api/order_api_client.dart`.

## Goal

1. Move the router + in-memory state into `backend/lib/orders_api.dart` as a class, so each test gets a fresh instance. `bin/server.dart` keeps only the `logRequests()` middleware, `io.serve`, and the startup print. Same paths, same responses, same SSE wire format, same port and bind address.
2. Malformed bodies on `POST /orders` and `PATCH /orders/{id}` (invalid JSON, or JSON that isn't an object) return **400** with a short plain-text message and leave stored orders unchanged. Today they throw an unhandled exception → 500. The Flutter client ignores status codes on POST/PATCH, so the apps aren't affected.
3. Add `backend/analysis_options.yaml` (`include: package:lints/recommended.yaml`) and dev dependencies `test` and `lints` via `dart pub add --dev` (lockfile updated by the tool, not by hand).
4. Add `backend/test/orders_api_test.dart`.

## Non-goals

- Server-side id generation, field validation beyond "is a JSON object", auth, persistence, restricting which fields PATCH can overwrite. (Known limitations — follow-up cards if wanted.)
- Any change to `lib/` or the Flutter apps.

## Tests (written with the change)

- `GET /orders` returns `200`, `application/json`, `[]` on a fresh instance.
- `POST /orders` with an `Order.toJson()`-shaped body returns `200` echoing it; a following `GET` lists it; newest first after two posts.
- `PATCH /orders/{id}` with `{"status":"accepted"}` returns the merged order and `GET` reflects it; unknown id → `404`.
- Invalid JSON and a non-object JSON body on POST and PATCH → `400`, and `GET` shows state unchanged.
- SSE over a real loopback server on port 0: the stream opens with `: connected`, then a `POST` produces a `data: <order json>` event. Every read has a timeout; the server is force-closed in `tearDown`.
- Two instances don't share state.

## Acceptance criteria → verification

| Criterion | Verified by |
|---|---|
| Tests above exist and pass | `make backend-test` (gate) |
| Backend lints clean with its own config | `make backend-analyze` (gate) |
| Touched files formatted, boundaries intact, apps unaffected | `make format-check` scoped to touched files, `make boundaries`, `make analyze`, `make test` (gates) |
| Refactor preserves behaviour & API contract | `code-reviewer` (independent review) |
| No new security problem from parsing or deps | `security-reviewer` (independent review) |
| Real apps still place/update orders live through Caddy | Owner acceptance in the browser — **unverified** unless the owner checks |

## Limits

`make format-check` over the whole repo fails before this task (12 files in `lib/` were never formatted). This task formats only the backend files it touches; the `lib/` formatting is a separate card.
