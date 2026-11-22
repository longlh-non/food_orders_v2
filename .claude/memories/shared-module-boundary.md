# When code moves into lib/shared/

Move code from `lib/customer/` or `lib/restaurant/` into `lib/shared/` only if **all** of these hold:

1. Both apps need the same behaviour or resource **today** (not "probably later").
2. It contains no product rule that belongs to only one side (e.g. the customer's "my orders" tracking stays in `customer/state/`).
3. It doesn't make `lib/shared/` import either app or `lib/dev/`.

Where it goes inside `shared/`: data shapes → `models/`; HTTP/SSE and the repository cache → `api/`; static data → `data/`; theme → `theme.dart`; small platform helpers with web/VM variants → a top-level file with conditional imports (like `chime.dart`).

Single-consumer code stays with its app. Don't create vague buckets like `shared/utils/` or `shared/common/`. A new top-level folder under `lib/` needs an update to the invariants in `CLAUDE.md` and to `make boundaries`.
