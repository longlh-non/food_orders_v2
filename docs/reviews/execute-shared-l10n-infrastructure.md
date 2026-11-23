---
task: shared-l10n-infrastructure
status: passed
p0: 0
p1: 0
---

# Review: shared-l10n-infrastructure

## Gates

| Command | Exit | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | 613 tests (23 new) |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | |
| `make analyze` / `make check` | 2 | 23 `deprecated_member_use` infos: 22 pre-existing baseline (`material_ui` SDK issue) + 1 for the `flutter/material.dart` import in `test/shared/app_localizations_smoke_test.dart` (same class as the baseline; unavoidable for a `MaterialApp` test). `make check` stops at analyze; the other gates were run separately. |
| `flutter build web -t lib/restaurant/main.dart` | 0 | implementer run |

## Findings (code-reviewer)

- P1 (1): `make analyze` showed 2 extra infos from generated `app_localizations.dart` lines 98-99. **Fixed**: `analysis_options.yaml` now excludes `lib/shared/l10n/app_localizations*.dart` (no longer reported). The remaining exit 2 is the known baseline.
- P2 (deferred): (1) no test pumps `CustomerApp`/`RestaurantApp` or renders every key per locale; (2) ARB placeholder check is one-directional (extra/misspelled placeholders not caught); (4) app titles still hardcoded, belongs to wiring cards (`onGenerateTitle`); (5) `lib/dev/demo.dart` has no delegates or `LocaleController.init`, matters once pages use `AppLocalizations.of(context)`: raise in the wiring cards.
- P2 fixed: README no longer claims later `vi` strings are owner-accepted.

Security review: `docs/reviews/security-shared-l10n-infrastructure.md` — passed, P0 0, P1 0.

## Unverified

- Wording: `en` partly redrafted; `zh lo es fr ru de ko ja` are machine drafts; Lao and Russian plurals need a fluent reader.
- localStorage persistence and the language switch in a real browser.
- CI Flutter 3.47.7 regenerating the checked-in `app_localizations*.dart` identically (format-check could differ).
- `intl` licence not checked.

## Verdict

**Passed**, P0: 0, P1: 0.
