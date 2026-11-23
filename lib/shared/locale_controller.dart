import 'package:flutter/widgets.dart';

import 'locale_storage.dart';

/// Reads the saved language code; returns `null` when none is saved.
typedef ReadLocaleCode = String? Function();

/// Saves the language code after the user picks one.
typedef WriteLocaleCode = void Function(String languageCode);

/// Holds which language the app shows right now.
///
/// A `ChangeNotifier` singleton like `OrderRepository`: the apps wrap their
/// `MaterialApp` in a `ListenableBuilder` on [instance], so [setLocale]
/// rebuilds the whole app in the new language. The choice is saved in the
/// browser (see `locale_storage.dart`) and restored by [init].
class LocaleController extends ChangeNotifier {
  /// Creates a controller. Tests pass [readCode] / [writeCode] to avoid the
  /// real browser storage; the app uses the defaults.
  LocaleController({ReadLocaleCode? readCode, WriteLocaleCode? writeCode})
    : _readCode = readCode ?? readStoredLocaleCode,
      _writeCode = writeCode ?? writeStoredLocaleCode;

  /// The one controller both apps share.
  static final LocaleController instance = LocaleController();

  /// Shown when nothing is saved or the saved value is unknown.
  static const Locale defaultLocale = Locale('vi');

  /// Every language the apps ship, in the order a picker lists them:
  /// Vietnamese and English first, then the rest alphabetically by native
  /// name (code-point order: Deutsch, Español, Français, Русский, ລາວ, 日本語,
  /// 中文, 한국어). Keep in step with the ARB files in `lib/shared/l10n`.
  static const List<Locale> supported = [
    Locale('vi'),
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
    Locale('lo'),
    Locale('ja'),
    Locale('zh'),
    Locale('ko'),
  ];

  final ReadLocaleCode _readCode;
  final WriteLocaleCode _writeCode;

  Locale _locale = defaultLocale;

  /// The language to show now. Pass it to `MaterialApp.locale`.
  Locale get locale => _locale;

  /// Restores the saved choice, if there is one and it is a supported
  /// language. Call once from each `main()` before `runApp`. Notifies only if
  /// the language changes.
  void init() {
    final saved = _match(_readCode());
    if (saved != null && saved != _locale) {
      _locale = saved;
      notifyListeners();
    }
  }

  /// Switches the language, saves the choice and notifies listeners.
  ///
  /// The save is attempted on every call, also when [locale] is already the
  /// current one. A language that is not in [supported] is ignored, so a bad
  /// call can never leave the app without translations.
  void setLocale(Locale locale) {
    final match = _match(locale.languageCode);
    if (match == null) return;
    _writeCode(match.languageCode);
    if (match == _locale) return;
    _locale = match;
    notifyListeners();
  }

  /// Finds the supported locale with this language code, or `null`.
  Locale? _match(String? languageCode) {
    for (final locale in supported) {
      if (locale.languageCode == languageCode) return locale;
    }
    return null;
  }
}
