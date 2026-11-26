---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, documentation, quality-gate]
blockedBy: [status-finished-backend, staff-login-backend, qr-static-backend-transitions]
securityReview: required
---

# Backend: a record of every order status change (who, from what to what, when), schema step 12

Planned 2026-11-26 from the owner's request to have the "who changed which order's status" record as its own card. It is **not** a new HTTP route, so no API table change; it does change what `CLAUDE.md` says under "Storage" and "Known limitations" (needs the owner's approval for that edit, see Goal 7). Security review is required: it records identities and sits inside every status-changing path.

`blockedBy` adds `qr-static-backend-transitions` to the two the coordinator named, so that **every** transition route exists (confirm to `paid`, the static switch to cash) before the hook is written once; otherwise a later card would have to reopen this one.

## Decisions to record (recommended default for each; the owner confirms or corrects)

- **AL1, where it lives:** a new SQLite table `order_status_log` in the same database, **schema step 12** (after step 9 status-finished, 10 qr-static, 11 staff sessions). Columns: `id INTEGER PRIMARY KEY AUTOINCREMENT`, `at` (server clock, ISO-8601 UTC), `order_id`, `from_status`, `to_status`, `via` (which door: `patch`, `confirm-payment`, `staff-switch-to-cash`, `switch-to-cash`, `renew-payment`, `expiry-sweep`, `create`), `actor_kind` (`staff-session`, `staff-password`, `customer`, `system`), `session_id` (nullable), `device_label` (nullable, copied from the session so it survives the session's removal). No foreign key to `orders` (the owner may delete old orders by hand; the log keeps the facts).
- **AL2, what "who" means:** with one shared staff account the log says **which login session** did it: the **session id** (the short public id, never the token, never a hash), plus the **device label** typed at login (`staff-login-contract` SL-j; absent = just the id). A staff action with the old password headers is `staff-password` with no session (curl). Customer routes are `customer` (no identity exists; the log can't say which customer). The expiry sweep is `system`. It says which tablet, not which person.
- **AL3, what is recorded:** every change of an order's status: `POST /orders` (creation, `from_status` null), `PATCH /orders/{id}` **that changes** the status (a 200 no-op writes nothing), `confirm-payment`, `staff-switch-to-cash`, the customer `switch-to-cash` and `renew-payment`, and the expiry cancel by the sweep or lazy check. Failed attempts (401, 409) are **not** recorded.
- **AL4, atomic with the change (recommended):** the log row is written in the **same transaction** as the order `UPDATE`, so there is never a change without its record, nor a record of a change that did not happen. If the log insert fails the change fails with the existing generic 500, never a half-write.
- **AL5, retention (recommended: a cap):** keep at most **50,000** rows; when the cap is reached the oldest rows are deleted in the same transaction (a ring buffer). Never blocks an order (unlike the 10,000-order limit, which refuses new orders). 50,000 is about 4 rows per order for the full 10,000 orders plus room; the number is a named constant. Alternative: keep forever (simple, but the file grows without bound).
- **AL6, privacy:** **no customer name, no items, no amounts, no tokens, no password, no IP** in the log: only order id, the two statuses, the door, the actor kind, the session id and the device label. The device label is staff-typed free text (<= 40 units, validated at login). Order ids are already visible to anyone who can reach `GET /orders`.
- **AL7, does the restaurant app show the history? (recommended: not in this task, a non-goal)** Reading it is a new route (`GET /orders/{id}/history`, a contract change and a screen) and a decision about who may see it. For now the owner reads it with the `sqlite3` CLI (query in the runbook). A small follow-up pair of cards (contract + route, then a read-only "Lịch sử" view behind the staff session) can be written when the owner asks. **No l10n strings in this task.**
- **AL8, reports and CSV unaffected:** neither reads the log; the numbers and files stay the same. (Moves into and out of `finished` still change the month's report; the log is how the owner finds out who did it.)
- **AL9, known limitation wording (replaces the plain-words text from `status-finished-contract`):** "Every status change is recorded (order id, from, to, time, the staff login session and its device label). There is one shared staff login, so the record can say which session did it, not which person. Old orders changed before this feature have no record. The log is only readable with the `sqlite3` CLI."

## Sources

`backend/lib/orders_api.dart` (the PATCH handler, `confirm-payment`, both switch routes, `renew-payment`, the sweep and `_expireIfOverdue`, `_publishIfChanged`, POST create), `backend/lib/staff_gate.dart` (the session id the gate exposes, from `staff-login-backend`), `backend/lib/staff_sessions.dart`, `backend/lib/database.dart` (steps 9 to 11), `backend/lib/mock_orders_db.dart` (the seed tool inserts orders directly and **stays unlogged**), the payment and PATCH tests.

## Goal

1. **Schema step 12** with the table above and an index on `order_id`; never edit shipped steps; update the step list comment.
2. A small `OrderStatusLog` class (new file) with `record(...)` taking the database, the clock and a plain `Actor` value (kind, session id, label) and enforcing the cap; every status-changing path in `orders_api.dart` calls it inside the transaction that does the `UPDATE`.
3. Each transition's guarded `UPDATE ... WHERE` stays one statement; wrap it with the log insert in `BEGIN/COMMIT`; "no row matched" (409) writes nothing.
4. The actor comes from the staff check (session id and label, or "password headers", or none for customer routes); nothing from the request body or other headers is stored.
5. The seed tool and `mock_orders_db.dart` are unchanged and write no log rows (comment why).
6. Docs in this card (`docs/runbook-local.md`, short owner section "Ai đã đổi trạng thái đơn?"): the `sqlite3` query for one order's history and for the last 50 changes, the cap, the privacy rule, that old changes have no record, that restarting after the dated backup applies step 12.
7. `CLAUDE.md` (**with the owner's approval for this task; otherwise list the lines**): "Storage" gets the step-12 bullet and the table; "Known limitations" gets AL9 in place of the plain-words text; the Layout tree names the new file. No API table change.

## Non-goals

A route or a screen to read the log, per-person accounts, recording failed attempts or customer identities, any Flutter code, changing reports or CSV.

## Tests written with the change

- migration: a version-11 database migrates to 12, every older row untouched; second open does nothing; a failure leaves version 11; versions 8 -> 12 in one open.
- each door writes exactly one row with the right `via`, `from_status`, `to_status` and actor: PATCH with a session (session id and label stored, **the token and its hash appear nowhere in the table**), PATCH with password headers (`staff-password`, no session), confirm-payment, both switch routes, renew, the sweep and the lazy expiry (`system`), POST create (`from_status` null).
- a no-op PATCH (same status), a 409, a 401, a 404 write nothing.
- atomic: force the log insert to fail (a test seam or a dropped table) -> the order keeps its old status and the reply is the generic 500.
- cap: with the constant lowered for the test, inserting past it deletes the oldest rows and keeps the newest; an order change never fails because of the cap.
- privacy: after a full flow, no column of any log row contains the customer name, an item name, a price, or the staff password.
- reports, CSV and the stream are byte-for-byte unchanged by the log (existing tests pass).
- the seed tool leaves the log empty.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make backend-test` (gate) |
| Gates | `make backend-analyze`, `make format-check` exit 0 |
| No token, hash, name, item or password is stored; failed attempts are not recorded | `security-reviewer` (review) |
| Every status-changing code path is covered (the executor lists each `UPDATE orders SET status` and where it is logged) | `code-reviewer` (review) |
| Step 12 never edits a shipped step and keeps all data | `code-reviewer` (review) |
| The owner can run the runbook query and read a real history | owner acceptance, "unverified" until done |

## Environment limits

The migration can't be undone, but it only adds a table: the dated backup before steps 9 to 12 covers it.
