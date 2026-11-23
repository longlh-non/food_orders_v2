---
executor: task-executor
scopes: [docs]
workKinds: [planning, documentation]
blockedBy: []
---

# Open decisions: multi-language support (English, Vietnamese, Chinese, Lao, Spanish, French, Russian, German, Korean, Japanese)

No code changes in this card. It exists to record the decisions the owner must make before any card below it (`shared-l10n-infrastructure`, `shared-locale-picker-widget`, `restaurant-l10n-wiring`, `customer-l10n-wiring`, `docs-i18n-runbook-and-claude-md`) may start. **Every one of those cards has `blockedBy` including this slug or a card that does.** Until the decisions below are answered, this whole effort is paused.

## LANG1 — this reverses a decision made earlier the same day (read first)

Three cards landed in this session, now in `docs/tasks/done/`: `vi-translate-shared-and-restaurant-ui.md`, `vi-translate-customer-ui.md`'s sibling work, and `comments-shared.md`. The first of those recorded owner decisions **VI1** ("Vietnamese only, not multi-language") and **VI2** ("direct replacement — hardcode the Vietnamese strings straight into the widgets, no new package, English is gone"). As a direct result, `lib/shared/models/order.dart` (`OrderStatusLabel`), `lib/restaurant/main.dart`, `lib/restaurant/pages/orders_page.dart`, `lib/restaurant/pages/export_month_dialog.dart`, `lib/restaurant/widgets/staff_login_dialog.dart`, and `web/index.html` / `web/manifest.json` now contain hardcoded Vietnamese strings with the English originals **actually deleted** — not commented out, not kept as a fallback.

