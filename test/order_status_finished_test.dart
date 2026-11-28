import 'dart:async';
import 'dart:convert';

import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:food_orders/shared/l10n.dart';
import 'package:food_orders/shared/localized_labels.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _staff = {'X-Staff-Id': 'boss-id', 'X-Staff-Password': 'hunter2-secret'};

Map<String, Object?> _json(Object? status) => {
  'id': 'abc',
  'customerName': 'An',
  'items': [
    {'name': 'Xôi thịt', 'quantity': 1, 'price': 25000},
  ],
  'status': status,
  'placedAt': '2026-11-19T12:00:00.000',
};

Order _order(OrderStatus status, {String id = 'abc'}) => Order(
  id: id,
  customerName: 'An',
  items: [OrderItem(name: 'Xôi thịt', quantity: 1, price: 25000)],
  status: status,
  placedAt: DateTime(2026, 11, 19, 12),
);

http.Response _reply(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _expectFailure(Future<Object?> call, int? statusCode) =>
    expectLater(
      call,
      throwsA(
        isA<OrderRequestException>().having(
          (e) => e.statusCode,
          'statusCode',
          statusCode,
        ),
      ),
    );

OrderApiClient _answering(http.Response Function(http.Request) respond) =>
    OrderApiClient(client: MockClient((r) async => respond(r)));

void main() {
  group('OrderStatus.finished model', () {
    test('finished round-trips through JSON', () {
      final o = Order.fromJson(_json('finished'));
      expect(o.status, OrderStatus.finished);
      expect(Order.fromJson(o.toJson()).status, OrderStatus.finished);
      expect(o.toJson()['status'], 'finished');
    });

    test('an unknown status still does not parse', () {
      expect(() => Order.fromJson(_json('bogus')), throwsArgumentError);
    });

    test('ready and delivered still parse', () {
      expect(Order.fromJson(_json('ready')).status, OrderStatus.ready);
      expect(Order.fromJson(_json('delivered')).status, OrderStatus.delivered);
    });
  });

  group('localized texts', () {
    test('finished is "Đã phục vụ" in vi, non-empty in all locales', () {
      final vi = lookupAppLocalizations(const Locale('vi'));
      expect(OrderStatus.finished.localized(vi), 'Đã phục vụ');
      expect(vi.orderMarkFinished, 'Đánh dấu đã phục vụ');
      expect(
        vi.orderCheckPaidNote,
        'Vui lòng kiểm tra nếu đơn hàng đã được thanh toán',
      );
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        final texts = [
          OrderStatus.finished.localized(l10n),
          l10n.orderMarkFinished,
          l10n.orderCheckPaidNote,
          l10n.orderCancel,
          l10n.orderCancelConfirm,
          l10n.orderCancelPaidNote,
          l10n.orderCancelFinalNote,
          l10n.orderChangeStatus,
          l10n.orderChangeStatusFinishedNote,
          l10n.orderChangeStatusNotAllowed,
          l10n.orderChangeStatusCancelled,
        ];
        for (final t in texts) {
          expect(t.trim(), isNotEmpty, reason: '$locale');
        }
      }
    });
  });

  group('activeOrders', () {
    final repo = OrderRepository.instance;
    tearDown(() => repo.setOrdersForTest(const []));

    test('leaves out finished, delivered and cancelled', () {
      repo.setOrdersForTest([
        _order(OrderStatus.preparing, id: 'a'),
        _order(OrderStatus.finished, id: 'b'),
        _order(OrderStatus.cancelled, id: 'c'),
        _order(OrderStatus.delivered, id: 'd'),
        _order(OrderStatus.awaiting_payment, id: 'e'),
      ]);
      expect(repo.activeOrders.map((o) => o.id), ['a', 'e']);
    });
  });

  group('updateStatus with staff headers', () {
    test('sends the headers and the status body', () async {
      late http.Request sent;
      final api = _answering((r) {
        sent = r;
        return _reply(_order(OrderStatus.finished).toJson());
      });
      final updated = await api.updateStatus(
        'abc',
        OrderStatus.finished,
        staffHeaders: _staff,
      );
      expect(updated.status, OrderStatus.finished);
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/api/orders/abc');
      expect(sent.headers['X-Staff-Id'], 'boss-id');
      expect(sent.headers['X-Staff-Password'], 'hunter2-secret');
      expect(jsonDecode(sent.body), {'status': 'finished'});
    });

    // `Retry-After` is deliberately not read: the payment calls ignore it too,
    // so the page can only see the status code.
    test('statuses map to distinct failures', () async {
      for (final code in [400, 401, 403, 404, 409, 429]) {
        final api = _answering(
          (_) => http.Response(
            'secret server detail',
            code,
            headers: code == 429 ? {'retry-after': '30'} : {},
          ),
        );
        await _expectFailure(
          api.updateStatus('abc', OrderStatus.finished, staffHeaders: _staff),
          code,
        );
      }
    });

    test('no answer has no status code', () async {
      final api = OrderApiClient(
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      await _expectFailure(
        api.updateStatus('abc', OrderStatus.finished, staffHeaders: _staff),
        null,
      );
    });

    test('header values are never in errors, toString or the log', () async {
      final printed = <String>[];
      final oldPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) =>
          printed.add(message ?? '');
      addTearDown(() => debugPrint = oldPrint);

      final lines = <String>[];
      await runZoned(
        () async {
          for (final code in [401, 403, 409, 429, 500]) {
            final api = _answering((_) => http.Response('x', code));
            try {
              await api.updateStatus(
                'abc',
                OrderStatus.finished,
                staffHeaders: _staff,
              );
            } on OrderRequestException catch (e) {
              lines
                ..add(e.message)
                ..add(e.toString());
            }
          }
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => lines.add(line),
        ),
      );
      for (final text in [...lines, ...printed]) {
        expect(text, isNot(contains('hunter2-secret')));
        expect(text, isNot(contains('boss-id')));
      }
    });

    test(
      'the repository passes headers and keeps the cache on failure',
      () async {
        final repo = OrderRepository.instance;
        addTearDown(() {
          repo.setApiForTest(OrderApiClient());
          repo.setOrdersForTest(const []);
        });
        repo.setOrdersForTest([_order(OrderStatus.preparing)]);
        repo.setApiForTest(_answering((_) => http.Response('no', 409)));
        await _expectFailure(
          repo.updateStatus('abc', OrderStatus.finished, staffHeaders: _staff),
          409,
        );
        expect(repo.orders.single.status, OrderStatus.preparing);

        late http.Request sent;
        repo.setApiForTest(
          _answering((r) {
            sent = r;
            return _reply(_order(OrderStatus.finished).toJson());
          }),
        );
        await repo.updateStatus(
          'abc',
          OrderStatus.finished,
          staffHeaders: _staff,
        );
        expect(sent.headers['X-Staff-Id'], 'boss-id');
        expect(repo.orders.single.status, OrderStatus.finished);
      },
    );
  });
}
