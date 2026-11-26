---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [qr-static-api-contract]
securityReview: required
---

# Customer: save the QR as a PNG file (web only, no new dependency)

Planned 2026-11-26. Decision QS4 in `qr-static-api-contract`. Security review is required (it builds a Blob and a download link in the browser). Independent of the backend, so it can run early.

## Sources

`lib/shared/chime.dart`, `chime_stub.dart`, `chime_web.dart` and `lib/shared/locale_storage*.dart` (the conditional-export pattern), `pubspec.yaml` (`qr_flutter ^4.1.0` and `web ^1.1.0` are already there), how `payment_qr_page.dart` draws the QR (`QrImageView`).

## Goal

- `lib/customer/download/` (customer-only, so not in `shared/`, invariant 2): `png_download.dart` exports `png_download_stub.dart` `if (dart.library.js_interop)` `png_download_web.dart`. One function, `Future<bool> savePng(Uint8List bytes, String fileName)`; plus `bool get canSavePng` (false in the stub).
- Web: Blob with MIME `image/png`, an `<a download>` element clicked once and removed, the object URL revoked afterwards. The file name is a **fixed** string such as `qr-chuyen-khoan.png` (no order data, no customer text).
- A small helper turns a payload string into PNG bytes: `QrPainter(data: payload, version: QrVersions.auto, ...)` and `toImageData(size)` with a **white background and a quiet-zone margin** so banking apps can scan the saved file. 1024 px square. Returns null on failure.
- Non-web (VM, tests): the stub does nothing and returns false; the button that will use it is hidden when `canSavePng` is false.

## Non-goals

The button and page (next card). Sharing sheets, printing, any package.

## Tests written with the change

- helper: PNG bytes start with the PNG signature `89 50 4E 47`, size 1024 square, corners are white; decodes to non-empty for a real static payload string. An empty payload returns null rather than throwing.
- stub: `canSavePng` false, `savePng` returns false.
- `make boundaries`: nothing in `shared/` imports it.
- The web implementation is not run by `flutter test` (VM). Compile check: `flutter build web -t lib/customer/main.dart` (gate-like, exit code recorded in the review).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Helper and stub behaviour | `make test` (gate) |
| Gates, boundaries | `make analyze`, `make format-check`, `make boundaries` (gates) |
| Web build compiles | `flutter build web` exit 0 (recorded) |
| No new dependency; fixed file name; URL revoked | `security-reviewer`, `code-reviewer` (reviews) |
| The file really downloads in Chrome and a banking app scans the saved PNG; iOS Safari behaviour | owner acceptance, "unverified" until done |
