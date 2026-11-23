---
executor: task-executor
scopes: [shared]
workKinds: [flutter, quality-gate]
blockedBy: [shared-l10n-infrastructure]
---

# Shared language-picker widget

**Assumes** LANG2 = runtime switching (a picker makes sense at all) and LANG4's language list/order as recorded in `i18n-multi-language-decisions`. If the owner chose LANG2 = build-time-only, this card is dropped entirely — say so instead of running it.

## Why

`shared-l10n-infrastructure` built the machinery to hold and persist a chosen locale; nothing yet lets a person change it. Both apps need the same picker (a customer and a staff member switching languages is the same interaction), so it belongs in `lib/shared/` per invariant 2 (code moves to `shared/` when both apps need it today — both do, immediately).

## Sources

`lib/shared/locale_controller.dart` (from the previous card), `lib/shared/theme.dart` (`customerTheme()`, `restaurantTheme()` — the picker must look right under both), any existing `ListenableBuilder` usage in this codebase for the pattern to follow (e.g. `lib/restaurant/pages/orders_page.dart` watching `OrderRepository`).

## Goal

`lib/shared/widgets/language_picker.dart`: a single widget, e.g. a `PopupMenuButton`/`DropdownButton` behind a globe icon, listing all 10 supported locales by **native display name** (not English names) — "Tiếng Việt", "English", "中文", "ລາວ", "Español", "Français", "Русский", "Deutsch", "한국어", "日本語" — with the current selection visibly marked. Tapping an entry calls `LocaleController.instance.setLocale(...)` and closes the menu; no confirmation dialog. Wrap it in a `ListenableBuilder` watching `LocaleController.instance` so the marked entry updates immediately and the button's own tooltip/label (if any) reflects the current language without a manual rebuild trigger.

Keep it a single widget with no app-specific logic — it takes no constructor arguments beyond optional styling, so dropping it into an `AppBar.actions` in either app is a one-line addition (done by the next two cards, not this one).

## Non-goals

No placement into either app's UI yet (`restaurant-l10n-wiring`, `customer-l10n-wiring`). No "detect my browser language" button. No search/filter box inside the menu (10 items doesn't need one — revisit only if more languages are added later).

## Tests written with the change

`test/shared/language_picker_test.dart`:
- pumps the widget standalone inside a minimal `MaterialApp`, opens the menu, asserts all 10 native names are present and the current locale's entry is visually marked (e.g. a checkmark or bold weight — pick one observable signal and assert on it).
- tapping a different entry calls `LocaleController.instance.setLocale` with the right `Locale` and the widget rebuilds to mark the new entry (no need to re-open the menu for this assertion — check the controller's state directly, or re-open and check).
- resets `LocaleController`'s stored locale between tests (it's a singleton) so tests don't leak state into each other.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| All 10 languages listed, native names, correct script per language | `code-reviewer` (review) — spelling of native names is checkable without speaking the language (they're well-known, stable strings) |
| Selecting a language updates `LocaleController` and the visible mark | `make test` |
| No new dependency, boundaries intact | `make boundaries` + `pubspec.yaml` diff empty (review) |
| `make check` green | `make check` exit 0 (gate) |
| Looks right under both `customerTheme()` and `restaurantTheme()` (contrast, tap target size) | owner acceptance in the browser — "unverified" until done |

## Environment limits

Agents can't see the rendered browser UI; owner checks visual fit under both themes.
