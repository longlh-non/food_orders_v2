---
task: customer-l10n-wiring
status: passed
p0: 0
p1: 0
---

# Review: customer-l10n-wiring

**Fork applied:** `vi-translate-customer-ui` had already run (customer UI was hardcoded Vietnamese). The old English is not in git history, so English is **redrafted, not restored**.

## Gates

| Command | Exit | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | |
| `make analyze` / `make check` | 2 | 27 `deprecated_member_use` infos: 25 baseline + 2 `flutter/material.dart` imports in the new test files (`test/customer_l10n_test.dart`, `test/helpers/l10n_app.dart`; they need `MaterialApp`). No other kind of finding. |

## Findings (code-reviewer): P0 0, P1 0, P2 4 — deferred

1. Analyze gate red from the documented baseline (+2 same-class infos).
2. `menu_page.dart:97` `notes.join(' ')` joins two sentences with an ASCII space; cosmetic in ja/zh/lo, only when both notes fire.
3. `app_zh.arb:101` `customerDishPrice` uses ASCII `:`, other zh keys use `：`.
4. `cart_page.dart:214-223` quantity +/- buttons have no tooltip/semantics label (pre-existing gap).

Passed checks: no remaining hardcoded user-visible literal in `lib/customer/**`; 123 keys per ARB with matching placeholders and plural forms; menu names and `formatVnd` untouched; picker in the MenuPage AppBar; `onGenerateTitle`; state classes free of context; `mounted` checks; banner overflow fixed; `lib/restaurant`, `pubspec`, `web/` untouched.

## Unverified (owner acceptance)

All 10 languages rendered in a browser and iPhone Safari (Lao/CJK glyphs, cart form, payment QR page); the picker; tab title via `onGenerateTitle`; demo split view; wording of the 8 drafted languages (lo and ru plurals especially). Fit tests use the Ahem font.

## Verdict

**Passed**, P0: 0, P1: 0.
