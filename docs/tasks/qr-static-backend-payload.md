---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: [qr-static-api-contract]
---

# Backend: the VietQR text without an amount (pure function)

Planned 2026-11-26. Decisions QS3 (no reference in the QR: owner decided 2026-11-26) in `qr-static-api-contract`; the caller passes no `reference`, the parameter only stays so tag 62 is tested.

## Sources

`backend/lib/vietqr.dart` (`vietQrPayload`, `_field`, `crc16CcittFalse`), `backend/test/vietqr_test.dart`.

## Goal

Add `vietQrStaticPayload({required String bin, required String account, String? reference})` next to `vietQrPayload`, reusing the same private helpers. Fields in order: `00`=`01`; `01`=**`11`** (static: no amount); `38` merchant account exactly as today; `53`=`704`; **no tag 54**; `58`=`VN`; tag `62` only when `reference` is given (default: none, QS3); `63` CRC as today. Same `bin` / `account` / `reference` checks and `ArgumentError`s. Do not change `vietQrPayload`.

## Non-goals

Routes, schema, any Flutter code.

## Tests written with the change (`vietqr_test.dart`)

- known-output test: fixed bin and account give one exact string (build it by hand from the field rules, not by calling the function); it contains `010211`, no `54` field, and ends with the CRC of everything before it.
- the CRC check: recomputing `crc16CcittFalse` over the text minus its last 4 characters equals those 4 characters.
- with a reference: tag 62 is present and equal to the one in `vietQrPayload` for the same input; without: absent.
- invalid bin / account / reference throw `ArgumentError`.
- `vietQrPayload` outputs are unchanged (existing tests stay green).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make backend-test` (gate) |
| `make backend-analyze`, `make format-check` | gates, exit 0 |
| `vietQrPayload` untouched | `code-reviewer` (review) |
| A real banking app scans the code and asks for an amount | owner acceptance, "unverified" until done (agents can't scan) |
