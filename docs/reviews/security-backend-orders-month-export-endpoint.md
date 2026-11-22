---
task: backend-orders-month-export-endpoint
status: passed
p0: 0
p1: 0
---

# Security review: backend-orders-month-export-endpoint

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-backend-orders-month-export-endpoint.md`.

- **Assets:** customer names and order contents, and the staff token.
- **Attacker inputs:** the `month` query parameter, the `X-Staff-Token` header, and stored order fields (client-supplied through POST).
- **New capability:** a bulk read of customer data behind the staff token.

## Round 1: passed. P0 0, P1 0, P2 2

- **P2-1, log injection:** `_exportFailed` interpolated the raw order id. POST allows any characters (up to 64), so a hand-corrupted row could forge or garble a log line. **Fixed:** the id is JSON-quoted.
- **P2-2, memory:** a huge month is built in memory synchronously (worst case around 1 GB at the 10,000-order cap with maximal orders). It's a self-DoS reachable only by a token holder. **Deferred** (stream or cap).

Checked and clean:
- the gate runs first, before any parsing or read;
- fail closed (no gate means 403; constant-time compare; fixed 401/403 bodies);
- the month is validated with an anchored ASCII pattern before any use, and a broken query escape gives 400;
- the file name comes only from the validated month, so there's no header injection;
- bound SQL;
- a duplicate `month` parameter takes the last value, which is still validated;
- only the id is logged, never content or the token; the 500 body is fixed;
- `no-store`;
- CORS not widened;
- `CLAUDE.md` is honest that `GET /orders` and the stream stay open and the token doesn't make customer data private.

## Re-review 1: passed. P0 0, P1 0, P2 1 (nit)

- **The fix:** `jsonEncode` escapes newline, CR and ESC, and `toString()` on a null id is safe.
- **Nit, deferred:** DEL and C1 control characters aren't escaped. Optionally strip `[\x00-\x1f\x7f-\x9f]` and cap at 64 characters.

## Gates

See `execute-backend-orders-month-export-endpoint.md`. `make check` exits 0.

## Needs owner confirmation in the real environment

- Download through Caddy and open in Excel (BOM, Vietnamese text, formula neutralisation).
- Caddy doesn't log the `X-Staff-Token` header (its access log is off by default).
