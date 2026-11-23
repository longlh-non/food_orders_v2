import 'package:web/web.dart' as web;

/// The `localStorage` key. One key per origin, so the customer site and the
/// restaurant site each remember their own choice.
const _key = 'food_orders_locale';

/// Returns the language code saved by [writeStoredLocaleCode] (for example
/// `vi`), or `null` if nothing was saved or the browser refuses access
/// (private mode and blocked storage can throw).
String? readStoredLocaleCode() {
  try {
    return web.window.localStorage.getItem(_key);
  } on Object {
    return null;
  }
}

/// Saves the language code in `localStorage`. A browser that refuses the write
/// is ignored: the choice then lasts only until the page is reloaded.
void writeStoredLocaleCode(String languageCode) {
  try {
    web.window.localStorage.setItem(_key, languageCode);
  } on Object {
    // Storage blocked or full: keep working without persistence.
  }
}
