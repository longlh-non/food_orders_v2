import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_orders/customer/api/payment_client.dart';

const _secret = 'SECRET-SERVER-TEXT-9f3';

String _tlv(String tag, String value) =>
    '$tag${value.length.toString().padLeft(2, '0')}$value';

/// A VietQR-shaped payload: amount in tag 54, account in 38 > 01 > 01,
/// transfer content in 62 > 08.
String _payload({
  String account = '123456',
  Object amount = 45000,
  String reference = 'DH482913',
}) {
  final consumer = _tlv('00', '970403') + _tlv('01', account);
  final merchant =
      _tlv('00', 'A000000727') + _tlv('01', consumer) + _tlv('02', 'QRIBFTTA');
  return _tlv('00', '01') +
      _tlv('38', merchant) +
      _tlv('54', '$amount') +
      _tlv('58', 'VN') +
      _tlv('62', _tlv('08', reference));
}

Map<String, Object?> _qr([Map<String, Object?> over = const {}]) => {
  'payload': _payload(),
  'amount': 45000,
  'reference': 'DH482913',
  'dueAt': '2026-11-19T10:05:00.000Z',
  'bankName': 'ACB',
  'accountNumber': '123456',
  'accountName': 'NGUYEN VAN A',
  ...over,
};

PaymentClient _client(http.Response Function(http.Request) handler) =>
    PaymentClient(client: MockClient((r) async => handler(r)));

http.Response _json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Future<PaymentException> _failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on PaymentException catch (e) {
    return e;
  }
  fail('expected a PaymentException');
}

