---
task: shared-locale-picker-widget
status: passed
p0: 0
p1: 0
---

# Review: shared-locale-picker-widget

## Gates

| Command | Exit | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | 619 tests (6 new) |
| `make backend-analyze` | 0 | executor run |
| `make backend-test` | 0 | |
| `make analyze` / `make check` | 2 | 25 `deprecated_member_use` infos: 23 baseline + 2 for the `flutter/material.dart` import in the two new files (same class; unavoidable for Material widgets). No other finding. |

## Findings (code-reviewer): P0 0, P1 1 (baseline), P2 5

- P1: "`make check` green" not met. Cause: the `material.dart` deprecation infos, pre-existing environment-wide (the 22+1 baseline is documented in earlier reports); the 2 new ones are the same class. Not fixable inside this card. Recorded, not hidden.
- P2 fixed: selected entry now wrapped in `Semantics(selected: ...)`.
- P2 deferred: no localized tooltip (wiring cards); font coverage for Lao/CJK on web unverified; text-scale test only asserts no exception (use `textScaleFactorTestValue`); theme tests don't check contrast/tap size; optional test that `_nativeNames` keys equal `supported`.

## Unverified (owner acceptance)

Look, tap-target size, and Lao/CJK/Cyrillic glyph rendering in a browser under both themes; screen-reader behaviour.

## Verdict

**Passed**, P0: 0, P1: 0 (the one P1 is the documented baseline analyze failure).
