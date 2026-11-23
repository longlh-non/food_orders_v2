---
task: docs-payment-and-reports
status: passed
p0: 0
p1: 0
---

# Review: docs-payment-and-reports

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make check` | 2 | stops at `analyze`: 20 infos, all `deprecated_member_use` on the `package:flutter/material.dart` import (the 19 pre-existing plus the one in `test/menu_sold_out_test.dart` from `customer-menu-sold-out-items`); no code changed in this card |
| `diff` of the "Engineering contract" half of `CLAUDE.md` against HEAD | identical | orchestrator re-checked after the fix round; only the project half was edited |

## Changed paths (documentation only)

`CLAUDE.md` (project half; owner approved this edit for the task) and `docs/runbook-local.md`. No code or tests.

CLAUDE.md: Layout (new customer, restaurant and backend files, plus a note that the tree lists main files only); new "Payment by bank transfer" and "Shop and bank settings" sections; "Order rules" deploy-order note replaces the stale "until the shared-model card lands" bullet; "Code" list; "Storage" step 8 restart note and "no step 9"; rewritten "Exporting a month" (CSV default, summary, detail, restaurant dialog); "Staff ID and password" route list; "Notifications" (no Accept step, chime and badge rules); "Known limitations"; the "compiled binary" sentence now says the backend is built with `dart build cli`. The API table rows were checked against `orders_api.dart`: no drift, unchanged.
runbook-local: startup lines, schema version 6 → 8 with steps 7/8, new sections 4a (shop and bank settings) and 4b (monthly reports), configuration table, known gaps.

## Findings (code-reviewer, fact check against the code): P0 0, P1 1, P2 6

Verified correct (payment routes and windows, export check order, `ShopSettings` rules, VietQR reference, schema steps, report contents, customer and restaurant UI text and rules, Layout files, `dart build cli`, no real bank details or secrets).

**P1 (fixed):** `docs/runbook-local.md:191` quoted the old English "Wrong staff ID or password"; the app says "Sai mã nhân viên hoặc mật khẩu" (`export_month_dialog.dart:149`, `orders_page.dart:308`). Corrected; the string was grep-checked against the code. Not re-sent to a reviewer: a one-string correction.

**P2 fixed in the same pass:** runbook line 56 stale English ("Couldn't load the menu" / "Retry" → "Không tải được thực đơn" / "Thử lại", grep-checked in `menu_page.dart`); CLAUDE.md control-character rule now says "inside the value" (a leading or trailing one is trimmed, `shop_settings.dart`); runbook line 163 now lists the staff payment buttons; runbook section 8 now says which `cd-*` cards remain open; Layout note "main files only".

**Deferred / no action:** the archived card still names `payment_page.dart` (history; the real file is `payment_qr_page.dart`). Card/code conflicts resolved by the implementer: the chime does not fire again for a known id, except that an order already on screen as `awaiting_payment` when the page opens rings once when it becomes `preparing` (documented).

## Unverified (owner acceptance)

QR scanning with a real banking app, the audio chime in a browser, Excel rendering of the two reports, and following the runbook steps end to end (the multi-line start command in 4a was only syntax-tested; pasting the whole block into a terminal without bracketed paste could feed lines to `read`).

## Verdict

**Passed**, P0: 0, P1: 0 (the one P1 was fixed).
