---
executor: task-executor
scopes: [shared]
workKinds: [flutter, quality-gate]
blockedBy: [i18n-multi-language-decisions]
securityReview: required
---

# Shared localisation infrastructure: `intl` + `flutter_localizations`, ARB files, locale controller

Security review because this adds the first new dependencies since `backend-xlsx-writer` (invariant 5 and the Safety policy's "dependencies" trigger) — on the Flutter side this time, not the backend.

**Assumes** the owner has recorded answers to `i18n-multi-language-decisions` and they match its recommendations: LANG1 reversed (translation mechanism comes back), LANG2 = runtime switching, LANG3 = `intl` + `flutter_localizations` approved, LANG4 = `en, vi, zh, lo, es, fr, ru, de, ko, ja` with `vi` default, LANG8 = no-new-dependency `localStorage` shim. **If any recorded answer differs, rewrite this card before starting it** — in particular, a hand-rolled map (LANG3 the other way) or a `shared_preferences` dependency (LANG8 the other way) change this card's design, not just its wording.

## Why

Every other card in this set needs somewhere to pull a translated string from and something to hold "which language is this device showing right now." This card builds only that — no UI wiring, no picker widget, no app-visible change yet (the two apps keep behaving exactly as they do today; this card only adds the machinery, used starting with the next cards).

## Sources

`pubspec.yaml` (root — single Flutter package for both apps, confirmed: there is one `pubspec.yaml` for `lib/customer` and `lib/restaurant`, separate from `backend/pubspec.yaml`), `lib/shared/chime.dart` / `chime_web.dart` / `chime_stub.dart` (the conditional-import pattern to copy for locale persistence), `docs/reviews/execute-vi-translate-shared-and-restaurant-ui.md` (has several of the English strings VI2 deleted, needed to seed `app_en.arb`), the current hardcoded Vietnamese in `lib/shared/models/order.dart` (`OrderStatusLabel`), `lib/restaurant/main.dart`, `lib/restaurant/pages/orders_page.dart`, `lib/restaurant/pages/export_month_dialog.dart`, `lib/restaurant/widgets/staff_login_dialog.dart` (needed to seed `app_vi.arb` — the Vietnamese wording the owner already accepted should be reused verbatim, not redrafted).

**Environment limit on sources:** several files in this list show as locally modified in the working tree ahead of this card (per the repo's current `git status` at planning time — `lib/restaurant/main.dart`, `lib/restaurant/pages/export_month_dialog.dart`, `lib/restaurant/pages/orders_page.dart`, `lib/restaurant/widgets/staff_login_dialog.dart`, `lib/shared/models/order.dart`, `test/*`). Inventory their actual on-disk contents fresh when this card starts; don't rely on what `docs/tasks/done/vi-translate-shared-and-restaurant-ui.md` describes as the only source of truth.

## Goal

1. Add dependencies to the root `pubspec.yaml`: `flutter_localizations` (`sdk: flutter`) and `intl` (pinned to the version `flutter_localizations` resolves to — don't hand-pick a conflicting one). Set `generate: true` under the `flutter:` section and add `l10n.yaml` at the repo root pointing at an ARB folder under `lib/shared/l10n/` (e.g. `arb-dir: lib/shared/l10n`, `template-arb-file: app_vi.arb` since Vietnamese is the current default and most-reviewed language, `output-localization-file: app_localizations.dart`).
2. Create one ARB file per locale: `lib/shared/l10n/app_vi.arb`, `app_en.arb`, `app_zh.arb`, `app_lo.arb`, `app_es.arb`, `app_fr.arb`, `app_ru.arb`, `app_de.arb`, `app_ko.arb`, `app_ja.arb`. Seed every key needed by the **already-landed** Vietnamese strings in the sources above (roughly 25–30 keys across `OrderStatusLabel`, `orders_page.dart`, `export_month_dialog.dart`, `staff_login_dialog.dart`, `main.dart`'s app titles) plus interpolated-argument placeholders (`{orderId}`, `{customerName}`, `{count}`, etc. — use ICU placeholders, not string concatenation, so plural/number formatting is available later). `app_vi.arb` reuses the owner-accepted Vietnamese text verbatim. `app_en.arb` reconstructs the pre-VI2 English text from `docs/reviews/execute-vi-translate-shared-and-restaurant-ui.md` and git history where available; where the exact original wording isn't recoverable, draft a plain English equivalent and flag it in the PR/review notes as redrafted-not-restored. The other 8 are agent-drafted machine-translation-quality drafts (per LANG5) — **every non-Vietnamese, non-English language's wording is "unverified" until a fluent reviewer confirms it; say so in the acceptance table, don't claim it's correct.**
   - This card seeds only the strings that exist **today**. It does not add strings for `menu_page.dart`, `cart_page.dart`, `add_food_dialog.dart`, or any other customer-app file — those are `customer-l10n-wiring`'s job, and that card adds its own keys to all 10 ARB files.
3. `lib/shared/locale_controller.dart`: a `ChangeNotifier` singleton (`LocaleController.instance`), holding the current `Locale`, with `setLocale(Locale)` and a list of the 10 supported locales plus `vi` as the compiled-in default. On construction (or an explicit `init()` called from each `main.dart`, following the `OrderRepository.init()` pattern already used), it reads a previously-saved choice from `localStorage` via a conditional-import pair (`lib/shared/locale_storage.dart` → `locale_storage_web.dart` on web, `locale_storage_stub.dart` on the Dart VM, mirroring `chime.dart`'s three-file shape exactly, so `flutter test` doesn't try to compile web-only APIs). `setLocale` persists the choice the same way and calls `notifyListeners()`.
4. `lib/shared/l10n.dart`: a small barrel re-exporting the generated `AppLocalizations` class and `LocaleController`, so `lib/customer/**` and `lib/restaurant/**` both import one `shared/` path (keeps invariant 1 clean — neither app reaches into the other, and both reach into `shared/` the same way they already do for `OrderRepository`).
5. Each `main.dart` (not wired to real UI strings yet, that's the next cards) gets its `MaterialApp` updated to accept `locale: LocaleController.instance.locale`, `localizationsDelegates: AppLocalizations.localizationsDelegates`, `supportedLocales: AppLocalizations.supportedLocales`, listening via `ListenableBuilder` the same way `OrderRepository` is watched elsewhere — this is infrastructure wiring (the app must be able to show a different language once asked), not string-by-string translation.

## Non-goals

No change to any widget's visible text yet (that's `restaurant-l10n-wiring` / `customer-l10n-wiring`). No picker UI (`shared-locale-picker-widget`). No backend text (LANG6 — out of scope). No `shared_preferences` or any dependency beyond `intl`/`flutter_localizations`. No `lib/dev/demo.dart` changes beyond what's needed for it to keep compiling (it imports both apps already per invariant 1's exception).

## Tests written with the change

- `test/shared/arb_completeness_test.dart`: parses every `lib/shared/l10n/app_*.arb` file as JSON directly (not via generated code) and asserts all 10 files have exactly the same set of message keys (catches a missing translation in any one language immediately, without needing a fluent reviewer).
- `test/shared/locale_controller_test.dart`: `setLocale` notifies listeners and updates `.locale`; defaults to `vi` when nothing is stored; a fake/injectable storage (not the real web shim) proves persistence is attempted on every `setLocale` call. Runs on the Dart VM via the stub shim, like `chime_stub.dart`'s tests do.
- `test/shared/app_localizations_smoke_test.dart`: a trivial `MaterialApp` pumped once per supported locale (10 pumps) with a `Builder` reading `AppLocalizations.of(context)!` and rendering one known key, asserting the text matches that locale's ARB value exactly (catches a key that fails to generate or resolve for a given locale).
- Update any existing test that constructs `MaterialApp` directly for `CustomerApp`/`RestaurantApp` top-level widgets, so it still compiles with the new required localization delegates (no behaviour assertion changes here — that's the wiring cards).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| `intl` + `flutter_localizations` are the only new dependencies; versions pinned; licences and transitive packages checked | `security-reviewer`, `code-reviewer` (reviews) |
| All 10 ARB files exist with an identical key set | `test/shared/arb_completeness_test.dart` via `make test` |
| `LocaleController` persists and restores a choice; defaults to `vi` | `make test` |
| Both apps' `MaterialApp`s accept the generated delegates and build for all 10 locales without throwing | `make test` (smoke test) + `make analyze` |
| Boundaries intact (`lib/shared` still imports neither app) | `make boundaries` |
| `make check` green | `make check` exit 0 (gate) |
| Vietnamese wording unchanged from the owner-accepted version; English wording is a faithful reconstruction or clearly flagged as redrafted | `code-reviewer` (review), owner spot-check — "unverified" until done |
| The other 8 languages' wording is correct | **not claimed here** — explicitly "unverified," pending LANG5's native/fluent review, tracked for closeout in `docs-i18n-runbook-and-claude-md` |

## Environment limits

Agents can't judge wording in Chinese, Lao, Russian, Korean or Japanese with confidence; this card produces a technically-complete, functionally-testable set of translations whose **wording correctness** is explicitly out of this card's ability to verify. The first `flutter pub get` after adding dependencies needs network access.
