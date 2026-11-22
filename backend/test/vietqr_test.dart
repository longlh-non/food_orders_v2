import 'dart:convert';

import 'package:food_orders_backend/vietqr.dart';
import 'package:test/test.dart';

/// Test-local tag/length/value reader. Throws [FormatException] when a length
/// field doesn't fit, so a writer length bug can't pass silently.
List<MapEntry<String, String>> readTlv(String text) {
  final fields = <MapEntry<String, String>>[];
  var i = 0;
  while (i < text.length) {
    if (i + 4 > text.length) throw const FormatException('short header');
    final tag = text.substring(i, i + 2);
    final length = int.tryParse(text.substring(i + 2, i + 4));
    if (length == null) throw const FormatException('bad length');
    final end = i + 4 + length;
    if (end > text.length) throw const FormatException('value too long');
    fields.add(MapEntry(tag, text.substring(i + 4, end)));
    i = end;
  }
  return fields;
}

Map<String, String> asMap(List<MapEntry<String, String>> f) => {
  for (final e in f) e.key: e.value,
};

// Obviously fake bank details.
String payload({
  String bin = '000000',
  String account = '1234567890',
  int amount = 74000,
  String reference = 'DH482913',
}) => vietQrPayload(
  bin: bin,
  account: account,
  amount: amount,
  reference: reference,
);

void main() {
  group('crc16CcittFalse', () {
    test('standard check value of "123456789" is 29B1', () {
      expect(crc16CcittFalse(ascii.encode('123456789')), 0x29B1);
    });
    test('empty input is the initial value 0xFFFF', () {
      expect(crc16CcittFalse(const []), 0xFFFF);
    });
  });

  group('vietQrPayload', () {
    test('ends with the CRC of everything before it, upper-case hex', () {
      final p = payload();
      final head = p.substring(0, p.length - 4);
      expect(head.endsWith('6304'), isTrue);
      final crc = crc16CcittFalse(ascii.encode(head));
      expect(
        p.substring(p.length - 4),
        crc.toRadixString(16).toUpperCase().padLeft(4, '0'),
      );
      expect(p.substring(p.length - 4), matches(RegExp(r'^[0-9A-F]{4}$')));
    });

    test('fixed expected text for fake data (pins the exact layout)', () {
      final head =
          '000201010212'
          '3854' // merchant info, 54 chars
          '0010A000000727'
          '0124'
          '0006000000'
          '01101234567890'
          '0208QRIBFTTA'
          '5303704'
          '540574000'
          '5802VN'
          '62120808DH482913'
          '6304';
      // The CRC was computed with a separate tool (Python), not with
      // crc16CcittFalse, so the writer can't agree with itself by mistake.
      expect(payload(), '${head}2B85');
    });

    test('tags are present in order with the right nested values', () {
      final fields = readTlv(payload());
      expect(fields.map((e) => e.key), [
        '00',
        '01',
        '38',
        '53',
        '54',
        '58',
        '62',
        '63',
      ]);
      final m = asMap(fields);
      expect(m['00'], '01');
      expect(m['01'], '12');
      expect(m['53'], '704');
      expect(m['54'], '74000');
      expect(m['58'], 'VN');
      expect(m['63'], hasLength(4));

      final merchant = readTlv(m['38']!);
      expect(merchant.map((e) => e.key), ['00', '01', '02']);
      final mm = asMap(merchant);
      expect(mm['00'], 'A000000727');
      expect(mm['02'], 'QRIBFTTA');
      final consumer = readTlv(mm['01']!);
      expect(consumer.map((e) => e.key), ['00', '01']);
      expect(asMap(consumer), {'00': '000000', '01': '1234567890'});

      final extra = readTlv(m['62']!);
      expect(extra.map((e) => e.key), ['08']);
      expect(extra.single.value, 'DH482913');
    });

    test(
      'a 19-digit account and a 25-character reference keep lengths right',
      () {
        final p = payload(
          account: '1' * 19,
          reference: 'A' * 25,
          amount: 5500000000,
        );
        final m = asMap(readTlv(p));
        expect(m['54'], '5500000000');
        final consumer = readTlv(asMap(readTlv(m['38']!))['01']!);
        expect(asMap(consumer)['01'], '1' * 19);
        expect(readTlv(m['62']!).single.value, 'A' * 25);
      },
    );

    test('the amount has no separator or decimals', () {
      expect(asMap(readTlv(payload(amount: 1)))['54'], '1');
      expect(asMap(readTlv(payload(amount: 1000000)))['54'], '1000000');
    });

    test('the test reader rejects lengths that do not add up', () {
      final p = payload();
      // Claim one more character than the value has.
      final broken = p.replaceFirst('5303704', '5304704');
      expect(() => readTlv(broken), throwsFormatException);
      expect(() => readTlv('00'), throwsFormatException);
      expect(() => readTlv('00xx01'), throwsFormatException);
      expect(() => readTlv('0005ab'), throwsFormatException);
    });

    test('bad input is refused', () {
      expect(() => payload(bin: '00000'), throwsArgumentError);
      expect(() => payload(bin: '00000a'), throwsArgumentError);
      expect(() => payload(account: ''), throwsArgumentError);
      expect(() => payload(account: '1' * 20), throwsArgumentError);
      expect(() => payload(account: '12-34'), throwsArgumentError);
      expect(() => payload(amount: 0), throwsArgumentError);
      expect(() => payload(amount: -5), throwsArgumentError);
      expect(() => payload(reference: ''), throwsArgumentError);
      expect(() => payload(reference: 'A' * 26), throwsArgumentError);
      expect(() => payload(reference: 'DH 12'), throwsArgumentError);
      expect(() => payload(reference: 'DHé12'), throwsArgumentError);
    });
  });

  group('transferReference', () {
    test('DH + the last 6 digits', () {
      expect(transferReference('1763550482913'), 'DH482913');
    });
    test('fewer than 6 digits uses all of them', () {
      expect(transferReference('42'), 'DH42');
      expect(transferReference('123456'), 'DH123456');
    });
    test('non-digit characters are skipped', () {
      expect(transferReference('ab12-34cd56ef78'), 'DH345678');
    });
    test('an id with no digit gets 6 stable digits', () {
      final a = transferReference('no-digits');
      expect(a, matches(RegExp(r'^DH[0-9]{6}$')));
      expect(transferReference('no-digits'), a);
      // Pinned: lib/restaurant/pages/orders_page.dart has a copy of this
      // function and pins the same value; change both together.
      expect(transferReference('abc'), 'DH920331');
    });
    test('always fits the QR rules', () {
      for (final id in ['1', 'x', '9' * 64, 'é' * 64]) {
        final r = transferReference(id);
        expect(r.length, lessThanOrEqualTo(maxReferenceLength));
        expect(() => payload(reference: r), returnsNormally);
      }
    });
  });
}
