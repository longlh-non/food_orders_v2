/// Plain-letter forms of the Vietnamese letters, used for menu item ids and
/// for the duplicate-name check of `POST /menu`. Hand-written (no package).
/// Each entry is "plain letter" -> every lower-case form that maps to it.
const _plainLetters = {
  'a': 'àáảãạăằắẳẵặâầấẩẫậ',
  'e': 'èéẻẽẹêềếểễệ',
  'i': 'ìíỉĩị',
  'o': 'òóỏõọôồốổỗộơờớởỡợ',
  'u': 'ùúủũụưừứửữự',
  'y': 'ỳýỷỹỵ',
  'd': 'đ',
};

/// Lower-case letter -> plain letter, built once from [_plainLetters].
final Map<String, String> _plainOf = {
  for (final entry in _plainLetters.entries)
    for (final rune in entry.value.runes) String.fromCharCode(rune): entry.key,
};

/// [text] in lower case with Vietnamese letters turned into plain ones
/// (`Xôi Thịt` -> `xoi thit`, `đ` -> `d`). Combining tone marks (the
/// "decomposed" way of typing a letter) are removed too. Everything else is
/// kept as it is, so two names are the "same" when their folded forms match.
String foldMenuText(String text) {
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    // U+0300 to U+036F: combining accents.
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    final char = String.fromCharCode(rune);
    out.write(_plainOf[char] ?? char);
  }
  return out.toString();
}

/// The longest id [menuSlug] makes (a `-2` style suffix may follow).
const maxMenuSlugLength = 48;

/// The id for a new menu item made from its [name]: folded with
/// [foldMenuText], every run of characters other than `a-z` and `0-9` turned
/// into one `-`, leading and trailing `-` removed, cut to
/// [maxMenuSlugLength] characters (and trimmed again). A name with nothing
/// left (Lao, emoji, only symbols) gives `item`. The result always matches
/// `^[a-z0-9][a-z0-9-]*$`.
String menuSlug(String name) {
  final dashed = foldMenuText(name)
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final cut = dashed.length > maxMenuSlugLength
      ? dashed.substring(0, maxMenuSlugLength).replaceAll(RegExp(r'-+$'), '')
      : dashed;
  return cut.isEmpty ? 'item' : cut;
}
