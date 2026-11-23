---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [backend-orders-month-export-xlsx]
securityReview: required
---

# Restaurant: the export dialog offers the two Excel reports (and the CSV)

Planned 2026-11-19, updated the same day. **No open decisions block this card.** Security review because it downloads financial data with the staff ID and password.

## Owner request

Two report formats for the month export: the summary (income per day) and the detailed (every order per day). **RPT5, decided (owner, 2026-11-19, "OK"):** the CSV stays, unchanged.

## Sources

`lib/restaurant/pages/export_month_dialog.dart`, `lib/restaurant/api/export_client.dart` (`fetchMonth`, `ExportFailure`), `lib/restaurant/download/save_file*.dart`, `lib/restaurant/state/staff_credentials.dart`, `test/` for the export dialog and client tests, the route card `backend-orders-month-export-xlsx` (parameters, file names, the extra 503).

## Design (plain words)

- A second dropdown in the dialog, **"Loại báo cáo"**, with three choices (Vietnamese, because they name Vietnamese bookkeeping documents; the rest of the dialog keeps its language for the translation cards):
  1. **Báo cáo tổng hợp theo ngày** (Excel) - default.
  2. **Chi tiết từng đơn trong tháng** (Excel).
  3. **Danh sách dòng món** (CSV, the existing export).
  Default is the summary, the report the owner needs each month; the CSV is the unusual one.
- `ExportClient.fetchMonth(month, {report, credentials})` adds `report` as an enum (`lines`, `summary`, `detail`) and sends `&report=summary|detail` only for the two reports; `lines` sends nothing extra, exactly like today. The staff ID and password stay in headers only.
- Saved file names: `bao-cao-tong-hop-YYYY-MM.xlsx`, `chi-tiet-YYYY-MM.xlsx`, `orders-YYYY-MM.csv`; MIME types `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` for the first two, `text/csv;charset=utf-8` for the CSV.
- New error: **503** (shop details are not set on the server) -> a new `ExportFailure.notConfigured` with the fixed text "Chưa cài đặt thông tin quán trên máy chủ". The other failures and their texts are unchanged.
- The dialog's busy state, remembered credentials, wrong-credentials clearing and layout rules are unchanged.

## Goal

The dropdown, the client parameter, the three file names and MIME types, the 503 handling. Fits at 360 px and text scales up to 2.0.

## Non-goals

Backend changes, previewing a report in the app, choosing a date range, translating the rest of the dialog.

## Tests written with the change

- Client (`MockClient`): each report sends the exact path and query (`lines`: `month` only; `summary`: `month` and `report=summary`; `detail`: `report=detail`) with the staff headers; 503 -> `notConfigured`; the other mappings as before; staff values never in an exception message.
- Dialog (fake client and save function): default choice is the summary; each choice downloads once with the right report, file name and MIME type, then closes; 503 shows the fixed text and the dialog stays open and usable; the dropdown is disabled while busy; the existing export dialog tests still pass; no overflow at 360 px for text scales 1.3 and 2.0.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Format, analysis, boundaries | `make format-check`, `make analyze`, `make boundaries` (gates) |
| Credentials only in memory and headers; no new dependency | `security-reviewer`, `code-reviewer` (reviews) |
| `make check` green | `make check` exit 0 (gate) |
| On `http://restaurant.local` and on the staff phone/tablet: pick a month and each report; the files download and open in Excel looking like the samples (iOS Safari may preview first) | owner acceptance - "unverified" until done |
