import 'dart:convert';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/menu_api.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:food_orders_backend/staff_gate.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Obviously fake test values; never real credentials.
const goodId = 'test-staff';
const goodPassword = 'test-password-123';

Request staffRequest({String? id, String? password, String? oldToken}) =>
    Request(
      'GET',
      Uri.parse('http://localhost/orders/export?month=2026-11'),
      headers: {
        staffIdHeader: ?id,
        staffPasswordHeader: ?password,
        'x-staff-token': ?oldToken,
      },
    );

Request good() => staffRequest(id: goodId, password: goodPassword);

/// A clock the test moves by hand.
class FakeClock {
  DateTime time = DateTime(2026, 11, 19, 10);
  DateTime call() => time;
  void advance(Duration d) => time = time.add(d);
}

void main() {
  group('which configurations enable staff routes', () {
    test('a valid ID and password: enabled, the right pair passes', () {
      final gate = StaffGate(id: goodId, password: goodPassword);
      expect(gate.enabled, isTrue);
      expect(gate.check(good()), isNull);
    });

    test('values are trimmed', () {
      final gate = StaffGate(id: '  $goodId ', password: '$goodPassword\n');
      expect(gate.check(good()), isNull);
    });

    test('exactly 12 password characters and a 64-character ID are enough', () {
      final id = 'a' * maxStaffIdLength;
      final gate = StaffGate(id: id, password: '123456789012');
      expect(gate.enabled, isTrue);
      expect(
        gate.check(staffRequest(id: id, password: '123456789012')),
        isNull,
      );
    });

    for (final (label, id, password) in <(String, String?, String?)>[
      ('nothing set', null, null),
      ('no ID', null, goodPassword),
      ('no password', goodId, null),
      ('empty ID', '', goodPassword),
      ('whitespace-only ID', '   ', goodPassword),
      ('ID over 64 characters', 'a' * 65, goodPassword),
      ('password of 11 characters', goodId, '12345678901'),
      ('password of 11 plus spaces', goodId, ' 12345678901 '),
      ('non-ASCII ID', 'nhân-viên', goodPassword),
      ('non-ASCII password', goodId, 'mật-khẩu-dài-đủ'),
      ('a control character in the password', goodId, 'test-pass\u0001word'),
    ]) {
      test('$label -> disabled, 403 even with matching headers', () {
        final gate = StaffGate(id: id, password: password);
        expect(gate.enabled, isFalse);
        expect(
          gate.check(staffRequest(id: id, password: password))?.statusCode,
          403,
        );
        expect(gate.check(good())?.statusCode, 403);
      });
    }
  });

  group('wrong or missing credentials', () {
    late StaffGate gate;
    setUp(() => gate = StaffGate(id: goodId, password: goodPassword));

    Future<String> body(Response r) => r.readAsString();

    test('every kind of wrong gets the same 401 body', () async {
      final bodies = <String>{};
      for (final req in [
        staffRequest(id: 'other', password: goodPassword),
        staffRequest(id: goodId, password: 'wrong-password-1'),
        staffRequest(id: 'other', password: 'wrong-password-1'),
        staffRequest(id: goodId),
        staffRequest(password: goodPassword),
        staffRequest(id: '', password: ''),
        staffRequest(),
      ]) {
        // A fresh gate each time, so the lockout doesn't kick in.
        final response = StaffGate(
          id: goodId,
          password: goodPassword,
        ).check(req)!;
        expect(response.statusCode, 401);
        expect(response.headers['www-authenticate'], isNull);
        bodies.add(await body(response));
      }
      expect(bodies, hasLength(1));
      expect(jsonDecode(bodies.single), {
        'error': 'Missing or wrong staff ID or password',
      });
    });

    test('the old X-Staff-Token header alone no longer works', () {
      expect(gate.check(staffRequest(oldToken: goodPassword))?.statusCode, 401);
    });

    test('responses never contain the configured or sent values', () async {
      final responses = [
        gate.check(staffRequest(id: 'guess-id', password: 'guess-password'))!,
        StaffGate().check(staffRequest(id: goodId, password: goodPassword))!,
      ];
      for (final r in responses) {
        final text = '${await body(r)} ${r.headers}';
        for (final secret in [
          goodId,
          goodPassword,
          'guess-id',
          'guess-password',
        ]) {
          expect(text, isNot(contains(secret)));
        }
      }
    });
  });

  group('lockout after repeated wrong attempts', () {
    late FakeClock clock;
    late StaffGate gate;
    setUp(() {
      clock = FakeClock();
      gate = StaffGate(id: goodId, password: goodPassword, now: clock.call);
    });

    Request wrong() => staffRequest(id: goodId, password: 'wrong-password-1');

    test('4 failures do not lock', () {
      for (var i = 0; i < maxStaffFailures - 1; i++) {
        expect(gate.check(wrong())?.statusCode, 401);
      }
      expect(gate.check(good()), isNull);
    });

    test('the 5th failure locks: 429 with Retry-After, even for the right '
        'pair, until 60 s have passed', () {
      for (var i = 0; i < maxStaffFailures; i++) {
        expect(gate.check(wrong())?.statusCode, 401);
      }
      final locked = gate.check(good())!;
      expect(locked.statusCode, 429);
      expect(locked.headers['retry-after'], '60');
      expect(locked.headers['www-authenticate'], isNull);

      clock.advance(const Duration(seconds: 59));
      expect(gate.check(good())?.statusCode, 429);
      expect(gate.check(good())!.headers['retry-after'], '1');

      clock.advance(const Duration(seconds: 1));
      expect(gate.check(good()), isNull);
    });

    test('failures older than 60 s no longer count', () {
      for (var i = 0; i < maxStaffFailures - 1; i++) {
        gate.check(wrong());
      }
      clock.advance(lockoutWindow);
      expect(gate.check(wrong())?.statusCode, 401);
      expect(gate.check(good()), isNull, reason: 'only 1 recent failure');
    });

    test('a wrong ID with the right password still counts as a failure', () {
      for (var i = 0; i < maxStaffFailures; i++) {
        gate.check(staffRequest(id: 'nope', password: goodPassword));
      }
      expect(gate.check(good())?.statusCode, 429);
    });

    test('a disabled gate never locks or counts', () {
      final off = StaffGate(now: clock.call);
      for (var i = 0; i < 10; i++) {
        expect(off.check(wrong())?.statusCode, 403);
      }
    });
  });

  group('constantTimeEquals', () {
    test('equal and different strings', () {
      expect(constantTimeEquals('', ''), isTrue);
      expect(constantTimeEquals(goodPassword, goodPassword), isTrue);
      expect(constantTimeEquals('abc', 'abd'), isFalse);
      expect(constantTimeEquals('abc', 'ab'), isFalse);
      expect(constantTimeEquals('ab', 'abc'), isFalse);
      expect(constantTimeEquals('ab\u0000', 'ab'), isFalse);
    });
  });

  group('through the real routes', () {
    late FakeClock clock;
    setUp(() => clock = FakeClock());

    Future<int> exportStatus(
      StaffGate gate,
      Map<String, String> headers,
    ) async {
      final db = openDatabase(':memory:');
      final api = OrdersApi(db, staffGate: gate);
      final response = await api.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/orders/export?month=2026-11'),
          headers: headers,
        ),
      );
      await api.close();
      db.close();
      return response.statusCode;
    }

    Future<int> menuStatus(StaffGate gate, Map<String, String> headers) async {
      final db = openDatabase(':memory:');
      final response = await MenuApi(db, staffGate: gate).handler(
        Request(
          'PATCH',
          Uri.parse('http://localhost/menu/tra-da'),
          headers: headers,
          body: '{"available": false}',
        ),
      );
      db.close();
      return response.statusCode;
    }

    const right = {staffIdHeader: goodId, staffPasswordHeader: goodPassword};
    const wrongPair = {
      staffIdHeader: goodId,
      staffPasswordHeader: 'wrong-password-1',
    };

    for (final (name, status) in [
      ('GET /orders/export', exportStatus),
      ('PATCH /menu/{id}', menuStatus),
    ]) {
      test('$name: 200 / 401 / 403 / 429', () async {
        StaffGate gate() =>
            StaffGate(id: goodId, password: goodPassword, now: clock.call);
        expect(await status(gate(), right), 200);
        expect(await status(gate(), wrongPair), 401);
        expect(await status(StaffGate(), right), 403);

        final locking = gate();
        for (var i = 0; i < maxStaffFailures; i++) {
          await status(locking, wrongPair);
        }
        expect(await status(locking, right), 429);
      });
    }

    test(
      'CORS: a cross-site preflight may not send the staff headers',
      () async {
        final db = openDatabase(':memory:');
        final api = OrdersApi(
          db,
          staffGate: StaffGate(id: goodId, password: goodPassword),
        );
        final response = await api.handler(
          Request(
            'OPTIONS',
            Uri.parse('http://localhost/orders/export?month=2026-11'),
            headers: {
              'origin': 'https://evil.example',
              'access-control-request-method': 'GET',
              'access-control-request-headers': 'x-staff-id, x-staff-password',
            },
          ),
        );
        await api.close();
        db.close();
        final allowed = (response.headers['access-control-allow-headers'] ?? '')
            .toLowerCase();
        expect(allowed, isNot(contains('x-staff-id')));
        expect(allowed, isNot(contains('x-staff-password')));
      },
    );
  });
}
