---
executor: task-executor
scopes: [docs]
workKinds: [documentation, quality-gate]
blockedBy: [status-finished-backend, status-finished-shared-cleanup, staff-login-restaurant]
---

# Docs: runbook, deploy checklist and language record for `finished` and staff-set status

Planned 2026-11-26, revised for staff-set status, "cancelled is final", the three-target confirmation rule, cash `awaiting_payment` and the staff session. `CLAUDE.md` was already rewritten in `status-finished-contract`; this card does **not** edit it. If its final `grep` still finds an old mention, list the lines for the owner (editing `CLAUDE.md` needs fresh approval). The login and logout text belongs to `staff-login-docs`; this card only says "signed in".

## Sources

`docs/runbook-local.md` (line ~129-132: the `DELETE ... status IN ('delivered', 'cancelled')` example; line ~137: mock orders "adds `delivered` and `cancelled`"; line ~354: "Both Excel reports count only `delivered` orders"; the staff ID and password section; "Language review log"), `docs/deploy.md` (release steps, backup before schema steps, the Docker update steps; **it has uncommitted owner edits: run `git status` and `git diff docs/deploy.md` first and change only the lines this card needs**), `lib/shared/l10n/README.md`.

## Goal

- `docs/runbook-local.md`: replace each `delivered` with `finished` (the `DELETE` example must use `'finished'`, or it would delete nothing after step 9); a short owner note "Trạng thái 'Đã phục vụ' và đổi trạng thái":
  - the flow per payment type; old `ready` orders came back as "preparing" and need one tap;
  - changing a status needs a staff login (details in the staff-login section);
  - the "Đổi trạng thái" picker; that moving to "Đã thanh toán" or "Đã phục vụ" (also the main button, also for cash) first asks "Vui lòng kiểm tra nếu đơn hàng đã được thanh toán"; moving to "Đã hủy" asks the cancel question; **other moves are sent without asking**;
  - staff can move a **cash** order to "Chờ thanh toán" (it stays a cash order; only staff and the customer's banner see it);
  - **an order cancelled ("Đã hủy") can never be moved back** by the app (a cancel is final; only an expired transfer order can still be brought back by the customer within 15 minutes or by staff with "Chuyển sang tiền mặt");
  - **moving an order into or out of "Đã phục vụ" changes the Excel report of its month**, also for a month already downloaded: download it again;
  - **nothing records who changed a status** until `order-status-audit-log` ships (one shared staff login); say it plainly;
  - the order of steps: stop the backend, dated backup, start, then reload both apps (a tab left open from before gets 401 or 400 until reloaded and signed in).
- `docs/deploy.md`: release checklist row and the Docker update steps: "step 9 runs on the first start: dated backup first (cannot be undone), restart the backend **before** reloading the apps". No env var change.
- `lib/shared/l10n/README.md` and the "Language review log": the new keys (`statusFinished`, `orderMarkFinished`, `orderCheckPaidNote`, `orderCancel*`, `orderChangeStatus*`), the removed keys, and that the 9 non-vi texts are machine drafts, unverified.

## Non-goals

Any code. `CLAUDE.md`. The qr-static docs (`qr-static-docs`, which adds step 10), the login docs (`staff-login-docs`, step 11), the audit docs (`order-status-audit-log`, step 12).

## Tests

None. Re-read each command against the files it names.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| `grep -n "delivered" docs/runbook-local.md docs/deploy.md` finds only history sentences | `code-reviewer` (review) |
| The owner's uncommitted `deploy.md` edits are untouched | `git diff` in the review |
| No secret, env value or personal detail in the text | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| The owner can follow the backup, restart and report-redownload steps | owner acceptance, "unverified" until done |
