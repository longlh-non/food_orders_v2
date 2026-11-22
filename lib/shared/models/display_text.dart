/// Shared by every model that shows owner- or customer-edited text
/// (menu items, toppings).
library;

/// Text from the server is shown as-is to every customer, so make it safe to display:
/// - every kind of line break (including the Unicode line and paragraph
///   separators U+2028/U+2029) becomes a space, so a name like
///   "Burger\n$0.01" can't fake a second price line;
/// - invisible control, zero-width and text-direction characters are
///   removed, since they can hide or reorder what the customer reads.
/// The zero-width joiners U+200C/U+200D are kept: emoji and some scripts
/// need them to render correctly.
String displayText(String raw) => raw
    .replaceAll(RegExp('[\r\n\t\u0085\u2028\u2029]+'), ' ')
    .replaceAll(
      RegExp(
        '[\u0000-\u001F\u007F-\u009F\u061C\u180E\u200B\u200E\u200F'
        '\u202A-\u202E\u2060-\u2069\uFEFF]',
      ),
      '',
    )
    .trim();
