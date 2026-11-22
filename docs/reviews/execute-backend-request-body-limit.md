---
task: backend-request-body-limit
status: passed
p0: 0
p1: 0
---

# Review: backend-request-body-limit

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-backend-request-body-limit.md`.

## Candidate (final)

- **Proxies:** `dev/Caddyfile` has `request_body { max_size 64KB }` in both `/api/*` blocks; `dev/nginx.conf` has `client_max_body_size 64k;` in both `/api/` locations.
- **`backend/lib/orders_api.dart`:**
  - `GET /orders` has `LIMIT 500`, newest first;
  - `POST` answers 503 "Order storage is full" at 10,000 stored orders (`OrdersApi(db, {maxStoredOrders})`, used by tests);
  - names (customer, item, topping) at most 200 UTF-16 units;
  - quantity 1–100;
  - item and topping price 0–1,000,000;
  - at most 50 items per order;
  - order, item and topping ids at most 64 characters.
  - Every message is fixed and built from constants.
- **`backend/lib/no_sniff.dart` (new):** adds `nosniff` to every response; wired in `backend/bin/server.dart`.
- **`backend/bin/server.dart`:** binds `127.0.0.1` by default. `BIND_ADDRESS` overrides it, and an empty value counts as unset.
- **Tests:** `backend/test/orders_api_test.dart`, group "limits".
- **`CLAUDE.md` (owner-approved):**
  - the `/orders` rows and the order rules;
  - a new "Size limits" paragraph;
  - an nginx-section line;
  - "Run it" now says `localhost:3000`;
  - a "Known limitations" line about the newest 500.
- **Deploy card:** `docs/tasks/deploy-production-config.md` carries the production `request_body` requirement.

Owner decisions: the numbers 500 / 10,000 / 200; edits to `CLAUDE.md`, `dev/Caddyfile` and `dev/nginx.conf` approved. Executor choices, recorded in the card: price ≤ 1,000,000 and quantity 1–100 (round 1); 50 items and 64-character ids (fix round 1).

## Round 1: passed. P0 0, P1 0, P2 4

- **P2-1:** "characters" in `CLAUDE.md` vs `String.length` (UTF-16 units; an emoji counts 2).
- **P2-2:** `Cart` has no quantity cap, so a line over 100 now fails at checkout.
- **P2-3:** with `GET /orders` capped at the newest 500, an older active order can drop off the restaurant screen.
- **P2-4:** `CLAUDE.md` said `nosniff` was on "every response" without the SSE exception.

## Fix round 1 (with the security P1)

- **P2-1, P2-3, P2-4:** fixed in `CLAUDE.md` (the UTF-16 note, a "Known limitations" line, "except the live order stream").
- **P2-2:** deferred (customer scope).
- **Security changes:** loopback bind by default; 50 items and 64-character ids, with tests.

## Re-review 1: passed. P0 0, P1 0, P2 2

- **P2:** no test for a topping id over 64 characters (same code path as item ids).
- **P2:** two long message lines in `orders_api.dart` (cosmetic; format check passes).

## Deferred follow-ups

1. **Cart quantity cap:** cap `Cart.add` at 100 per line (customer card). Until then, a larger line fails at checkout with the cart page's inline error.
2. **Restaurant list:** paging, or "active orders first", for `GET /orders` before volumes get near 500 open-and-recent orders.
3. **Menu field lengths:** maximum menu name and description lengths need a `menu_items` rebuild. Do it in a later schema step that rebuilds the table anyway, and carry `image` and `available` with their CHECKs.
4. **Topping id test:** a test for a topping id over 64 characters.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make backend-analyze` (round 1 and after fixes) | 0 |
| `make backend-test` (271 tests, then 274 after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `caddy validate --config dev/Caddyfile --adapter caddyfile` | 0 |
| `nginx -t` | not run (nginx isn't installed): **unverified** |
| `git diff --stat backend/pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 241 app + 274 backend tests) | 0 |

## Unverified (owner acceptance)

- **Caddy reload:** `sudo cp dev/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy`. Then a 70 KB POST should print `413` (the command is in the card). Optionally repeat it with `-H 'Transfer-Encoding: chunked'`.
- **Backend restart** (after a dated backup: the database moves to version 6):
  - `ss -ltn | grep 3000` should show `127.0.0.1`;
  - `http://customer.local` still works, including on the iPhone;
  - `http://<laptop-ip>:3000/orders` from another device should fail.
- **nginx:** `nginx -t`, if nginx is used.
