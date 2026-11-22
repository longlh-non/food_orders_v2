import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/money.dart';

void main() {
  for (final (amount, expected) in [
    (0, '0 VNĐ'),
    (500, '500 VNĐ'),
    (4000, '4.000 VNĐ'),
    (25000, '25.000 VNĐ'),
    (125000, '125.000 VNĐ'),
    (1250000, '1.250.000 VNĐ'),
    (25000.0, '25.000 VNĐ'),
    (9999.6, '10.000 VNĐ'),
    (9999.4, '9.999 VNĐ'),
    (-8000, '-8.000 VNĐ'),
  ]) {
    test('formatVnd($amount) is "$expected"', () {
      expect(formatVnd(amount), expected);
    });
  }

  test('never shows a dollar sign or decimals', () {
    final text = formatVnd(23000.0);
    expect(text, isNot(contains(r'$')));
    expect(text, isNot(contains(',')));
    expect(text, '23.000 VNĐ');
  });

  test('does not crash on a non-finite amount', () {
    expect(formatVnd(double.infinity), '— VNĐ');
    expect(formatVnd(double.nan), '— VNĐ');
  });
}
