---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [qr-static-api-contract]
securityReview: required
---

# Customer: download the QR image file (web only, no new dependency)

Planned 2026-11-26, rewritten the same day after the owner's design change: the QR is a third-party **image** in the server's images folder, so the download saves **that image file itself**, not a re-rendered QR. The slug is historical (it was "save the QR as a PNG"); the file may be a jpg, png or webp. Decision QS4 in `qr-static-api-contract`. Security review is required (it fetches a file and builds a Blob and a download link in the browser). Independent of the backend, so it can run early.

## Sources

`lib/shared/chime.dart`, `chime_stub.dart`, `chime_web.dart` and `lib/shared/locale_storage*.dart` (the conditional-export pattern), `lib/shared/api/order_api_client.dart` (`imageUrlFor`), `pubspec.yaml` (`web ^1.1.0` is already there; `qr_flutter` is **not** used by this option).

## Goal

- `lib/customer/download/` (customer-only, so not in `shared/`, invariant 2): `image_download.dart` exports `image_download_stub.dart` `if (dart.library.js_interop)` `image_download_web.dart`. One function, `Future<bool> saveImageFile(String imageUrl, String fileName)`; plus `bool get canSaveImage` (false in the stub). A test seam: the page takes the function by constructor (default = this one), and the web file splits "fetch the bytes" from "hand them to the browser" so each can be faked.
- Web: fetch `imageUrl` (the value of `OrderApiClient.imageUrlFor(name)`, which is a **same-origin** `/api/images/<file>` path; refuse any URL that is not same-origin, so the function can never fetch another site), read the body as bytes, make a `Blob` with the response's image MIME type (fall back to the type from the file extension; refuse a non-`image/*` type), then an `<a download>` element clicked once and removed, the object URL revoked afterwards. Returns false on any failure (network, non-200, wrong type, empty body); never throws.
- The saved **file name is the picture name itself** (`fileName`, taken from the server's `staticQrImage`, already limited by the picture-name rule). No order data, no customer text.
- The bytes are saved as served: no decoding, no re-drawing, no resizing. `QrPainter` and `qr_flutter` are not used.
- Non-web (VM, tests): the stub does nothing and returns false; the button that will use it is hidden when `canSaveImage` is false.

## Non-goals

The button and page (the payment-page card). Sharing sheets, printing, any package, drawing a QR.

## Tests written with the change

- stub: `canSaveImage` false, `saveImageFile` returns false.
- the pure parts of the web logic (kept in a file the VM can run, e.g. a helper `isSameOriginImagePath(url)` and `mimeForFileName(name)`): same-origin `/api/images/xoi.png` accepted; `https://other.example/x.png`, `//other.example/x.png`, `javascript:` and `data:` URLs refused; `.png`, `.jpg`, `.jpeg`, `.webp` map to the right MIME and anything else is refused.
- with a fake fetch and a fake save: success returns true and hands the exact bytes and the picture name to the save; non-200, empty body, non-image type and a thrown error all return false without throwing.
- `make boundaries`: nothing in `shared/` imports it.
- The web implementation is not run by `flutter test` (VM). Compile check: `flutter build web -t lib/customer/main.dart` (gate-like, exit code recorded in the review).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Stub and pure-helper behaviour | `make test` (gate) |
| Gates, boundaries | `make analyze`, `make format-check`, `make boundaries` (gates) |
| Web build compiles | `flutter build web` exit 0 (recorded) |
| No new dependency; same-origin only; file name is the picture name; URL revoked | `security-reviewer`, `code-reviewer` (reviews) |
| The file really downloads in Chrome and the saved image scans in the owner's payment app; iOS Safari behaviour | owner acceptance, "unverified" until done |
