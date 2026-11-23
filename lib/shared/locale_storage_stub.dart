/// Non-web fallback: nothing is remembered. Keeps the public API callable from
/// any platform while avoiding `package:web` on the Dart VM used by
/// `flutter test`.
String? readStoredLocaleCode() => null;

/// Non-web fallback: does nothing.
void writeStoredLocaleCode(String languageCode) {}
