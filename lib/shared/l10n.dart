/// One import for translated text and the language switch.
///
/// Both apps import this file instead of reaching into `l10n/` or
/// `locale_controller.dart`, the same way they import `OrderRepository`.
/// [AppLocalizations] is generated from `l10n/app_*.arb` by `flutter gen-l10n`
/// (it runs on `flutter pub get`, `flutter run` and `flutter test`).
library;

export 'l10n/app_localizations.dart';
export 'locale_controller.dart';
