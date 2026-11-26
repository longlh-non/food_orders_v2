---
executor: task-executor
scopes: [shared, customer, restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [status-finished-restaurant, status-finished-customer]
---

# Remove `ready` and `delivered` from the enum, labels and all 10 ARBs

Planned 2026-11-26. Decision SF10 in `status-finished-contract`. Done last so no card before it breaks a gate. Touches the apps only to delete what the compiler then reports.

## Sources

`grep -rn "OrderStatus.ready\|OrderStatus.delivered\|statusReady\|statusDelivered\|orderMarkReady\|orderMarkDelivered\|'ready'\|'delivered'" lib test` (the executor lists every hit), `lib/shared/models/order.dart`, `lib/shared/localized_labels.dart`, `lib/shared/l10n/app_*.arb` (10), generated `app_localizations*.dart`, `lib/shared/l10n/README.md`, tests `order_calls_test`, `order_repository_refresh_test`, `order_payment_test`, `payment_qr_page_test`, `orders_page_test`, `menu_page_test`.

## Goal

- `enum OrderStatus { awaiting_payment, preparing, finished, cancelled }`; delete the two cases from every `switch`, the doc comment (line 6) and the Vietnamese label extension in `order.dart`.
- Remove `statusReady`, `statusDelivered`, `orderMarkReady`, `orderMarkDelivered` from all 10 ARBs, regenerate, commit the generated files.
- Tests that fed `ready` or `delivered` JSON now use `finished`; add one test that an order JSON with `status: "delivered"` or `"ready"` (a stale server, or an old export) is **skipped, not a crash**.

## Non-goals

New behaviour. Backend files. Docs.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| The grep above finds nothing in `lib/` and `test/` except the skip test | `code-reviewer` (review) |
| Whole project builds and passes | `make check` exit 0 (gate) |
| `arb_completeness_test` passes (all 10 files lost the same 4 keys) | `make test` (gate) |
