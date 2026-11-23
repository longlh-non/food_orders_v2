---
task: restaurant-export-report-choice
status: passed
p0: 0
p1: 0
---

# Review: restaurant-export-report-choice

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | 550 tests |
| `make backend-analyze` | 0 | (executor run) |
| `make backend-test` | 0 | (executor run) |
| `make analyze` / `make check` | 2 | 19 pre-existing `deprecated_member_use` infos (`material_ui` SDK issue); no new finding in this card's files |

## Changed paths

`lib/restaurant/api/export_client.dart` (`ExportReport` enum, `report` query, `ExportFailure.notConfigured` on 503), `lib/restaurant/pages/export_month_dialog.dart` ("Loại báo cáo" dropdown, default summary, file names/MIME per report, fixed 503 text), `test/export_month_test.dart`.

## Findings (code-reviewer): P0 0, P1 0, P2 3 — deferred

1. `test/export_month_test.dart:596-618`: the 360 px overflow test never opens the report dropdown at text scale 2.0.
2. `test/export_month_test.dart:378-406`: the 503 test doesn't assert remembered credentials survive a 503.
3. `export_client.dart:25,70`: class doc still says "CSV bytes"; one doc line over 80 chars.

Security review: `docs/reviews/security-restaurant-export-report-choice.md` — passed, P0 0, P1 0.

## Unverified (owner acceptance)

Downloading each report on `restaurant.local` / the staff phone and opening it in Excel.

## Verdict

**Passed**, P0: 0, P1: 0.
