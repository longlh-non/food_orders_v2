---
task: restaurant-export-report-choice
status: passed
p0: 0
p1: 0
---

# Security review: restaurant-export-report-choice

## Scope

`lib/restaurant/api/export_client.dart`, `lib/restaurant/pages/export_month_dialog.dart`, `test/export_month_test.dart` (what this card adds). Read-only review.

## Findings: P0 0, P1 0, P2 0

Checked and clean:
- Staff ID/password go only through `credentials.headers`; the URL carries only `month` and `report`; a test asserts neither value appears in `url.toString()`. `ExportException.message` holds fixed text plus status code only; the dialog's generic catch shows a fixed string.
- `report` comes from the closed `ExportReport` enum; `month` is checked against `^\d{4}-(0[1-9]|1[0-2])$` and percent-encoded; the dropdown offers only recent months.
- Download file name and MIME type come from the client-side enum, not from response headers, so the server can't choose them. The Blob isn't navigated to or rendered and is revoked after 10 s.
- All error texts are fixed strings; 503 maps to `notConfigured` and does not echo the body (tested with an arbitrary body). 401 still clears stored credentials.
- Whole-response buffering is bounded by the 10,000-order cap and the trusted backend.

## Needs real-environment confirmation (not findings)

Excel opening the `.xlsx` files; backend route behaviour (already covered by `security-backend-orders-month-export-xlsx.md`: staff gate runs before the 503 settings check).

## Verdict

**Passed**, P0: 0, P1: 0.