A 10-language "manage more languages" request is not a pure addition on top of that work. It requires:
- reversing VI2 (bringing back a translation mechanism instead of hardcoded literals), and
- recreating the English strings that VI2 deleted (they are not in the current source; they are recoverable from this session's diffs and from `docs/reviews/execute-vi-translate-shared-and-restaurant-ui.md`, which quotes several of the old English strings — the rest would need re-drafting), and
- writing 8 more languages' worth of new strings on top of that.

**This card does not assume the owner wants this reversal just because they asked for 10-language support.** The owner must explicitly confirm, in writing, in this file (add a `## Decided` section below, dated, the same way `vi-translate-shared-and-restaurant-ui.md` recorded VI1–VI3), before `shared-l10n-infrastructure` starts. Given how recent and deliberate VI1/VI2 were, treat silence as "not yet confirmed," not as implicit approval.

## LANG2 — what "manage more languages" means

Two readings:
- **(a) Runtime switching** — a picker lets a customer or a staff member change the app's language themselves, per device/browser, at any time. This is what "manage" most naturally reads as, and is the planning assumption for every card below.
- **(b) Build-time / deploy-time locale** — one deployed instance serves one fixed language (like today's Vietnamese-only setup), just made configurable instead of hardcoded, with no in-app picker.

**Recommendation: (a).** The cards below assume runtime switching. If the owner wants (b) instead, `shared-locale-picker-widget`, and the picker-wiring parts of `restaurant-l10n-wiring` / `customer-l10n-wiring`, should be dropped and replaced with a single build-time config value — smaller change, say so before `shared-l10n-infrastructure` starts so its design doesn't build a picker nobody wants.

## LANG3 — mechanism, and the new-dependency approval it needs

Architecture invariant 5 (`CLAUDE.md`): "Adding Provider/Riverpod/Bloc/GetX, a router package, or any new dependency needs the owner's approval first." Two real options:

- **`intl` + `flutter_localizations` + ARB files** (Flutter's standard path; `flutter_localizations` ships in the Flutter SDK itself, `intl` is a pub.dev package it depends on). Idiomatic, handles plurals/number formatting, and is what every Flutter i18n tutorial uses. **Recommended** — reinventing this for 10 languages by hand is real, avoidable work.
- **A hand-rolled `Map<String, Map<String, String>>`** keyed by locale and string key, no new package. Lighter, fully under the project's control, but the project now owns plural rules, interpolation, and a growing hand-written map for 10 languages with no tooling to catch a missing key in one language — exactly the kind of wheel-reinventing `intl` exists to avoid.

**Either way this needs the owner's explicit yes before `shared-l10n-infrastructure` starts**, consistent with how `backend-xlsx-writer.md` recorded its own dependency approval ("RPT4, decided (owner, 2026-11-19): approve both... any other new package still needs the owner's approval first"). The cards below assume `intl` + `flutter_localizations` is approved; if the owner picks the hand-rolled map instead, rewrite `shared-l10n-infrastructure` before starting it (no dependency approval needed for that path, but the card's design changes materially).

## LANG4 — exact languages, locale codes, and the default

The request lists 10 languages by name, which maps to codes but has real ambiguity for two of them:
- Chinese: simplified (`zh`, `zh-Hans`) or traditional (`zh-Hant`)? Mainland, Taiwan, or Hong Kong conventions differ.
- Spanish / French: a single generic `es` / `fr`, or regional variants (`es-ES` vs `es-419`, `fr-FR` vs `fr-CA`)?
- Lao: `lo`.
- The rest are unambiguous: `en`, `vi`, `ru`, `de`, `ko`, `ja`.

Also decide:
- **Default/fallback locale** when nothing is stored yet for a device. Recommendation: Vietnamese (`vi`), matching current behaviour and the shop's primary customers, with every other language one tap away.
- **Order of appearance** in the picker (recommendation: Vietnamese and English first, then the rest alphabetically by native name).

**Recommendation:** `zh` (simplified), generic `es` and `fr` (no regional split) unless the owner knows their customers need a specific region, default locale `vi`. Confirm or correct before `shared-l10n-infrastructure` writes the ARB file set, since the file names and `supportedLocales` list are baked into that card.

## LANG5 — who provides the translated text, and its quality

Vietnamese was translated by the agent and explicitly accepted by the owner reading the live app ("Vietnamese wording is acceptable... owner acceptance in the browser"). Doing that for 9 more languages, several in scripts the owner may not read (Chinese, Lao, Russian, Korean, Japanese), removes the owner's ability to check wording the same way.

Decide:
- Does the owner (or a translation service they arrange) supply the actual strings per language, or is the agent expected to machine-translate all 9 as a first draft?
- If machine-translated: who reviews them, and how, given the owner likely can't read most of these scripts? (E.g. a native-speaker review step per language before `docs-i18n-runbook-and-claude-md`'s card closes, or accept the risk and ship first-draft machine translations with a documented caveat.)

**Recommendation:** agent drafts all strings (English and Vietnamese first, since those are re-derivable and ownerreadable; the other 8 as machine-translated drafts), every language's acceptance criteria explicitly says "unverified" for wording until a native or fluent speaker confirms it — mirroring how the Vietnamese cards treated "wording is natural" as owner acceptance, not an agent-gated check. This is a real risk with 10 languages that the owner should weigh before approving LANG1/LANG3.

## LANG6 — backend-generated text

The CSV export (`GET /orders/export`) and the two just-landed `.xlsx` reports (`docs/tasks/done/backend-report-summary-xlsx.md`, `backend-report-detail-xlsx.md`) hardcode Vietnamese column headers and labels ("Chi tiết tháng", "Ngày tháng năm", etc.) in `backend/`, a plain Dart package with no Flutter dependency (invariant 4). `vi-translate-shared-and-restaurant-ui.md`'s own non-goals already drew this line once: "no backend text."

Decide: is backend-generated output (CSV headers, xlsx report labels, HTTP error message bodies) in scope for this effort, or purely the Flutter UI?

**Recommendation: out of scope for this round**, consistent with the existing precedent, and because it raises its own unanswered questions this request doesn't address (does staff pick an export language per download, or is the shop's own bookkeeping always Vietnamese regardless of what a customer's phone shows?). If the owner wants it in scope, say so and a follow-up card gets planned once that question is answered — not created speculatively here.

## LANG7 — the still-active `vi-translate-customer-ui` card

`docs/tasks/vi-translate-customer-ui.md` is unblocked and not yet run. If it runs before the owner answers LANG1, it does to `lib/customer/**` exactly what already happened to the restaurant app: hardcode Vietnamese and delete the English, one more surface this effort would then have to un-delete and re-wrap in translation infrastructure.

This card does not edit `vi-translate-customer-ui.md` — changing another active card's execution order is bigger than what was asked here. Flagging it instead: **the owner should decide, before answering LANG1, whether to pause or remove `vi-translate-customer-ui` from the active queue.** If it's left as-is and happens to run first, `customer-l10n-wiring` below still works (it inventories the customer files fresh, whatever state they're in) but does strictly more work (re-deriving the deleted English for the customer app too, on top of what the restaurant side already needs).

## LANG8 — where the chosen language is stored per device

A `ChangeNotifier` holding the current locale is easy; keeping it across a page reload on the web needs some storage. Two paths:
- **Browser `localStorage`**, read/written through a conditional-import shim (`lib/shared/locale_controller.dart` → `_locale_storage_web.dart` / `_locale_storage_stub.dart`), mirroring the existing `chime.dart` / `chime_web.dart` / `chime_stub.dart` pattern. **No new package.**
- A persistence package such as `shared_preferences`. Also works on web, but is a second new dependency on top of `intl`/`flutter_localizations`, needing its own approval under invariant 5.

**Recommendation:** the conditional-import `localStorage` shim — it needs no new approval and the codebase already has the pattern. The cards below assume this. If the owner would rather approve `shared_preferences`, say so before `shared-l10n-infrastructure` starts.

## Process flag (not a product decision, but easy to miss)

Editing `CLAUDE.md` itself (the "Layout" section gains an `lib/shared/l10n/` entry, "State management" section notes the one approved new dependency) needs the owner's **explicit approval for that specific task**, per the Safety policy — approval for LANG1/LANG3 above doesn't automatically cover editing `CLAUDE.md`; that's a separate ask when `docs-i18n-runbook-and-claude-md` starts.

## Known risk, not a decision (flag only)

`flutter_localizations`' built-in `MaterialLocalizations` table (the "OK"/"Cancel"/date-picker chrome Flutter itself draws) may have partial or no coverage for Lao specifically — the app's own ARB-driven strings work regardless of this, since the app controls almost all its own UI text, but it should be verified during `shared-l10n-infrastructure` rather than assumed.

## How this card is "done"

There is no `make` gate for a decision. This card is done when every LANG1–LANG8 item above has a `## Decided` entry appended below (owner, dated), the same style as `vi-translate-shared-and-restaurant-ui.md`'s VI1–VI3 entries. Until then it stays active and keeps blocking the rest of this set.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| LANG1–LANG8 each have a dated, recorded answer in this file | owner review (no `make` gate — this card has no code) |
| Downstream cards are re-checked against the recorded answers (rewritten first if an answer differs from the "Recommendation" they assumed) | manual check by whoever runs `/execute-tasks` next, before starting `shared-l10n-infrastructure` |

## Decided (owner, 2026-11-23)

Answers given in the `/execute-tasks` session of 2026-11-23. The answers match the card's own recommendations (LANG1 was a confirmation and LANG7 turned out to be moot), so the downstream cards (`shared-l10n-infrastructure`, `shared-locale-picker-widget`, `restaurant-l10n-wiring`, `customer-l10n-wiring`, `docs-i18n-runbook-and-claude-md`), which assumed those recommendations, need no rewrite for these decisions.

- **LANG1 — reverse VI1/VI2: YES.** The owner confirms, in writing, reversing "Vietnamese only, hardcoded, no new package" in favour of multi-language support. The hardcoded Vietnamese strings in `lib/restaurant/**`, `lib/customer/**`, `lib/shared/models/order.dart` (`OrderStatusLabel`) must be moved behind the translation mechanism (the web page files are a separate point, see "Web page files" below); the English strings VI2 deleted must be re-derived (from the diffs and the review reports, or re-drafted).
- **LANG2 — runtime switching (option a): YES.** A per-device language picker; the picker card stays in the plan.
- **LANG3 — mechanism and new dependencies: APPROVED `intl` + `flutter_localizations` + ARB files.** This is the owner's explicit approval under architecture invariant 5 for these two packages and no others (`flutter_localizations` ships in the Flutter SDK; `intl` is the pub.dev package it needs). `shared_preferences` is NOT approved. The approval is for the cards in this set only; any other new package still needs its own approval.
- **LANG4 — languages, locale codes, default: accepted as recommended.** `en`, `vi`, `zh` (Simplified Chinese), `lo`, `es` (generic), `fr` (generic), `ru`, `de`, `ko`, `ja`. Default and fallback locale `vi`. Picker order: Vietnamese and English first, then the rest alphabetically by native name.
- **LANG5 — who translates: the agent drafts all strings.** English and Vietnamese first; the other eight as machine-translated drafts. Wording of every language stays **"unverified"** until a native or fluent speaker confirms it; no card may claim translated wording as verified.
- **LANG6 — backend-generated text: OUT of scope for this round.** CSV headers, the two `.xlsx` reports and HTTP error bodies stay Vietnamese. If wanted later, a new planning round must first answer who picks the export language.
- **LANG7 — `vi-translate-customer-ui`: moot.** That card already ran and is archived in `docs/tasks/done/` (review `docs/reviews/execute-vi-translate-customer-ui.md`). `lib/customer/**` is therefore hardcoded Vietnamese today, exactly like the restaurant app, and `customer-l10n-wiring` must inventory the customer files fresh and re-derive the English for them too, as that card already says it does. Nothing to pause.
- **LANG8 — where the chosen language is stored: browser `localStorage` through a conditional-import shim** (the existing `chime.dart` / `chime_web.dart` / `chime_stub.dart` pattern). No persistence package.

Still open (not decisions this card can make): editing `CLAUDE.md` for the l10n work needs the owner's explicit approval for that specific task when `docs-i18n-runbook-and-claude-md` runs (approval for LANG1/LANG3 does not cover it); whether Flutter's built-in `MaterialLocalizations` covers Lao must be checked during `shared-l10n-infrastructure`.

### Web page files (`web/index.html`, `web/manifest.json`): CONFIRMED by the owner, 2026-11-23

The review of this card found that no downstream card owns these two files. Static `index.html` and `manifest.json` cannot read ARB files at runtime, so they cannot follow the picker. **Decision (owner confirmed the proposal, 2026-11-23):** they stay Vietnamese, the default locale (`lang="vi"`, app name "Đặt Món"), and the browser tab title follows the chosen language at runtime through `MaterialApp.onGenerateTitle` (Flutter overwrites `document.title` with the app title anyway), which `restaurant-l10n-wiring` and `customer-l10n-wiring` should do when they wire `MaterialApp`. The wiring cards must not touch `web/**`, and the installed-app name in the manifest stays Vietnamese-only.
