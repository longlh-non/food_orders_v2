---
executor: task-executor
scopes: [docs]
workKinds: [documentation, planning]
blockedBy: []
securityReview: required
---

# Status `finished` and staff-set status: write the API contract and the decision record (CLAUDE.md first)

Planned 2026-11-26, revised three times the same day (staff may set any status; owner answers on unpaid transfer moves, cancel being final and the "check payment" text; then the owner's second round of answers: cash may go to `awaiting_payment` by staff, the picker confirms only three targets, and the staff **session** replaces "staff ID and password on PATCH"). **Editing `CLAUDE.md` needs the owner's explicit approval for this task** (Safety policy). Without it, stop and ask. No other `status-finished-*` card and no `qr-static-*` card starts before this one is accepted (invariant 3: table first, then backend, then client). Do not run it at the same time as another card that edits `CLAUDE.md` (`staff-login-contract`, `qr-static-api-contract`, `order-status-audit-log`).

## Owner requests (verbatim, 2026-11-26)

> remove "status" and "delivered", change them to "finished" and the Wording becomes "Đã phục vụ", the flow for old transfer feature will be: awaiting_payment -> (staff confirm) -> preparing -> finished. The flow for new transfer feature: awaiting_payment -> (staff confirm) -> paid -> finished. For every order, the staff can change them all to "cancelled" if they need to.

> also, let the staff to change to any status they want

Owner answers (2026-11-26):

- "status" in the first request meant `ready`: **confirmed by the owner on 2026-11-26**. `ready` and `delivered` are removed and replaced by `finished`.
- Stored `ready` orders become `preparing` (yes). An unpaid old `bank_transfer` order may be moved to `paid` (yes). A cancelled order, cash included, can never be moved back (yes). An order cancelled by the payment expiry can still be revived by the payment routes (yes). One confirmation dialog per action (yes); it applies to the cash order's main button too (yes). Both Excel reports count `finished` only (yes). Wording as drafted (yes). The "Đã giao" shortcut for a waiting static order is dropped (yes).
- **A cash order CAN go to `awaiting_payment`, by staff only** (picker / PATCH with a staff session). The old `bank_transfer` method still cannot go to `awaiting_payment` (suspended; but setting `awaiting_payment` on an order already in it is the 200 no-op, SF6); `bank_transfer_static` may.
- **The picker asks for confirmation only when the target is `paid`, `finished` or `cancelled`.** The `paid` and `finished` dialog has the text "Vui lòng kiểm tra nếu đơn hàng đã được thanh toán"; `cancelled` has the cancel question. Every other picker move needs no dialog.
- Staff authentication on PATCH is **not** "type the staff ID and password each time" any more: it is the **staff login session** of the `staff-login-*` cards (the owner's new feature).
- A record of who changed which status: the owner wants it as its own card (`order-status-audit-log`), not "not planned".

## Which decisions are the owner's and which are still open

| Decision | State |
|---|---|
| New status `finished`, label "Đã phục vụ", flows SF2, cancel for every order | **owner decided**; reading of "status" = `ready` **confirmed** |
| Staff may change among the other statuses too | **owner decided** (SF6) |
| From unpaid transfer (`awaiting_payment`, either method): to `paid`, `preparing`, `finished`, `cancelled` | **owner decided** (SF16) |
| Cancelled is final for every order kind | **owner decided** (SF6, SF16) |
| Check-payment text on a move to `paid` or `finished`; one dialog per action; applies to the cash main button | **owner decided** (SF12, SF18) |
| Picker confirms only `paid`, `finished`, `cancelled` | **owner decided** (SF14) |
| Cash may go to `awaiting_payment` by staff only | **owner decided** (SF16) |
| What a cash order in `awaiting_payment` is | **owner decided 2026-11-26**: the method stays `cash` (option A) (SF16) |
| Can a **cash** order go to `paid`? | **owner decided 2026-11-26**: no, 409 "That status doesn't fit this payment method" (SF16) |
| Stored `ready` -> `preparing`, `paid` for old `bank_transfer`, `finished` cards have no cancel button, reports count `finished`, wording, "Đã giao" dropped | **owner decided** (yes to each) |
| Who may PATCH | **owner decided: staff session** (SF13, replaced) |
| Audit log | own card `order-status-audit-log` (SF19) |

## Planner's reading (now confirmed)

- **SF1:** remove `ready` and `delivered`, add one new final status `finished`, vi label **"Đã phục vụ"**. The other 9 languages are machine drafts, unverified (LANG5). Confirmed by the owner, 2026-11-26.
- **SF2, the normal flows** (what the buttons do):
  - cash: `preparing -> finished`
  - old transfer (QR with amount, suspended for new orders by QS12/QS14): `awaiting_payment -> (staff confirm) -> preparing -> finished`
  - new transfer (QR without amount, `qr-static-*`): `awaiting_payment -> (staff confirm) -> paid -> finished`
  - `paid` is added by `qr-static-*` (QS13). After this chain the status list is `awaiting_payment, preparing, finished, cancelled`; `qr-static-api-contract` adds `paid`.
  - SF6 and SF16 let staff leave these flows on purpose, except out of `cancelled`.

## Decisions to record

- **SF3, stored orders (schema step 9):** `delivered` -> `finished`; stored `ready` -> **`preparing`** (owner: yes). `orders.status` has **no CHECK constraint** (`database.dart` step 1), so no rebuild.
- **SF4, step numbers (revised):** `status-finished-backend` owns **step 9**; `qr-static-backend-schema-and-create` **step 10**; `staff-login-backend` **step 11** (the `staff_sessions` table); `order-status-audit-log` **step 12**. The steps are numbered by the order the cards run (see the dependency list in each card). All run on one first start after one dated backup; none can be undone.
- **SF5, cancel button:** one cancel button with a confirmation on every card that is **not `cancelled` and not `finished`** (owner: no cancel button on finished cards), built once in `status-finished-restaurant`. The picker still offers `cancelled` on a `finished` card, with the cancel confirmation.
- **SF6, the PATCH rules, restated:**
  - `status` must be a known status (`awaiting_payment, preparing, finished, cancelled`; `paid` after qr-static). `ready` / `delivered` are unknown: a stale tab's `PATCH delivered` gets **400** "status must be a known order status".
  - **Cancelled is final (owner):** a PATCH on a `cancelled` order to any **other** status is **409** for every order kind: transfer orders keep the text "Use the payment routes"; cash orders get one new fixed text "A cancelled order can't be changed". `cancelled -> cancelled` is a 200 no-op **only when `paymentDueAt` is null**. **Planner's recommendation (the owner may overrule):** `cancelled -> cancelled` on an order that still has `paymentDueAt` (cancelled by the payment expiry) is a REAL staff cancel: it clears `paymentDueAt`, so the customer's renew / switch-to-cash window ends.
  - From every non-cancelled status, staff can set every other known status, subject only to method fit (SF16). Setting the status it already has is 200, no change, and **this no-op rule is checked first and wins** over the method rules (SF16): an old `bank_transfer` order already in `awaiting_payment` PATCHed to `awaiting_payment` is 200, not 409.
  - **The write is one guarded statement** `UPDATE ... WHERE id = ? AND status = <the status just read>`, 409 when no row matched (like the payment routes), never an unguarded UPDATE.
  - The payment routes are not PATCH and keep working, so an order **cancelled by the expiry** can still be brought back by the customer (`renew-payment`, `switch-to-cash`, within 15 minutes) or by staff (`staff-switch-to-cash`, no limit). Owner: yes, keep. A staff-cancelled order can't come back by any route.
- **SF13, who may PATCH (owner: the staff session):** `PATCH /orders/{id}` becomes a staff route, checked **before** the body is read, with the same staff check as the other staff routes: 401 / 403 / 429. PATCH keeps the required check order: **staff check first, then the body, then the lookup** (no 404 before the check). What counts as proof is defined by `staff-login-contract`, which will define the session in CLAUDE.md ("Staff ID and password" section): the **staff session** (`X-Staff-Session`, from `POST /staff/login`) or the old password headers (curl and the runbook keep working). This card writes the rule in terms of "the staff check"; `staff-login-contract` fills in the session. **Open point (security review):** because PATCH is now a staff route, the 429 lockout (5 wrong tries, 60 seconds) also blocks every order status change and cancel for 60 seconds, which hurts the kitchen; how failed session tokens are counted toward the lockout is decided in `staff-login-contract`, and CLAUDE.md says so in the 429 bullet. The customer app never calls PATCH. **This is the security-relevant change of the chain: every backend and restaurant card is `securityReview: required`.**
- **SF14, the picker (owner decided the confirmations):** the card gets a "Đổi trạng thái" button listing every status the order may move to (all known statuses except the current one, filtered by SF16). The main button ("Đánh dấu đã phục vụ"), the payment buttons and the cancel button stay as one-tap fast paths. **A `cancelled` card has no picker.** A picker move opens a confirmation **only** when the target is `paid`, `finished` or `cancelled` (texts: SF12, SF18); every other move is sent at once, no dialog.
- **SF16, method fit and `paymentDueAt`:**
  - **Owner decided:** from `awaiting_payment`, a transfer order (old `bank_transfer` or `bank_transfer_static`) may be moved to `paid`, `preparing`, `finished` or `cancelled`. `paid` is legal for the old `bank_transfer` too; its own `confirm-payment` route still ends in `preparing`, and `paid` behaves like `preparing` in the kitchen (the badge counts both).
  - **Owner decided (changed):** `cash` **can** go to `awaiting_payment`, by staff only (PATCH with a staff session). The old `bank_transfer` can **not** go to `awaiting_payment` (409 "Use the payment routes"; suspended), **except** the no-op: an old transfer order already in `awaiting_payment` PATCHed to it is 200 (the no-op rule of SF6 wins); `bank_transfer_static` may (from a non-cancelled status).
  - **A cash order in `awaiting_payment` (owner decided 2026-11-26, option A):** the method **stays `cash`**, `paymentDueAt` stays null, so the sweep never touches it. The restaurant card shows "Chưa thanh toán" **for staff only** and the normal picker (no "Đã nhận chuyển khoản": it isn't a transfer). The customer app lists it in the banner with the plain status label ("chờ thanh toán") but it opens **no** payment page. Routes: `confirm-payment`, `switch-to-cash`, `staff-switch-to-cash`, `renew-payment`, `payment-qr` all answer 409 for a cash order (they all require a transfer method); staff move it on with the picker. Alternative B (PATCH turns a cash order into `bank_transfer_static`) was rejected by the owner: PATCH would then change the method, and a customer who chose cash would suddenly see a bank-transfer page.
  - **Cash -> `paid` (owner decided 2026-11-26: refused):** 409 "That status doesn't fit this payment method". "Paid" for cash is `preparing`/`finished`.
  - the method is never changed by PATCH (switching to cash stays `staff-switch-to-cash`).
  - **`paymentDueAt`:** any staff PATCH that **changes** the status sets it to null (a moved order can't be mistaken for "cancelled by the expiry"); a no-op keeps it (except `cancelled -> cancelled` on an order cancelled by the payment expiry, SF6). A cancelled order can't be PATCHed on, so an expired order's kept deadline only changes through the payment routes.
- **SF17, the sweep and the customer routes keep working:** the sweep and the lazy check only touch `awaiting_payment` orders **with** a `paymentDueAt`; a staff move never creates that pair. The payment routes keep their rules and answer 409 for any state they don't serve. A staff PATCH racing a customer route: the PATCH is also a guarded `UPDATE ... WHERE id = ? AND status = <read status>`, so whichever write matches the expected status first wins and the other gets 409 (no unguarded overwrite).
- **SF15, reports (owner: yes):** both Excel reports and `orders_report.dart` count **`finished`** only. Since status is freely editable, **moving an order into or out of `finished` changes the report of its month** (by `placedAt`), also for a month already downloaded; nothing is stored, every export recomputes. The docs card says so. (The picker dialog for a move **into** `finished` may carry a second line saying so; a move **out of** `finished` has no dialog, so only the docs warn.)
- **SF7, reports and CSV:** `deliveredOrders` is renamed `finishedOrders`. **The CSV writes the raw status**, so it reads `finished`; old exports keep `delivered`. "Delivered orders only" in `CLAUDE.md` and runbooks becomes "finished orders only". The seed tool writes `finished`.
- **SF8, wording:** chip "Đã phục vụ"; main button **"Đánh dấu đã phục vụ"** (owner: yes). Keys `statusFinished`, `orderMarkFinished`.
- **SF9, deploy order and old tabs:** stop the backend, **dated backup**, start the new backend (steps 9 to 12 as they ship), **then** reload both apps. A stale tab hides statuses it doesn't know; its `PATCH delivered` gets 400, and **any** PATCH from a stale restaurant tab gets 401 until reloaded and signed in. Rolling back the program does not roll back the data.
- **SF10, removing the old keys and enum values:** last (`status-finished-shared-cleanup`).
- **SF11, effect on `qr-static-*` (owner: yes):** the dedicated "Đã giao" button for a waiting static order is **dropped**; staff reach `finished` (or `preparing`) from `awaiting_payment` through the picker. Fast paths: paid ("Đã nhận chuyển khoản"), switch to cash, cancel.
- **SF12, confirmations:** only three (owner):
  - target **`cancelled`** (cancel button or picker): "Hủy đơn này?"; for a transfer order past `awaiting_payment` an extra line: money may have been received, any refund is by hand; and a line that **a cancelled order can't be changed back** (SF6);
  - target **`paid` or `finished`**: SF18;
  - nothing else is confirmed.
- **SF18, the check-payment text (owner decided, exact words):** a move **to `paid` or to `finished`** shows **one** confirmation dialog (owner: one dialog per action) containing exactly **"Vui lòng kiểm tra nếu đơn hàng đã được thanh toán"** (key `orderCheckPaidNote`, all 10 ARBs; vi is the owner's text, the other 9 machine drafts, unverified), with Yes / No. It applies on **every path that ends in `paid` or `finished`**: the picker, the main button "Đánh dấu đã phục vụ" (**cash orders too**, owner: yes) and "Đã nhận chuyển khoản".
- **SF19, who changed a status (owner wants it, own card):** `order-status-audit-log` records, for every staff status change and every payment-route transition, which order, from what to what, when, and which staff **session** (there is one shared staff account, so the record says which login session or device, not which person). The record holds session or device identifiers only, **never the password or the session token**. A customer `switch-to-cash` puts an unpaid order into `preparing` and is outside "who changed a status by staff"; the audit-log card covers the customer routes too, recording them as `customer`. Until it ships, `CLAUDE.md` says in plain words: nothing records who changed an order's status; once it ships the limitation text is replaced.

## Contract changes to write (CLAUDE.md)

Find every place with `grep -n -i "ready\|delivered\|Đã giao\|sẵn sàng\|PATCH" CLAUDE.md` and change it; the known ones:

1. Order rules: the `status` bullet and the "kept in sync by hand" sentence: `awaiting_payment, preparing, finished, cancelled`.
2. The PATCH bullets and the `PATCH /orders/{id}` row of the API table: **staff only** (401 / 403 / 429; "the staff check"); the SF6/SF16 rules replace "an `awaiting_payment` order can only be PATCHed to `cancelled`" and "PATCHing to `awaiting_payment` is 409": a cash order may go to `awaiting_payment` (staff only), the old `bank_transfer` may not; the "a cancelled `bank_transfer` order can't be PATCHed on" bullet becomes **"a cancelled order of any kind can't be PATCHed to another status"** with the two 409 texts; new 409 text "That status doesn't fit this payment method" (for cash -> `paid`, once `paid` exists); `paymentDueAt` cleared on a change; "a paid transfer order staff cancel by mistake can't be moved back" is now the rule for every order.
3. "Staff ID and password": add `PATCH /orders/{id}` to the staff routes (the session text itself is `staff-login-contract`); the "Accepted risk" paragraph: customer routes remain open, PATCH no longer is.
4. The export row, "Exporting a month", the two report bullets, "Both Excel reports count only..." -> `finished`, plus SF15. CSV paragraph: the status column holds the raw status.
5. "Storage": "Step 9 turns every stored `delivered` order into `finished` and every `ready` order into `preparing`. **It cannot be undone**, so make the dated backup first." replaces "There is no step 9" (later steps are added by their own cards).
6. "Deploy order" bullet (SF9).
7. "Notifications": restaurant card (`preparing` -> "Đánh dấu đã phục vụ", cancel button, picker, the check-payment dialog); customer banner lists orders that are not `finished` or `cancelled`.
8. "Contract ahead of code" note at the top of "Backend" (remove with the last `status-finished-*` task), and tenses for unshipped parts written as "will" / "planned". 8b. "Known limitations": a stale tab (SF9); staff status changes can put the books out (SF15); **in plain words:** "Nothing records who changed an order's status, when, or from what. There is only one shared staff login, so even a record could say which login session did it, not which person. A separate task (`order-status-audit-log`) plans that record."
9. The sample SQL that deletes old orders: `'delivered'` -> `'finished'`.

Do **not** edit `docs/runbook-local.md`, `docs/deploy.md` or `lib/shared/l10n/README.md`: that is `status-finished-docs`.

## Non-goals

Any code. `paid` (qr-static). The session itself (`staff-login-*`). The audit log (`order-status-audit-log`). Per-person staff accounts. Customer authentication.

## Tests

None (docs). Check every row you touched against `backend/lib/orders_api.dart` and `lib/shared/models/order.dart`.

Required of `status-finished-backend`: a test for 409 on every payment route (`switch-to-cash`, `staff-switch-to-cash`, `renew-payment`, `confirm-payment`, `payment-qr`) for a cash order in `awaiting_payment` (security N1).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Text matches SF1-SF19 as the owner confirmed them, and the two former open items (cash `awaiting_payment` stays cash; cash -> `paid` refused) are written as owner decided 2026-11-26 | owner acceptance; `code-reviewer` (review) checks the text agrees with itself |
| `grep -n -i "delivered" CLAUDE.md` finds only history sentences | `code-reviewer` (review) |
| No other file changed | `git diff --stat` in the review |
| `make check` green | `make check` exit 0 (gate) |
