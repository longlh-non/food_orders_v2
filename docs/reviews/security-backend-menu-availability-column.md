---
task: backend-menu-availability-column
status: passed
p0: 0
p1: 0
---

# Security review: backend-menu-availability-column

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-backend-menu-availability-column.md`.

- **Assets:** `backend/data/orders.db`, and the `GET /menu` response.
- **Attacker input:** nothing new. No request parameter, body or header was added. The column is only writable through the `sqlite3` CLI, which needs local shell access.

## Round 1: passed. P0 0, P1 0, P2 0

Checked and clean:
- **SQL:** the `/menu` SELECT and the step-6 ALTER are constant strings.
- **CHECK:**
  - INTEGER affinity turns `'1'` and `1.0` into a clean `1`; `'abc'` and `1.5` fail the CHECK; NULL is blocked by NOT NULL.
  - The endpoint renders anything but exactly `1` as false, so a bad value fails closed: it shows as sold out, not as orderable.
- **Migration 5 → 6:** a plain `ADD COLUMN` with a default, not a rebuild, so there's no data-loss risk. BEGIN/COMMIT/ROLLBACK, the version is bumped inside the transaction, and it runs once.
- **Nothing new is writable over HTTP.** No stack traces or internals are exposed.
- **Dependencies:** none added.

## Notes for the next cards

- **`backend-menu-staff-write-endpoint`:** check `available` strictly as a JSON boolean before writing; the CHECK alone would accept `"1"`.
- **`POST /orders`:** doesn't check `available` until MENU-DB3. That's expected.

## Gates

See `execute-backend-menu-availability-column.md`. `make check` exits 0.

## Needs owner confirmation

`curl http://customer.local/api/menu` against the real database, after a dated backup.
