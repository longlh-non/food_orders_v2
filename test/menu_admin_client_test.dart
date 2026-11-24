import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/restaurant/api/menu_admin_client.dart';
import 'package:food_orders/restaurant/state/staff_credentials.dart';
import 'package:food_orders/shared/models/menu_item.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Obviously fake test values.
const staffId = 'test-staff';
const token = 'test-password-1234';
const creds = StaffCredentials(id: staffId, password: token);

Map<String, Object?> itemJson({double price = 4000, bool available = true}) => {
  'id': 'tra-da',
  'name': 'Trà đá',
  'description': '',
  'price': price,
  'category': 'drink',
  'allowToppings': false,
  'image': null,
  'available': available,
};

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Expects [call] to fail with [failure] and an error that never contains
/// the token.
Future<void> expectFailure(
  Future<Object?> call,
  MenuAdminFailure failure, {
  int? status,
}) async {
  try {
    await call;
    fail('should have thrown');
  } on MenuAdminException catch (e) {
    expect(e.failure, failure);
    expect(e.statusCode, status);
    for (final secret in [token, staffId]) {
      expect(e.toString(), isNot(contains(secret)));
      expect(e.message, isNot(contains(secret)));
    }
  }
}

void main() {
  late List<http.Request> sent;
  MenuAdminClient answering(Future<http.Response> Function() respond) {
    sent = [];
    return MenuAdminClient(
      client: MockClient((request) {
        sent.add(request);
        return respond();
      }),
    );
  }

  test(
    'sends PATCH /api/menu/{id} with only the given fields and the token',
    () async {
      final api = answering(() async => json(itemJson(available: false)));

      final item = await api.updateItem(
        'tra-da',
        credentials: creds,
        available: false,
      );

      final request = sent.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/menu/tra-da');
      expect(request.headers['X-Staff-Id'], staffId);
      expect(request.headers['X-Staff-Password'], token);
      expect(request.headers.containsKey('X-Staff-Token'), isFalse);
      expect(request.url.toString(), isNot(contains(token)));
      expect(request.body, isNot(contains(token)));
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(request.body), {'available': false});
      expect(item.id, 'tra-da');
      expect(item.available, isFalse);
    },
  );

  test('price only, and both fields together', () async {
    final api = answering(() async => json(itemJson(price: 5000)));

    await api.updateItem('tra-da', credentials: creds, price: 5000);
    expect(jsonDecode(sent.single.body), {'price': 5000});

    final both = answering(() async => json(itemJson()));
    await both.updateItem(
      'tra-da',
      credentials: creds,
      price: 5000,
      available: true,
    );
    expect(jsonDecode(sent.single.body), {'price': 5000, 'available': true});
  });

  test('the id is encoded into one path segment', () async {
    final api = answering(() async => json(itemJson()));
    await api.updateItem('../orders?x=1', credentials: creds, available: true);
    expect(sent.single.url.pathSegments, ['api', 'menu', '../orders?x=1']);
    expect(sent.single.url.hasQuery, isFalse);
  });

  for (final bad in ['', '.', '..']) {
    test('id "$bad": throws without sending anything', () async {
      final api = answering(() async => json(itemJson()));
      expect(
        () => api.updateItem(bad, credentials: creds, available: true),
        throwsArgumentError,
      );
      expect(sent, isEmpty);
    });
  }

  test('no fields: throws without sending anything', () async {
    final api = answering(() async => json(itemJson()));
    expect(
      () => api.updateItem('tra-da', credentials: creds),
      throwsArgumentError,
    );
    expect(sent, isEmpty);
  });

  for (final (status, failure) in [
    (400, MenuAdminFailure.invalid),
    (401, MenuAdminFailure.wrongCredentials),
    (403, MenuAdminFailure.editingDisabled),
    (404, MenuAdminFailure.notFound),
    (413, MenuAdminFailure.other),
    (500, MenuAdminFailure.other),
  ]) {
    test('$status -> ${failure.name}', () async {
      final api = answering(
        () async => http.Response('server text $token', status),
      );
      await expectFailure(
        api.updateItem('tra-da', credentials: creds, price: 1000),
        failure,
        status: status,
      );
    });
  }

  test('no answer -> other, no status', () async {
    final api = answering(() async => throw http.ClientException('refused'));
    await expectFailure(
      api.updateItem('tra-da', credentials: creds, price: 1000),
      MenuAdminFailure.other,
    );
  });

  for (final (label, body) in [
    ('not JSON', http.Response('<html>', 200)),
    ('a JSON list', json([1, 2])),
    ('an item missing its name', json({...itemJson()}..remove('name'))),
    ('available as a string', json({...itemJson(), 'available': 'yes'})),
  ]) {
    test('a 200 with $label -> other', () async {
      final api = answering(() async => body);
      await expectFailure(
        api.updateItem('tra-da', credentials: creds, price: 1000),
        MenuAdminFailure.other,
        status: 200,
      );
    });
  }

  test('429 -> tooManyTries, with the Retry-After seconds when sent', () async {
    final api = answering(
      () async => http.Response('locked', 429, headers: {'retry-after': '42'}),
    );
    try {
      await api.updateItem('tra-da', credentials: creds, price: 1000);
      fail('should throw');
    } on MenuAdminException catch (e) {
      expect(e.failure, MenuAdminFailure.tooManyTries);
      expect(e.retryAfterSeconds, 42);
    }
    final noHeader = answering(() async => http.Response('locked', 429));
    try {
      await noHeader.updateItem('tra-da', credentials: creds, price: 1000);
      fail('should throw');
    } on MenuAdminException catch (e) {
      expect(e.failure, MenuAdminFailure.tooManyTries);
      expect(e.retryAfterSeconds, isNull);
    }
  });

  test('non-ASCII or empty credentials are refused without sending', () {
    final api = answering(() async => json(itemJson()));
    for (final bad in [
      const StaffCredentials(id: 'nhân-viên', password: token),
      const StaffCredentials(id: staffId, password: 'mật-khẩu-dài'),
      const StaffCredentials(id: '', password: token),
    ]) {
      expect(
        () => api.updateItem('tra-da', credentials: bad, price: 1000),
        throwsArgumentError,
      );
    }
    expect(sent, isEmpty);
  });

  test('StaffCredentials never shows its values', () {
    expect(creds.toString(), isNot(contains(token)));
    expect(creds.toString(), isNot(contains(staffId)));
  });

  group('addItem', () {
    const draft = NewMenuItem(
      name: 'Xôi lá cẩm',
      description: 'Ngon',
      price: 30000,
      category: MenuCategory.food,
      allowToppings: true,
    );
    Map<String, Object?> created() => {
      ...itemJson(),
      'id': 'xoi-la-cam',
      'name': 'Xôi lá cẩm',
    };

    test('sends POST /api/menu with exactly the draft keys', () async {
      final api = answering(() async => json(created(), 201));
      final item = await api.addItem(draft, credentials: creds);
      final request = sent.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), '/api/menu');
      expect(request.headers['X-Staff-Id'], staffId);
      expect(request.headers['X-Staff-Password'], token);
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(request.body, isNot(contains(token)));
      expect(jsonDecode(request.body), {
        'name': 'Xôi lá cẩm',
        'description': 'Ngon',
        'price': 30000,
        'category': 'food',
        'allowToppings': true,
      });
      expect(item.id, 'xoi-la-cam');
    });

    test('image is sent only when set', () async {
      final api = answering(() async => json(created(), 201));
      await api.addItem(
        const NewMenuItem(
          name: 'A',
          price: 0,
          category: MenuCategory.drink,
          image: 'a.webp',
        ),
        credentials: creds,
      );
      expect(jsonDecode(sent.single.body)['image'], 'a.webp');
    });

    for (final (status, failure) in [
      (400, MenuAdminFailure.invalid),
      (401, MenuAdminFailure.wrongCredentials),
      (403, MenuAdminFailure.editingDisabled),
      (409, MenuAdminFailure.duplicate),
      (413, MenuAdminFailure.invalid),
      (429, MenuAdminFailure.tooManyTries),
      (500, MenuAdminFailure.other),
      (503, MenuAdminFailure.menuFull),
      (200, MenuAdminFailure.other),
      (204, MenuAdminFailure.other),
    ]) {
      test('$status -> ${failure.name}', () async {
        final api = answering(
          () async => http.Response('server text $token', status),
        );
        await expectFailure(
          api.addItem(draft, credentials: creds),
          failure,
          status: status,
        );
      });
    }

    test('429 carries Retry-After', () async {
      final api = answering(
        () async => http.Response('x', 429, headers: {'retry-after': '30'}),
      );
      try {
        await api.addItem(draft, credentials: creds);
        fail('should throw');
      } on MenuAdminException catch (e) {
        expect(e.retryAfterSeconds, 30);
      }
    });

    test('no answer -> other', () async {
      final api = answering(() async => throw http.ClientException('x'));
      await expectFailure(
        api.addItem(draft, credentials: creds),
        MenuAdminFailure.other,
      );
    });

    for (final (label, body) in [
      ('not JSON', http.Response('<html>', 201)),
      ('a list', json([1], 201)),
      ('a missing name', json({...created()}..remove('name'), 201)),
    ]) {
      test('a 201 with $label -> other', () async {
        final api = answering(() async => body);
        await expectFailure(
          api.addItem(draft, credentials: creds),
          MenuAdminFailure.other,
          status: 201,
        );
      });
    }

    test('unsendable credentials: ArgumentError, nothing sent', () {
      final api = answering(() async => json(created(), 201));
      for (final bad in [
        const StaffCredentials(id: 'nhân-viên', password: token),
        const StaffCredentials(id: staffId, password: ''),
      ]) {
        expect(() => api.addItem(draft, credentials: bad), throwsArgumentError);
      }
      expect(sent, isEmpty);
    });
  });
}