void main() {
  group('fetchInfo', () {
    test('enabled', () async {
      late http.Request seen;
      final info = await _client((r) {
        seen = r;
        return _json({
          'transferEnabled': true,
          'bankName': ' ACB\n',
          'accountNumber': '123456',
          'accountName': 'NGUYEN VAN A',
        });
      }).fetchInfo();
      expect(seen.url.path, '/api/payment-info');
      expect(seen.method, 'GET');
      expect(info.transferEnabled, isTrue);
      expect(info.bankName, 'ACB');
      expect(info.accountNumber, '123456');
      expect(info.accountName, 'NGUYEN VAN A');
    });

    test('disabled', () async {
      final info = await _client((_) => _json({'transferEnabled': false}))
          .fetchInfo();
      expect(info.transferEnabled, isFalse);
      expect(info.bankName, isNull);
    });

    for (final body in <Object?>[
      {'transferEnabled': true},
      {'transferEnabled': true, 'bankName': 'A', 'accountNumber': '1'},
      {
        'transferEnabled': true,
        'bankName': 'A',
        'accountNumber': 1,
        'accountName': 'C',
      },
      {'transferEnabled': 'true'},
      {'transferEnabled': 1},
      {'bankName': 'A'},
      [true],
      'x',
    ]) {
      test('malformed $body throws', () async {
        final e = await _failure(() => _client((_) => _json(body)).fetchInfo());
        expect(e.failure, PaymentFailure.other);
      });
    }

    test('account number with letters throws', () async {
      final e = await _failure(
        () => _client(
          (_) => _json({
            'transferEnabled': true,
            'bankName': 'A',
            'accountNumber': '12ab',
            'accountName': 'C',
          }),
        ).fetchInfo(),
      );
      expect(e.failure, PaymentFailure.other);
    });

    test('not JSON throws', () async {
      final e = await _failure(
        () => _client((_) => http.Response('<html>', 200)).fetchInfo(),
      );
      expect(e.failure, PaymentFailure.other);
    });
  });

  group('fetchQr', () {
    test('parses every field and encodes the id', () async {
      late http.Request seen;
      final qr = await _client((r) {
        seen = r;
        return _json(_qr());
      }).fetchQr('a/b?x=%');
      expect(seen.method, 'GET');
      expect(seen.url.toString(), '/api/orders/a%2Fb%3Fx%3D%25/payment-qr');
      expect(qr.payload, _payload());
      expect(qr.amount, 45000);
      expect(qr.reference, 'DH482913');
      expect(qr.dueAt, DateTime.utc(2026, 11, 19, 10, 5));
      expect(qr.dueAt.isUtc, isTrue);
      expect(qr.bankName, 'ACB');
      expect(qr.accountNumber, '123456');
      expect(qr.accountName, 'NGUYEN VAN A');
    });

    test(
      'accepts a short reference (an id with fewer than 6 digits)',
      () async {
        final qr = await _client(
          (_) => _json(
            _qr({
              'reference': 'DH123',
              'payload': _payload(reference: 'DH123'),
            }),
          ),
        ).fetchQr('o123');
        expect(qr.reference, 'DH123');
      },
    );

    test('status codes map to failures', () async {
      final cases = {
        409: PaymentFailure.notPayable,
        503: PaymentFailure.notSetUp,
        404: PaymentFailure.notFound,
        500: PaymentFailure.other,
        401: PaymentFailure.other,
      };
      for (final entry in cases.entries) {
        final e = await _failure(
          () => _client((_) => http.Response(_secret, entry.key)).fetchQr('o1'),
        );
        expect(e.failure, entry.value, reason: '${entry.key}');
        expect(e.statusCode, entry.key);
      }
    });

    test('a network error is other, without a status', () async {
      final client = PaymentClient(
        client: MockClient((_) async => throw http.ClientException(_secret)),
      );
      final e = await _failure(() => client.fetchQr('o1'));
      expect(e.failure, PaymentFailure.other);
      expect(e.statusCode, isNull);
      expect(e.toString(), isNot(contains(_secret)));
    });

    final bad = <String, Map<String, Object?>>{
      'empty payload': {'payload': ''},
      'payload not a string': {'payload': 5},
      'missing amount': {'amount': null},
      'amount as string': {'amount': '45000'},
      'amount as double': {'amount': 45000.5},
      'amount whole double': {'amount': 45000.0},
      'amount too big': {
        'amount': 55000000001,
        'payload': _payload(amount: 55000000001),
      },
      'amount zero': {'amount': 0},
      'amount negative': {'amount': -1},
      'reference too long': {'reference': 'DH1234567'},
      'reference without digits': {'reference': 'DH'},
      'reference lowercase': {'reference': 'dh123456'},
      'reference trailing newline': {'reference': 'DH123456\n'},
      'account with letters': {'accountNumber': '12345A'},
      'account too long': {'accountNumber': '1' * 20},
      'account empty': {'accountNumber': ''},
      'account not in payload': {'accountNumber': '999999'},
      'amount not in payload': {'amount': 77000},
      'account is a prefix of the payload account': {
        'payload': _payload(account: '1234567890'),
        'accountNumber': '123456',
      },
      'account is a superset of the payload account': {
        'payload': _payload(account: '123456'),
        'accountNumber': '1234567',
      },
      'amount is a substring of the payload amount': {
        'payload': _payload(amount: 450000),
        'amount': 45000,
      },
      'amount only appears elsewhere': {
        'payload': _payload(amount: 1).replaceFirst('54011', '540145000'),
      },
      'account only in the wrong tag': {
        'payload':
            '${_tlv('00', '01')}${_tlv('54', '45000')}'
            '${_tlv('59', '123456')}',
      },
      'payload is not TLV': {'payload': 'hello 123456 45000'},
      'length runs past the end': {'payload': '5405450'},
      'repeated amount tag': {'payload': _payload() + _tlv('54', '45000')},
      'shown reference differs from the QR content': {
        'payload': _payload(reference: 'DH999999'),
      },
      'QR has no transfer content': {
        'payload': _payload().replaceFirst(RegExp(r'62\d\d.*$'), ''),
      },
      'missing reference': {'reference': null},
      'reference not a string': {'reference': 1},
      'missing bankName': {'bankName': null},
      'missing accountNumber': {'accountNumber': null},
      'missing accountName': {'accountName': null},
      'missing dueAt': {'dueAt': null},
      'dueAt not a string': {'dueAt': 1700000000},
      'dueAt garbage': {'dueAt': 'tomorrow'},
      'dueAt without Z': {'dueAt': '2026-11-19T10:05:00'},
      'dueAt with offset': {'dueAt': '2026-11-19T10:05:00+07:00'},
      'dueAt impossible date': {'dueAt': '2026-13-45T10:05:00Z'},
    };
    bad.forEach((name, over) {
      test('$name throws', () async {
        final body = _qr(over);
        final e = await _failure(
          () => _client((_) => _json(body)).fetchQr('o1'),
        );
        expect(e.failure, PaymentFailure.other);
        expect(e.statusCode, 200);
      });
    });

    test('reads UTF-8 without a charset header', () async {
      final qr = await PaymentClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode(
                _qr({
                  'bankName': 'Ngân hàng Ví Dụ',
                  'accountName': 'NGUYỄN VĂN A',
                }),
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ).fetchQr('o1');
      expect(qr.bankName, 'Ngân hàng Ví Dụ');
      expect(qr.accountName, 'NGUYỄN VĂN A');
    });

    test('invalid UTF-8 is a generic error', () async {
      final client = PaymentClient(
        client: MockClient(
          (_) async => http.Response.bytes([0x7b, 0xff, 0xfe, 0x7d], 200),
        ),
      );
      final e = await _failure(() => client.fetchQr('o1'));
      expect(e.failure, PaymentFailure.other);
    });

    test('empty or dot-only ids are refused without a request', () async {
      var calls = 0;
      final client = PaymentClient(
        client: MockClient((_) async {
          calls++;
          return _json(_qr());
        }),
      );
      for (final id in ['', '.', '..', '...']) {
        final e = await _failure(() => client.fetchQr(id));
        expect(e.failure, PaymentFailure.notFound);
      }
      expect(calls, 0);
    });

    test('a body that is not an object throws', () async {
      for (final body in <Object?>[
        [1],
        'x',
        null,
      ]) {
        final e = await _failure(
          () => _client((_) => _json(body)).fetchQr('o1'),
        );
        expect(e.failure, PaymentFailure.other);
      }
    });
  });

  test('no exception text contains the server body', () async {
    final calls = <Future<Object?> Function()>[
      () => _client((_) => http.Response(_secret, 409)).fetchQr('o1'),
      () => _client((_) => http.Response(_secret, 500)).fetchInfo(),
      () => _client((_) => http.Response(_secret, 200)).fetchQr('o1'),
      () =>
          _client((_) => _json(_qr({'payload': _secret, 'amount': _secret})))
              .fetchQr('o1'),
      () => _client((_) => _json({'transferEnabled': _secret})).fetchInfo(),
      () => _client((_) => _json(_qr({'dueAt': _secret}))).fetchQr('o1'),
    ];
    for (final call in calls) {
      final e = await _failure(call);
      expect(e.message, isNot(contains(_secret)));
      expect(e.toString(), isNot(contains(_secret)));
    }
  });
}
