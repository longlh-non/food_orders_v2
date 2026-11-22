---
executor: task-executor
scopes: [backend, dev-infra]
workKinds: [backend, infra]
blockedBy: [backend-orders-handler-tests]
securityReview: required
---

# Cap request body size on the orders API

## Why

Deferred P2-1 from `docs/reviews/security-backend-orders-handler-tests.md`: `POST`/`PATCH /orders` buffer the whole request body and keep valid orders forever, so any device on the wifi (reachable via mDNS on :80) can exhaust backend memory.

## Decided (owner, 2026-11-11): the body-size limit lives in the proxy (option B)

The owner chose to enforce the request-size limit in **Caddy and nginx**, not in the backend.

**What that means:**
- **The limit is configuration, not Dart code.**
  - `dev/Caddyfile`: inside each `handle_path /api/* { … }`, add `request_body { max_size 64KB }`.
  - `dev/nginx.conf`: inside each `location /api/ { … }`, add `client_max_body_size 64k;`.
  - 64 KB is far above any real order (well under 1 KB).
  - Both proxies answer **413** for a larger body, and the backend never sees it.
- **Edits under `dev/**` need the owner's approval** (`.claude/settings.json` "ask" rule). The owner applies them, since agents never run `sudo`:
  ```bash
  sudo cp dev/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy
  ```
- **Hosting:** `deploy-production-config` must carry the same `request_body` block in the production Caddyfile. Add that requirement to that card when this one runs.
- **⚠ The limit only protects requests that go through the proxy.** The backend listens on `0.0.0.0:3000`, so anything that can reach port 3000 directly bypasses it. That makes "port 3000 is not reachable from outside the machine" part of this card's acceptance.
  - **Locally:** the owner runs `sudo ufw status`; only 80/tcp should be allowed from the LAN.
  - **For hosting:** HOST6 (bind the backend to loopback) on the deploy card.

## Goal

1. **Proxy body limit,** as above, in both `dev/Caddyfile` and `dev/nginx.conf`. `/api/*` only: the Flutter dev servers' routes are untouched.
2. **Backend-side limits.** A proxy can't do these, so they stay in this card (from the later review notes below):
   - **A cap on stored orders,** or a `LIMIT` on `GET /orders` (newest N). Recommend a `LIMIT 500` on `GET /orders` plus a hard maximum number of rows refused with an error, e.g. 10,000. The executor states both numbers in the review.
   - **Maximum lengths:** customer name, item name and topping name of at most 200 characters, and the menu name and description lengths via the `menu_items` CHECK constraints (a new schema step, or folded into the next un-shipped step; say which).
   - **`X-Content-Type-Options: nosniff`** on the backend's plain-text error responses.
3. **Docs:** `CLAUDE.md` "Reverse proxy" and "Backend" sections say where the size limit lives and why port 3000 must stay private. Owner approval for the `CLAUDE.md` edit is requested by this card.

## Tests written with the change

- Backend (`make backend-test`): the stored-order cap is enforced; `GET /orders` returns at most the limit, newest first; over-long names get 400 with state unchanged; error responses carry `nosniff`.
- **The proxy limit can't be covered by `make` gates,** because no proxy runs in CI. The executor records a config check instead: if the tools exist, `caddy validate --config dev/Caddyfile` and `nginx -t -c "$PWD/dev/nginx.conf" -p "$PWD"`, neither needing `sudo`; otherwise this is marked unverified. The owner runs the real check below.

## Acceptance criteria → verification (revised 2026-11-11 for option B)

| Criterion | Verified by |
|---|---|
| A body over 64 KB through Caddy gets 413, and the order list is unchanged | owner acceptance after reloading Caddy (see the command below) |
| Same through nginx, if nginx is used | owner acceptance, the same command while nginx runs |
| Port 3000 is not reachable from the LAN | owner: `sudo ufw status` shows only 80/tcp allowed, **or** a request from another device to `http://<laptop-ip>:3000/orders` fails |
| Order cap, `GET /orders` limit, name-length limits, `nosniff` | `make backend-test` (gate) |
| Proxy configs are valid | `caddy validate` / `nginx -t` if available, otherwise unverified; `security-reviewer` (review) |
| `CLAUDE.md` matches what was done | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |

