---
task: restaurant-menu-add-client-and-state
status: passed
p0: 0
p1: 0
---

# Security review: restaurant-menu-add-client-and-state

No P0 or P1 (P2 3).

Checked clean: credentials only in the two headers on the constant `/api/menu` path (never in the URL or body); fixed exception texts, no reply text, `StaffCredentials.toString` hidden, no `print`/`debugPrint`; header injection blocked (`isSendable` accepts only printable ASCII, `ArgumentError` before sending); credentials read into a local and not kept past the holder, 401 clears the holder; the `_adding` flag is set before the first `await` and reset in `finally`, no notify after dispose; reply parsed defensively (201 only, `MenuItem.fromJson` type checks, `FormatException`/`TypeError` mapped to a fixed `other`, text passed through `displayText`).

## Findings

- P2-1 **fixed**: a reply repeating an existing id would have produced two rows with one id; `addItem` now replaces that row (new test).
- P2-2 deferred: `addItem` doesn't enforce its own validation or trimming (the server is the real control; the form card should validate and trim before building `NewMenuItem`).
- P2-3 deferred: `_hasControl` in the app misses bidi and zero-width characters, as does the server (see `security-backend-menu-staff-add-endpoint.md`, P2-1); `displayText` strips them on screen.

## Unverified

The server's actual 201/409/503/401/403/429 replies against a real backend, and the proxy's 413 behaviour.
