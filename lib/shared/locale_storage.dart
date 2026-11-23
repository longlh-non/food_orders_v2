/// Remembers the language the user picked, in this browser.
///
/// Conditional export, the same shape as `chime.dart`: `flutter test` (Dart VM)
/// gets the stub, which stores nothing, so `package:web` is never compiled
/// there; web builds get the real `localStorage` version.
///
/// Call [readStoredLocaleCode] at start-up and [writeStoredLocaleCode] when the
/// user picks a language. Both are safe to call on any platform.
library;

export 'locale_storage_stub.dart'
    if (dart.library.js_interop) 'locale_storage_web.dart';
