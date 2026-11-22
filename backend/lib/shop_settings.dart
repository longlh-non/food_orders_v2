// Control characters (newline, tab, NUL, DEL, the C1 range and the Unicode
// line and paragraph separators U+2028 and U+2029) are never allowed, so a
// pasted newline can't break a report or a log line.
final _controlChars = RegExp(r'[\x00-\x1F\x7F-\x9F\u2028\u2029]');
final _taxCode = RegExp(r'^[0-9-]+$');
final _digits = RegExp(r'^[0-9]+$');

/// The shop's details and bank account, read once from the environment at
/// startup (like `STAFF_ID`). They are the owner's real data, so they never
/// live in the repo.
///
/// Every value is trimmed; an empty value counts as unset. A missing or
/// invalid value turns off only the feature that needs it ([reportEnabled]
/// for the `SHOP_*` values, [transferEnabled] for the `BANK_*` values);
/// nothing throws. A change needs a backend restart.
///
/// Text lengths count UTF-16 units, like the order rules. [describe] prints
/// variable **names** only, never values, not even their lengths.
class ShopSettings {
  /// [env] is `Platform.environment` in the server, a plain map in tests.
  ShopSettings(Map<String, String?> env)
    : shopName = _text(env['SHOP_NAME'], 200),
      taxCode = _matching(env['SHOP_TAX_CODE'], 1, 20, _taxCode),
      address = _text(env['SHOP_ADDRESS'], 200),
      location = _text(env['SHOP_LOCATION'], 200),
      representative = _text(env['SHOP_REPRESENTATIVE'], 100),
      bankBin = _matching(env['BANK_BIN'], 6, 6, _digits),
      bankAccount = _matching(env['BANK_ACCOUNT'], 1, 19, _digits),
      bankAccountName = _text(env['BANK_ACCOUNT_NAME'], 100),
      bankName = _text(env['BANK_NAME'], 100);

  /// Each field is the valid trimmed value, or null when unset or invalid.
  final String? shopName;
  final String? taxCode;
  final String? address;
  final String? location;
  final String? representative;
  final String? bankBin;
  final String? bankAccount;
  final String? bankAccountName;
  final String? bankName;

  /// All five `SHOP_*` values are valid.
  bool get reportEnabled => _missingShop.isEmpty;

  /// All four `BANK_*` values are valid.
  bool get transferEnabled => _missingBank.isEmpty;

  List<String> get _missingShop => [
    if (shopName == null) 'SHOP_NAME',
    if (taxCode == null) 'SHOP_TAX_CODE',
    if (address == null) 'SHOP_ADDRESS',
    if (location == null) 'SHOP_LOCATION',
    if (representative == null) 'SHOP_REPRESENTATIVE',
  ];

  List<String> get _missingBank => [
    if (bankBin == null) 'BANK_BIN',
    if (bankAccount == null) 'BANK_ACCOUNT',
    if (bankAccountName == null) 'BANK_ACCOUNT_NAME',
    if (bankName == null) 'BANK_NAME',
  ];

  /// Two lines for the startup printout. Names only, never values.
  String describe() =>
      'shop details for reports: ${_state(_missingShop)}\n'
      'bank transfer: ${_state(_missingBank)}';

  static String _state(List<String> missing) => missing.isEmpty
      ? 'enabled'
      : 'disabled (missing or invalid: ${missing.join(', ')})';

  static String? _text(String? raw, int max) => _matching(raw, 1, max, null);

  static String? _matching(String? raw, int min, int max, RegExp? pattern) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.length < min || value.length > max) return null;
    if (_controlChars.hasMatch(value)) return null;
    if (pattern != null && !pattern.hasMatch(value)) return null;
    return value;
  }
}
