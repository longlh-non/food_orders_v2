---
task: comments-backend
status: passed
p0: 0
p1: 0
---

# Review: comments-backend

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | 635 tests |
| `make check` | 2 | stops at `analyze`: the 19 pre-existing `deprecated_member_use` infos (`material_ui` SDK issue); no Dart code changed in this card |

Comment-only proof: sorted non-comment `+/-` lines of `git diff -U0 backend/lib backend/bin` identical before/after (implementer, 59 lines); with comment-only lines and whitespace/commas stripped, each of the six files equals its pre-edit copy (implementer: SAME; orchestrator re-check: only blank lines differ). `dart format` changed 0 files.

## Changed paths (comments only)

`backend/lib/orders_api.dart`, `menu_api.dart`, `database.dart`, `orders_export.dart`, `staff_gate.dart`, `backend/bin/server.dart`. Out of the card's Sources, untouched: `orders_report.dart`, `report_*.dart`, `xlsx_writer.dart`, `mock_orders*.dart`, `vietqr.dart`, `shop_settings.dart`, `images_api.dart`, `menu_image.dart`, `no_sniff.dart`, `bin/seed_mock_orders.dart`.

Older comments corrected: database.dart step 6 (staff `PATCH /menu/{id}` now exists); `orders_export.dart` header (no CLI; `GET /orders/export` calls it); staff-only route lists in `OrdersApi`/`_gate`/`StaffGate` docs (now include staff-switch-to-cash and confirm-payment); `handler` comment wording.

## Findings (code-reviewer): P0 0, P1 0, P2 5

Every new or changed comment was checked against the code and the CLAUDE.md API table and found true. Deferred P2s:
1. `database.dart:219-221` (older text): step 5 comment lists `..` as blocked by the CHECK; the GLOB allows `.`. `menu_image.dart` guards it. Misleading, not new.
2. `database.dart:327-329` (older text): `removedInStep3` comment treats `soda` as a later addition; it is one of the five step-2 placeholders.
3. Shared `///` docs over several constants (`paymentCash`/`paymentBankTransfer`/`paymentMethods`, staff_gate constants); some private key sets use `//` not `///`.
4. `orders_api.dart:365-368` long unwrapped, repetitive GET /orders comment.
5. `orders_api.dart:553-556` ragged wrapping in the payment-qr comment.

## Unverified

Owner acceptance that the comments are readable and helpful.

## Verdict

**Passed**, P0: 0, P1: 0.
