---
executor: task-executor
scopes: [shared, restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [restaurant-orders-show-toppings]
---

# Vietnamese UI text: order status labels and the restaurant app

## Why

Owner asked to translate the app to Vietnamese. Plan: replace the English text directly in the widgets (no new package; English is gone). This card does the part both apps share (`OrderStatus.label`) plus the restaurant app. The customer app is the next card. Assumes decisions VI1 (Vietnamese only), VI2 (direct replacement) and VI3 (prices stay as they are) are accepted; if the owner picks otherwise, rewrite these cards first.

## Sources

`lib/shared/models/order.dart` (`OrderStatusLabel`, about 6 strings), `lib/restaurant/pages/orders_page.dart` (about 12 strings: AppBar title, SnackBar text, Accept action, empty state, 4 action-button labels, "Order #...", "Total:"), `lib/restaurant/main.dart` (app `title`), `test/widget_test.dart` (`find.text('Incoming Orders')`).

## Goal

1. Every user-visible English string in the files above becomes Vietnamese. Agent drafts the wording, owner accepts it (acceptance table).
2. Keep interpolation (`#id`, customer name, counts) working and keep Dart-side enum names and JSON values (`pending`, `accepted`, ...) untouched. Only the label changes.
3. Update the existing restaurant widget test to look for the new Vietnamese AppBar title.

## Non-goals

No `intl`/`flutter_localizations`/ARB files, no language toggle, no currency or `$` change (the `$` price format stays; see VI3), no date formatting, no menu item names, no backend text, no customer app files, no `web/` files, no `lib/dev/demo.dart`.

## Tests written with the change

- Update `test/widget_test.dart` restaurant test to expect the Vietnamese title.
- New widget test: pump `OrdersPage` with an order in each status and assert the Vietnamese action label and status chip text render (at least pending and ready).
- New unit test: every `OrderStatus` value has a non-empty `label` and none still equals its English text.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| No English UI text left in the listed files | `code-reviewer` (review) |
| Status chips and action buttons show Vietnamese in the restaurant app | `make test` (widget tests) |
| Boundaries intact, no new dependency | `make boundaries` + `git diff` of `pubspec.yaml` empty (review) |
| `make check` green | `make check` exit 0 (gate) |
| Vietnamese wording is acceptable and diacritics render correctly | owner acceptance in the browser at `http://restaurant.local` - "unverified" until done |
| Same on iPhone Safari | owner acceptance on the phone - optional |

## Environment limits

Agents cannot judge natural wording or see the browser. The owner reads and approves the Vietnamese.

## Order change (owner, 2026-11-11): runs after the toppings work

The owner let the toppings work go first, so this card now waits for `restaurant-orders-show-toppings`. That card adds English text for the toppings shown on each order, which this card must translate. Inventory the strings again when this card starts.

## Decided 2026-11-11: currency is VND (CUR1 / VI3)

The owner chose **VNĐ** for the whole app. The display change is card `currency-vnd-display` (prices shown as `10.000 VNĐ`, whole numbers). VI3 is no longer an open question.

## Added 2026-11-12: export button text

If `restaurant-orders-month-export-button` is done before this card, translate its English text too: the "Export month" tooltip, the dialog title, labels and buttons, and the error messages.

## Added 2026-11-12: status-update failure text

If `restaurant-orders-status-update-shows-failure` is done before this card, also translate its new SnackBar text 'Couldn't update the order. Try again.' (add a widget-test assertion for the Vietnamese message). Inventory the strings again when this card starts.
