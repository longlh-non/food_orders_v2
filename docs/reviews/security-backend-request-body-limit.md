---
task: backend-request-body-limit
status: passed
p0: 0
p1: 0
---

# Security review: backend-request-body-limit

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-backend-request-body-limit.md`.

- **Assets:** backend memory, the SQLite file and its disk, whether orders can be placed, and the event loop (sqlite is synchronous).
- **Boundaries:** wifi → Caddy/nginx on :80, where the limit applies; wifi → :3000 directly, where it didn't.

## Round 1: changes requested. P0 0, P1 1, P2 2

- **P1-1, the body limit could be bypassed:**
  - The backend bound `0.0.0.0:3000`, and `readAsString()` has no size cap.
  - So any LAN device could POST a huge body straight to `<laptop-ip>:3000`. The only control was "the owner checks ufw", and ufw may be inactive.
  - Fix: bind to loopback by default.
- **P2-1:** items per order and id length were bounded only by the proxy. That makes `GET /orders` up to 500 large rows, and large-payload orders can fill the 10,000 cap with a lot of disk.
- **P2-2:** the order cap turns a flood into a lasting "can't place orders" outage until someone deletes rows. That's accepted under "no auth", but the owner needs a way to recover.

Checked and clean:
- **Caddy:** `request_body` sits before `reverse_proxy` inside `handle_path`. `MaxBytesReader` answers 413 for a body with Content-Length over the cap; a chunked body is cut off mid-stream (the client may see 413 or 502, and the backend gets at most the cap).
- **nginx:** `client_max_body_size` in `location` also applies to chunked bodies, and request buffering is on by default.
- **No COUNT/INSERT race** (synchronous sqlite, no `await` between them).
- **Validation:** `quantity is int` rejects `1e2`; prices reject Infinity and NaN; messages never reflect input.
- **noSniff:** placement is fine; the SSE hijack passes through untouched.
- No new dependencies.

## Fix round 1

- **P1-1:** `bin/server.dart` binds `InternetAddress.loopbackIPv4` by default. `BIND_ADDRESS` overrides it, and an empty value counts as unset. `CLAUDE.md` explains this, with ufw as a second layer.
- **P2-1:** `maxItemsPerOrder` = 50 and `maxIdLength` = 64 (order, item and topping ids), with tests.
- **P2-2:** `CLAUDE.md` explains how to make room: stop the backend, back up, then delete old delivered or cancelled orders.

## Re-review 1: passed. P0 0, P1 0, P2 0

- With the code default, nothing on the LAN can reach `:3000`. Caddy (`localhost:3000`) and nginx (`127.0.0.1:3000`) still reach the backend.
- `BIND_ADDRESS` is an operator setting, not attacker input.
- An order is now in practice bounded by the 64 KB proxy limit. A tighter cap is optional and not raised.

## Gates

See `execute-backend-request-body-limit.md`. `make check` exits 0.

## Needs owner confirmation in the real environment

- Caddy 413 for a 70 KB body, sent both with Content-Length and chunked.
- `nginx -t`.
- After restarting the backend: `customer.local` works through Caddy (and on iOS over mDNS), and `ss -ltn | grep 3000` shows `127.0.0.1`.
