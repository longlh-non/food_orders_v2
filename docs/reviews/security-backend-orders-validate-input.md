---
task: backend-orders-validate-input
status: passed
p0: 0
p1: 0
reviewedFiles:
  - backend/lib/orders_api.dart
  - backend/test/orders_api_test.dart
  - CLAUDE.md
---

# Security review — backend-orders-validate-input

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-09, on the same frozen candidate as the code review. No other reviewer's conclusions were shared.

## Scope

- **Assets:** the in-memory order list, the SSE stream, and process availability.
- **Attacker input:** the POST and PATCH JSON bodies, and the `<id>` path segment.
- **New capability:** none. The validation is stricter, and duplicates get a 409.
- **Accepted context:** no auth, reachable from the LAN through mDNS on :80, CORS `*`.

## Findings (first pass): P0 0 · P1 1 · P2 2

### P1-1: a non-finite price got past validation and broke the store. Fixed.

- **Entry:** `POST /orders` with an item `"price": 1e999`.
- **Path:** `jsonDecode` turns `1e999` into `double.infinity`, which still passes `is num`. The order was then inserted and broadcast. `jsonEncode` throws on Infinity, so the POST answered 500, and every later `GET /orders`, PATCH of that order, and SSE event would throw too. The SSE listener has no try/catch, so an open client could also crash the process, wiping the in-memory orders.
- **Confirmed by the caller:** a scratch script showed `jsonDecode('{"price": 1e999}')` gives `Infinity`, `is num` is `true`, and `jsonEncode` throws `JsonUnsupportedObjectError`.
- **Fix:** `price` must be finite and at least 0, and `quantity` an int of at least 1. Regression test: a raw-JSON POST with `1e999` gets 400. Before the fix, this request threw inside the handler.

### P2-1: no cap on string length, item count, or order count. Deferred.

Same class as the tracked body-limit work. Added to `docs/tasks/backend-request-body-limit.md`.

### P2-2: no `X-Content-Type-Options: nosniff` on plain-text error bodies. Deferred.

Minimal impact, because nothing is echoed. Noted on the body-limit card as an optional hardening.

## Checked with no issues found

- **Hostile JSON types:** non-object JSON, malformed JSON and invalid UTF-8 all get a 400. Decoded maps are `Map<String, dynamic>`, so the type checks hold.
- **Nesting:** deeply nested values are rejected by the type checks before they could be stored.
- **Key handling:** `_hasExactly` ignores key order, and duplicate JSON keys collapse to one.
- **PATCH:** it can only change `status`.
- **No id oracle:** the 400-before-404 order and the 409 reveal nothing new, because `GET /orders` already lists every order.
- **Output:** nothing from the request is reflected back.
- **Races:** none in the single-isolate handler.
- **Dependencies:** none changed.

## Re-review 1

The P1 is resolved: `!price.isFinite || price < 0` rejects ±Infinity, and NaN can't come from JSON.

After validation, stored values can only be strings, ints and finite numbers, inside a fixed-shape list and maps of those. So `jsonEncode` can't fail, and the SSE listener can stay as it is.

The new `placedAt` regex is anchored and linear, with no ReDoS risk. No new findings.

**Gates after the fix:** `make backend-test` 0 (46), `make backend-analyze` 0, `make analyze` 0, `make test` 0, `make format-check` 0, `make boundaries` 0.

**Counts:** P0 0 · P1 0 · P2 2 (deferred).