The owner's 413 check (sends a 70 KB body; expected output `413`):

```bash
head -c 70000 /dev/zero | tr '\0' 'a' | curl -s -o /dev/null -w '%{http_code}\n' -X POST --data-binary @- http://customer.local/api/orders
```

## Added by later reviews (2026-11-09)

From `docs/reviews/security-backend-orders-validate-input.md`:
- **P2-1:** besides the body size, there's no cap on the number of stored orders, string lengths, or items per order. Consider an order-count cap, or rely on the SQLite card plus the body limit, and say which.
- **P2-2 (optional):** add `X-Content-Type-Options: nosniff` to the plain-text error responses.

From `docs/reviews/security-backend-orders-sqlite-storage.md` (P2-2, 2026-11-09):
- **Now more urgent.** Orders are stored in SQLite, so a POST flood fills the disk *persistently*: a restart no longer clears it, and recovery means deleting the database file, which loses every order. `GET /orders` also returns every row (`SELECT *`, no `LIMIT`). The body limit plus an order-count cap (or a `LIMIT` on GET) should land before any deploy.

From `docs/reviews/security-customer-menu-client-and-state.md` (P2-1, 2026-11-10):
- The customer app buffers the whole `GET /menu` response, and nothing caps the menu's size. Consider a maximum number of menu items, or maximum name and description lengths, in the `menu_items` CHECK constraints.

From `docs/reviews/security-backend-order-item-toppings.md` (P2, 2026-11-12): `quantity` and prices have no upper bound (`9e18` passes), so `quantity × price` can overflow or display badly. Add maximums here or in MENU-DB3, and say which.

## Owner decisions and executor notes (2026-11-17)

- **Owner approval:** the owner approved the edits to `CLAUDE.md`, `dev/Caddyfile` and `dev/nginx.conf` for this card, and the numbers: `GET /orders` returns the newest **500**, new orders are refused (503) past **10,000** stored, and names are at most **200** characters.
- **Executor choices (owner may change):**
  - item and topping price at most **1,000,000** VND, the same cap the owner approved for menu edits (MENU-EDIT3);
  - quantity from 1 to **100**.
  - Both answer the later review notes about `9e18`. They're constants in `backend/lib/orders_api.dart`.
- **Not done here (follow-up):** maximum menu name and description lengths. A CHECK on existing columns needs a full `menu_items` table rebuild. Only the owner edits the menu, by hand, and the staff endpoint will only change price and sold-out, so the risk is small. Do it in a later schema step that rebuilds the table anyway, and carry `image` and `available` with their CHECKs.
- **`nosniff`:** added as `noSniff()` middleware in `bin/server.dart`, so every response gets it, not just `/orders`. The hijacked SSE stream bypasses middleware; it only sends `text/event-stream`.
- **Proxy config check:** `caddy validate --config dev/Caddyfile --adapter caddyfile` passes (exit 0). nginx isn't installed here, so `nginx -t` is **unverified**.
- **Hosting:** `deploy-production-config` now carries the same `request_body` requirement.

## Fix round 1 (2026-11-17)

- **Security P1:** the backend now listens on loopback (`127.0.0.1`) by default, so nothing on the wifi can reach `:3000` and get around the proxy's 64 KB limit. `BIND_ADDRESS` overrides it, and an empty value counts as unset. The "port 3000 not reachable" acceptance row is now met by the code default; ufw is a second layer.
- **Security P2:** at most **50** lines per order, and at most **64** characters for the order, item and topping ids. These are executor choices: app ids are 13-digit timestamps.
- **Docs (code review P2-1, P2-4, P2-3; security P2-2):**
  - name lengths count UTF-16 units;
  - `nosniff` applies to every response except the SSE stream;
  - a "Known limitations" line that the newest-500 list can hide older active orders;
  - how to clear a full order store, after a backup.
- **Deferred:** a cap on `Cart` quantity at 100 (code review P2-2). The customer app is out of this card's scope. Until then, a line over 100 fails at checkout with the cart page's inline error.
