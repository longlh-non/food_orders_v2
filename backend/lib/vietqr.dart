// The text inside a VietQR (NAPAS, EMVCo merchant-presented) transfer QR.
// Pure functions: no I/O, no clock. The apps only draw this text as a QR.
//
// Every field is `tag(2 digits) + length(2 digits) + value`. Lengths count
// characters; everything here is ASCII, so characters equal bytes.

final _digits = RegExp(r'^[0-9]+$');
final _referenceChars = RegExp(r'^[A-Za-z0-9]+$');

/// Longest transfer content the QR carries (the VietQR limit).
const maxReferenceLength = 25;

/// CRC-16/CCITT-FALSE: polynomial 0x1021, initial 0xFFFF, no reflection, no
/// final xor. The check value of the ASCII text `123456789` is 0x29B1.
int crc16CcittFalse(List<int> bytes) {
  var crc = 0xFFFF;
  for (final byte in bytes) {
    crc ^= (byte & 0xFF) << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc;
}

/// One field. Throws [ArgumentError] when the value is too long for the
/// 2-digit length (over 99), so a long value can never write a wrong length.
String _field(String tag, String value) {
  if (value.length > 99) throw ArgumentError('QR field $tag is too long');
  return '$tag${value.length.toString().padLeft(2, '0')}$value';
}

/// The transfer content for an order id: `DH` + the last 6 digits of the id
/// (all of them when there are fewer than 6), e.g. `DH482913`. Non-digit
/// characters in the id are skipped. An id with no digit at all gets 6 digits
/// from a fixed hash of the id instead, so such orders don't all share `DH`.
String transferReference(String orderId) {
  final digits = orderId.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isNotEmpty) {
    return 'DH${digits.length <= 6 ? digits : digits.substring(digits.length - 6)}';
  }
  var hash = 0x811C9DC5; // FNV-1a, 32 bit
  for (final unit in orderId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return 'DH${(hash % 1000000).toString().padLeft(6, '0')}';
}

/// Builds the payload. [bin] is the 6-digit bank id, [account] 1-19 digits,
/// [amount] whole VND above 0, [reference] ASCII letters and digits, at most
/// [maxReferenceLength]. Throws [ArgumentError] otherwise.
String vietQrPayload({
  required String bin,
  required String account,
  required int amount,
  required String reference,
}) {
  if (bin.length != 6 || !_digits.hasMatch(bin)) {
    throw ArgumentError('bin must be 6 digits');
  }
  if (account.isEmpty || account.length > 19 || !_digits.hasMatch(account)) {
    throw ArgumentError('account must be 1-19 digits');
  }
  if (amount <= 0) throw ArgumentError('amount must be above 0');
  if (reference.isEmpty ||
      reference.length > maxReferenceLength ||
      !_referenceChars.hasMatch(reference)) {
    throw ArgumentError('reference must be 1-25 ASCII letters or digits');
  }
  final consumer = _field('00', bin) + _field('01', account);
  final merchant =
      _field('00', 'A000000727') + // NAPAS
      _field('01', consumer) +
      _field('02', 'QRIBFTTA'); // transfer to an account
  final body =
      _field('00', '01') + // format version
      _field('01', '12') + // dynamic: has an amount
      _field('38', merchant) +
      _field('53', '704') + // VND
      _field('54', amount.toString()) +
      _field('58', 'VN') +
      _field('62', _field('08', reference));
  // The CRC covers everything before it, including the text `6304`.
  final withCrcTag = '${body}6304';
  final crc = crc16CcittFalse(withCrcTag.codeUnits)
      .toRadixString(16)
      .toUpperCase()
      .padLeft(4, '0');
  return '$withCrcTag$crc';
}
