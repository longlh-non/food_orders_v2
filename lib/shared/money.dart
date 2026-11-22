/// Prices in this app are Vietnamese đồng (VND): whole numbers, no cents.
///
/// Formats [amount] the Vietnamese way, with `.` between thousands:
/// `4000` -> `4.000 VNĐ`, `1250000` -> `1.250.000 VNĐ`. Rounds to the
/// nearest đồng. Use this everywhere a price is shown, in both apps.
String formatVnd(num amount) {
  // Prices are validated as finite numbers, so this is only a safety net
  // against a crash in the UI.
  if (!amount.isFinite) return '— VNĐ';
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}$grouped VNĐ';
}
