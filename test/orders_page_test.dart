import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/restaurant/pages/orders_page.dart';
import 'package:food_orders/restaurant/state/staff_credentials.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:food_orders/shared/money.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/l10n_app.dart';

Order orderWith(List<OrderItem> items, {String id = 'order-0001'}) => Order(
  id: id,
  customerName: 'An',
  items: items,
  status: OrderStatus.preparing,
  placedAt: DateTime(2026, 11, 12, 8, 30),
);

Future<void> pumpOrders(
  WidgetTester tester,
  List<Order> orders, {
  double width = 800,
  double textScale = 1.0,
  DateTime Function()? now,
  void Function()? chime,
}) async {
  OrderRepository.instance.setOrdersForTest(orders);
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    l10nApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: OrdersPage(now: now ?? DateTime.now, chime: chime ?? () {}),
    ),
  );
}

void main() {
  void reset() => OrderRepository.instance
    ..setApiForTest(OrderApiClient())
    ..setOrdersForTest(const []);
  setUp(reset);
  tearDown(reset);

  final withToppings = OrderItem(
    menuItemId: 'xoi-thit',
    name: 'Xôi thịt',
    quantity: 2,
    price: 25000,
    toppings: const [
      OrderTopping(id: 'cha', name: 'Thêm chả', price: 10000),
      OrderTopping(id: 'trung', name: 'Thêm trứng tráng', price: 8000),
    ],
  );
  final plain = OrderItem(
    menuItemId: 'tra-da',
    name: 'Trà đá',
    quantity: 1,
    price: 4000,
  );

  testWidgets('shows toppings under the item that has them, only there', (
    tester,
  ) async {
    await pumpOrders(tester, [
      orderWith([withToppings, plain]),
    ]);

    expect(find.text('2× Xôi thịt'), findsOneWidget);
    expect(find.text('+ Thêm chả, + Thêm trứng tráng'), findsOneWidget);
    expect(find.text('1× Trà đá'), findsOneWidget);
    expect(find.textContaining('+ '), findsOneWidget);
  });

  testWidgets('an id shorter than 4 characters is shown whole, no crash', (
    tester,
  ) async {
    await pumpOrders(tester, [
      orderWith([plain], id: 'x1'),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('Đơn #x1 — An'), findsOneWidget);
  });

  testWidgets('line subtotal is (price + toppings) x quantity, in VNĐ', (
    tester,
  ) async {
    await pumpOrders(tester, [
      orderWith([withToppings, plain]),
    ]);

    // (25.000 + 10.000 + 8.000) x 2 = 86.000; plus 4.000 = 90.000.
    expect(find.text(formatVnd(86000)), findsOneWidget);
    expect(find.text(formatVnd(4000)), findsOneWidget);
    expect(find.text('Tổng: ${formatVnd(90000)}'), findsOneWidget);
    expect(find.text('Tổng: 90.000 VNĐ'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('an order without any toppings renders as before', (
    tester,
  ) async {
    await pumpOrders(tester, [
      orderWith([plain]),
    ]);

    expect(find.text('1× Trà đá'), findsOneWidget);
    expect(find.textContaining('+ '), findsNothing);
    expect(find.text('Tổng: ${formatVnd(4000)}'), findsOneWidget);
  });

  // Text x2.0 is not tested: the test font draws every letter 1 em wide, so
  // a 7-digit price alone is wider than the card (follow-up in the review).
  for (final scale in [1.0, 1.3]) {
    testWidgets('long name, 4 toppings and a big price fit at 360 px '
        '(text x$scale)', (tester) async {
      final big = OrderItem(
        menuItemId: 'mi-tom-bo',
        name: 'Mì tôm bò thêm rau thơm và hành phi, phần lớn cho hai người',
        quantity: 25,
        price: 30000,
        toppings: const [
          OrderTopping(id: 'cha', name: 'Thêm chả', price: 10000),
          OrderTopping(id: 'thit', name: 'Thêm thịt', price: 10000),
          OrderTopping(id: 'trung', name: 'Thêm trứng tráng', price: 8000),
          OrderTopping(id: 'lap', name: 'Thêm lạp xưởng', price: 12000),
        ],
      );
      await pumpOrders(
        tester,
        [
          orderWith([big, plain]),
        ],
        width: 360,
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      // (30.000 + 40.000) x 25 = 1.750.000, shown in full.
      expect(find.text(formatVnd(1750000)), findsOneWidget);
      expect(
        find.text(
          '+ Thêm chả, + Thêm thịt, + Thêm trứng tráng, + Thêm lạp xưởng',
        ),
        findsOneWidget,
      );
    });
  }

  group('Vietnamese status chip and action label (vi-translate)', () {
    Order of(OrderStatus status, {String id = 'order-0001'}) => Order(
      id: id,
      customerName: 'An',
      items: [OrderItem(name: 'Trà đá', quantity: 1, price: 4000)],
      status: status,
      placedAt: DateTime(2026, 11, 19),
    );

    testWidgets('every status shows its own Vietnamese chip text', (
      tester,
    ) async {
      await pumpOrders(tester, [
        for (final s in OrderStatus.values) of(s, id: 'order-${s.name}'),
      ]);
      for (final s in OrderStatus.values) {
        expect(find.text(s.label), findsWidgets, reason: s.name);
      }
    });

    testWidgets('preparing shows the "Đánh dấu sẵn sàng" action; '
        'ready shows "Đánh dấu đã giao"', (tester) async {
      await pumpOrders(tester, [
        of(OrderStatus.preparing, id: 'order-preparing'),
        of(OrderStatus.ready, id: 'order-ready'),
      ]);
      expect(
        find.widgetWithText(FilledButton, 'Đánh dấu sẵn sàng'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Đánh dấu đã giao'),
        findsOneWidget,
      );
    });
  });

  group('status changes report failure', () {
    const failure = 'Không thể cập nhật đơn hàng. Thử lại.';
    final plain = OrderItem(name: 'Trà đá', quantity: 1, price: 4000);

    /// The repository answers every request with [respond].
    void backend(Future<http.Response> Function(http.Request) respond) {
      OrderRepository.instance.setApiForTest(
        OrderApiClient(client: MockClient(respond)),
      );
    }

    OrderStatus statusOf(String id) =>
        OrderRepository.instance.orders.firstWhere((o) => o.id == id).status;

    for (final (label, respond) in <(String, Future<http.Response> Function())>[
      ('500', () async => http.Response('Internal Server Error', 500)),
      ('no answer', () async => throw http.ClientException('refused')),
    ]) {
      testWidgets('a failed status button ($label) says so; status unchanged', (
        tester,
      ) async {
        backend((_) => respond());
        await pumpOrders(tester, [
          orderWith([plain]),
        ]);

        await tester.tap(
          find.widgetWithText(FilledButton, 'Đánh dấu sẵn sàng'),
        );
        await tester.pumpAndSettle();

        expect(find.text(failure), findsOneWidget);
        expect(statusOf('order-0001'), OrderStatus.preparing);
        expect(find.textContaining('Internal Server Error'), findsNothing);
      });
    }

    testWidgets('a successful status button shows no failure', (tester) async {
      final order = orderWith([plain]);
      backend(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode(order.copyWith(status: OrderStatus.ready).toJson()),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await pumpOrders(tester, [order]);

      await tester.tap(find.widgetWithText(FilledButton, 'Đánh dấu sẵn sàng'));
      await tester.pumpAndSettle();

      expect(find.text(failure), findsNothing);
      expect(statusOf('order-0001'), OrderStatus.ready);
      expect(
        find.widgetWithText(FilledButton, 'Đánh dấu đã giao'),
        findsOneWidget,
      );
    });

    testWidgets('a new order shows a SnackBar with no Accept action', (
      tester,
    ) async {
      await pumpOrders(tester, []);

      // A new order (cash orders start `preparing`) arrives.
      OrderRepository.instance.setOrdersForTest([
        orderWith([plain], id: 'order-0002'),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Đơn mới từ An'), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);
    });
  });

  group('payment on the order card', () {
    final now = DateTime.utc(2026, 11, 19, 10);
    final soon = now.add(const Duration(minutes: 10));
    final item = OrderItem(name: 'Trà đá', quantity: 1, price: 4000);

    Order make(
      String id,
      OrderStatus status, {
      PaymentMethod method = PaymentMethod.cash,
      DateTime? due,
    }) => Order(
      id: id,
      customerName: 'An',
      items: [item],
      status: status,
      placedAt: DateTime(2026, 11, 19),
      paymentMethod: method,
      paymentDueAt: due,
    );

    Order transfer(String id, OrderStatus status, {DateTime? due}) =>
        make(id, status, method: PaymentMethod.bank_transfer, due: due);

    testWidgets('shows the method; no field means cash', (tester) async {
      await pumpOrders(tester, [
        make('order-100001', OrderStatus.preparing),
        transfer('order-100002', OrderStatus.preparing),
        Order.fromJson({
          'id': 'order-100003',
          'customerName': 'An',
          'items': [
            {'name': 'Trà đá', 'quantity': 1, 'price': 4000},
          ],
          'status': 'preparing',
          'placedAt': '2026-11-19T08:00:00.000',
        }),
      ], now: () => now);
      expect(find.text('Tiền mặt'), findsNWidgets(2));
      expect(find.text('Chuyển khoản'), findsOneWidget);
    });

    testWidgets('awaiting payment: transfer content, no status button', (
      tester,
    ) async {
      await pumpOrders(tester, [
        transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
      ], now: () => now);
      expect(find.text('Nội dung chuyển khoản: DH482913'), findsOneWidget);
      expect(find.text('Chưa thanh toán'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Hết hạn thanh toán'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    test('transfer content: last 6 digits, short ids, no-digit hash', () {
      expect(transferReference('1700000123456'), 'DH123456');
      expect(transferReference('a-12'), 'DH12');
      // Same value as backend transferReference('abc') on the VM.
      expect(transferReference('abc'), 'DH920331');
      expect(transferReference('abc'), matches(RegExp(r'^DH\d{6}$')));
    });

    testWidgets('expired unpaid transfer says so, no status button', (
      tester,
    ) async {
      await pumpOrders(tester, [
        transfer(
          'order-482913',
          OrderStatus.cancelled,
          due: now.subtract(const Duration(minutes: 1)),
        ),
      ], now: () => now);
      expect(find.text('Hết hạn thanh toán'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('a staff-cancelled transfer (no deadline) is not "expired"', (
      tester,
    ) async {
      await pumpOrders(tester, [
        transfer('order-482913', OrderStatus.cancelled),
      ], now: () => now);
      expect(find.text('Hết hạn thanh toán'), findsNothing);
    });

    testWidgets('a lapsed deadline shows expired before the server sweep, '
        'and the badge drops it', (tester) async {
      var clock = now;
      await pumpOrders(tester, [
        transfer(
          'order-482913',
          OrderStatus.awaiting_payment,
          due: now.add(const Duration(seconds: 30)),
        ),
      ], now: () => clock);
      expect(find.text('Nội dung chuyển khoản: DH482913'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      clock = now.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('Hết hạn thanh toán'), findsOneWidget);
      expect(find.textContaining('Nội dung chuyển khoản'), findsNothing);
      expect(find.text('1'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a renewed order looks awaiting again, no expired text', (
      tester,
    ) async {
      await pumpOrders(tester, [
        transfer(
          'order-482913',
          OrderStatus.cancelled,
          due: now.subtract(const Duration(minutes: 1)),
        ),
      ], now: () => now);
      expect(find.text('Hết hạn thanh toán'), findsOneWidget);
      OrderRepository.instance.setOrdersForTest([
        transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
      ]);
      await tester.pump();
      expect(find.text('Hết hạn thanh toán'), findsNothing);
      expect(find.text('Nội dung chuyển khoản: DH482913'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('buttons: preparing -> Mark ready, ready -> Mark delivered', (
      tester,
    ) async {
      await pumpOrders(tester, [
        make('order-100001', OrderStatus.preparing),
        make('order-100002', OrderStatus.ready),
        make('order-100003', OrderStatus.delivered),
      ], now: () => now);
      expect(
        find.widgetWithText(FilledButton, 'Đánh dấu sẵn sàng'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Đánh dấu đã giao'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNWidgets(2));
    });

    testWidgets('badge counts awaiting_payment + preparing only', (
      tester,
    ) async {
      await pumpOrders(tester, [
        transfer('order-100001', OrderStatus.awaiting_payment, due: soon),
        make('order-100002', OrderStatus.preparing),
        make('order-100003', OrderStatus.ready),
        make('order-100004', OrderStatus.delivered),
        make('order-100005', OrderStatus.cancelled),
        // revived as cash: preparing again, counts
        make('order-100006', OrderStatus.preparing),
        // renewed: awaiting again, counts
        transfer('order-100007', OrderStatus.awaiting_payment, due: soon),
        // expired unpaid: does not count
        transfer(
          'order-100008',
          OrderStatus.cancelled,
          due: now.subtract(const Duration(minutes: 1)),
        ),
      ], now: () => now);
      expect(find.text('4'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    group('chime', () {
      late int rings;
      late DateTime clock;
      setUp(() {
        rings = 0;
        clock = now;
      });

      Future<void> start(WidgetTester tester, List<Order> initial) =>
          pumpOrders(tester, initial, now: () => clock, chime: () => rings++);

      Future<void> arrive(WidgetTester tester, List<Order> orders) async {
        OrderRepository.instance.setOrdersForTest(orders);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      testWidgets('initial load rings nothing', (tester) async {
        await start(tester, [
          make('order-100001', OrderStatus.preparing),
          transfer('order-100002', OrderStatus.awaiting_payment, due: soon),
        ]);
        expect(rings, 0);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('new preparing order: one chime, plain snackbar', (
        tester,
      ) async {
        await start(tester, []);
        await arrive(tester, [make('order-100001', OrderStatus.preparing)]);
        expect(rings, 1);
        expect(find.text('Đơn mới từ An'), findsOneWidget);
        expect(find.byType(SnackBarAction), findsNothing);
      });

      testWidgets('new awaiting_payment order: one chime, says so', (
        tester,
      ) async {
        await start(tester, []);
        await arrive(tester, [
          transfer('order-100001', OrderStatus.awaiting_payment, due: soon),
        ]);
        expect(rings, 1);
        expect(find.text('Đơn mới từ An — chờ chuyển khoản'), findsOneWidget);
        expect(find.byType(SnackBarAction), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('arrived awaiting, then paid: still one chime in total', (
        tester,
      ) async {
        await start(tester, []);
        await arrive(tester, [
          transfer('order-100001', OrderStatus.awaiting_payment, due: soon),
        ]);
        await arrive(tester, [transfer('order-100001', OrderStatus.preparing)]);
        expect(rings, 1);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('loaded as awaiting, paid later: rings once, never again', (
        tester,
      ) async {
        await start(tester, [
          transfer('order-100001', OrderStatus.awaiting_payment, due: soon),
        ]);
        await arrive(tester, [transfer('order-100001', OrderStatus.preparing)]);
        expect(rings, 1);
        await arrive(tester, [transfer('order-100001', OrderStatus.ready)]);
        await arrive(tester, [transfer('order-100001', OrderStatus.preparing)]);
        expect(rings, 1);
      });

      testWidgets('expired order revived as cash: no chime', (tester) async {
        final expired = transfer(
          'order-100001',
          OrderStatus.cancelled,
          due: now.subtract(const Duration(minutes: 1)),
        );
        await start(tester, [expired]);
        await arrive(tester, [make('order-100001', OrderStatus.preparing)]);
        expect(rings, 0);
      });

      testWidgets('expired order renewed to awaiting: no chime, nor on pay', (
        tester,
      ) async {
        await start(tester, [
          transfer(
            'order-100001',
            OrderStatus.cancelled,
            due: now.subtract(const Duration(minutes: 1)),
          ),
        ]);
        await arrive(tester, [
          transfer('order-100001', OrderStatus.awaiting_payment, due: soon),
        ]);
        expect(rings, 0);
        await arrive(tester, [transfer('order-100001', OrderStatus.preparing)]);
        expect(rings, 0);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('seen as awaiting, expired, renewed, paid: no chime', (
        tester,
      ) async {
        await start(tester, [
          transfer('order-100001', OrderStatus.awaiting_payment, due: soon),
        ]);
        await arrive(tester, [
          transfer(
            'order-100001',
            OrderStatus.cancelled,
            due: now.subtract(const Duration(minutes: 1)),
          ),
        ]);
        await arrive(tester, [
          transfer('order-100001', OrderStatus.awaiting_payment, due: soon),
        ]);
        await arrive(tester, [transfer('order-100001', OrderStatus.preparing)]);
        expect(rings, 0);
        await tester.pumpWidget(const SizedBox());
      });
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('payment lines fit at 360 px (text x$scale)', (tester) async {
        await pumpOrders(
          tester,
          [
            transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
            transfer(
              'order-482914',
              OrderStatus.cancelled,
              due: now.subtract(const Duration(minutes: 1)),
            ),
          ],
          width: 360,
          textScale: scale,
          now: () => now,
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('DH482913'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('staff payment buttons', () {
    final now = DateTime.utc(2026, 11, 19, 10);
    final soon = now.add(const Duration(minutes: 10));
    final longAgo = now.subtract(const Duration(days: 3));
    final item = OrderItem(name: 'Trà đá', quantity: 1, price: 4000);
    const creds = StaffCredentials(
      id: 'test-staff',
      password: 'test-password-1234',
    );

    http.Response json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    Order transfer(String id, OrderStatus status, {DateTime? due}) => Order(
      id: id,
      customerName: 'An',
      items: [item],
      status: status,
      placedAt: DateTime(2026, 11, 19),
      paymentMethod: PaymentMethod.bank_transfer,
      paymentDueAt: due,
    );

    Order cash(String id, OrderStatus status) => Order(
      id: id,
      customerName: 'An',
      items: [item],
      status: status,
      placedAt: DateTime(2026, 11, 19),
    );

    Finder confirmButton() =>
        find.widgetWithText(OutlinedButton, 'Đã nhận chuyển khoản');
    Finder switchButton() =>
        find.widgetWithText(OutlinedButton, 'Chuyển sang tiền mặt');
    Finder idField() => find.widgetWithText(TextField, 'Mã nhân viên');
    Finder passwordField() =>
        find.widgetWithText(TextField, 'Mật khẩu nhân viên');
    Finder confirmDialogButton() =>
        find.widgetWithText(FilledButton, 'Xác nhận');

    late List<http.Request> posts;
    late List<http.Request> gets;
    late Future<http.Response> Function(http.Request) onPost;
    late Future<http.Response> Function(http.Request) onGet;

    setUp(() {
      StaffCredentialsHolder.instance.clear();
      posts = [];
      gets = [];
      onPost = (_) async => http.Response('boom', 500);
      onGet = (_) async => json([]);
    });
    tearDown(StaffCredentialsHolder.instance.clear);

    Future<void> start(
      WidgetTester tester,
      List<Order> orders, {
      void Function()? chime,
    }) async {
      OrderRepository.instance.setApiForTest(
        OrderApiClient(
          client: MockClient((request) async {
            if (request.method == 'GET') {
              gets.add(request);
              return onGet(request);
            }
            posts.add(request);
            return onPost(request);
          }),
        ),
      );
      await pumpOrders(tester, orders, now: () => now, chime: chime ?? () {});
    }

    testWidgets('live transfer order: both buttons', (tester) async {
      await start(tester, [
        transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
      ]);
      expect(confirmButton(), findsOneWidget);
      expect(switchButton(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'expired transfer order: only switch-to-cash, even days later',
      (tester) async {
        await start(tester, [
          transfer('order-482913', OrderStatus.cancelled, due: longAgo),
        ]);
        expect(confirmButton(), findsNothing);
        expect(switchButton(), findsOneWidget);
        expect(find.text('Hết hạn thanh toán'), findsOneWidget);
      },
    );

    testWidgets('never for cash, preparing, ready, delivered, or a '
        'purposely cancelled order', (tester) async {
      await start(tester, [
        cash('order-100001', OrderStatus.preparing),
        cash('order-100002', OrderStatus.ready),
        cash('order-100003', OrderStatus.delivered),
        cash('order-100004', OrderStatus.cancelled),
        transfer('order-100005', OrderStatus.cancelled), // no deadline
      ]);
      expect(confirmButton(), findsNothing);
      expect(switchButton(), findsNothing);
    });

    testWidgets('renewal: expired shows both again; cash shows none', (
      tester,
    ) async {
      await start(tester, [
        transfer('order-482913', OrderStatus.cancelled, due: longAgo),
      ]);
      expect(switchButton(), findsOneWidget);
      expect(confirmButton(), findsNothing);

      OrderRepository.instance.setOrdersForTest([
        transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
      ]);
      await tester.pump();
      expect(confirmButton(), findsOneWidget);
      expect(switchButton(), findsOneWidget);

      OrderRepository.instance.setOrdersForTest([
        Order(
          id: 'order-482913',
          customerName: 'An',
          items: [item],
          status: OrderStatus.preparing,
          placedAt: DateTime(2026, 11, 19),
        ),
      ]);
      await tester.pump();
      expect(confirmButton(), findsNothing);
      expect(switchButton(), findsNothing);
    });

    testWidgets('confirm with remembered credentials: one request, no dialog', (
      tester,
    ) async {
      StaffCredentialsHolder.instance.value = creds;
      onPost = (_) async =>
          json(transfer('order-482913', OrderStatus.preparing).toJson());
      await start(tester, [
        transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
      ]);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(posts, hasLength(1));
      expect(posts.single.url.path, '/api/orders/order-482913/confirm-payment');
      expect(posts.single.headers['X-Staff-Id'], creds.id);
      expect(posts.single.headers['X-Staff-Password'], creds.password);
      expect(find.text('Chuyển khoản'), findsOneWidget);
      expect(confirmButton(), findsNothing);
      expect(switchButton(), findsNothing);
    });

    testWidgets('a second tap while the first request is in flight is '
        'ignored: exactly one request', (tester) async {
      StaffCredentialsHolder.instance.value = creds;
      final hold = Completer<http.Response>();
      onPost = (_) => hold.future;
      await start(tester, [
        transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
      ]);

      await tester.tap(confirmButton());
      await tester.pump();
      // The button is disabled while busy, so this reaches no handler.
      await tester.tap(confirmButton(), warnIfMissed: false);
      await tester.tap(switchButton(), warnIfMissed: false);
      await tester.pump();
      expect(posts, hasLength(1));

      hold.complete(
        json(transfer('order-482913', OrderStatus.preparing).toJson()),
      );
      await tester.pumpAndSettle();
      expect(posts, hasLength(1));
    });

    testWidgets('staff switch to cash with remembered credentials, also on an '
        'expired order', (tester) async {
      StaffCredentialsHolder.instance.value = creds;
      onPost = (_) async => json(
        Order(
          id: 'order-482913',
          customerName: 'An',
          items: [item],
          status: OrderStatus.preparing,
          placedAt: DateTime(2026, 11, 19),
        ).toJson(),
      );
      await start(tester, [
        transfer('order-482913', OrderStatus.cancelled, due: longAgo),
      ]);

      await tester.tap(switchButton());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(posts, hasLength(1));
      expect(
        posts.single.url.path,
        '/api/orders/order-482913/staff-switch-to-cash',
      );
      expect(find.text('Tiền mặt'), findsOneWidget);
      expect(find.text('Hết hạn thanh toán'), findsNothing);
    });

    testWidgets(
      'without credentials: Cancel sends nothing; typing both sends once '
      'and remembers them',
      (tester) async {
        onPost = (_) async =>
            json(transfer('order-482913', OrderStatus.preparing).toJson());
        await start(tester, [
          transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
        ]);

        await tester.tap(confirmButton());
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(posts, isEmpty);

        await tester.tap(confirmButton());
        await tester.pumpAndSettle();
        await tester.enterText(idField(), creds.id);
        await tester.enterText(passwordField(), creds.password);
        await tester.pump();
        await tester.tap(confirmDialogButton());
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(posts, hasLength(1));
        expect(StaffCredentialsHolder.instance.value?.id, creds.id);
        expect(StaffCredentialsHolder.instance.value?.password, creds.password);
      },
    );

    testWidgets('401 clears the remembered credentials and asks again', (
      tester,
    ) async {
      StaffCredentialsHolder.instance.value = const StaffCredentials(
        id: 'old-staff',
        password: 'old-password-123',
      );
      var attempt = 0;
      onPost = (request) async {
        attempt++;
        if (attempt == 1) return http.Response('x', 401);
        return json(transfer('order-482913', OrderStatus.preparing).toJson());
      };
      await start(tester, [
        transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
      ]);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(StaffCredentialsHolder.instance.value, isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Sai mã nhân viên hoặc mật khẩu'), findsOneWidget);
      // The holder was cleared, so the new dialog starts empty.
      expect(tester.widget<TextField>(idField()).controller!.text, isEmpty);

      await tester.enterText(idField(), creds.id);
      await tester.enterText(passwordField(), creds.password);
      await tester.pump();
      await tester.tap(confirmDialogButton());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(posts, hasLength(2));
      expect(posts[0].headers['X-Staff-Id'], 'old-staff');
      expect(posts[1].headers['X-Staff-Id'], creds.id);
      expect(StaffCredentialsHolder.instance.value?.id, creds.id);
    });

    for (final (status, message) in [
      (403, 'Chức năng đang tắt trên máy chủ'),
      (429, 'Thử lại sau.'),
      (500, 'Không thể cập nhật. Thử lại.'),
    ]) {
      testWidgets('HTTP $status shows "$message"; credentials kept', (
        tester,
      ) async {
        StaffCredentialsHolder.instance.value = creds;
        onPost = (_) async => http.Response('x', status);
        await start(tester, [
          transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
        ]);

        await tester.tap(confirmButton());
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(StaffCredentialsHolder.instance.value, creds);
        expect(posts, hasLength(1));
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('a network error shows the generic failure text', (
      tester,
    ) async {
      StaffCredentialsHolder.instance.value = creds;
      onPost = (_) => throw http.ClientException('boom');
      await start(tester, [
        transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
      ]);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.text('Không thể cập nhật. Thử lại.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      '409: re-reads the repository first, so a chime for real new work '
      '(e.g. staff paid it on another device) still rings, but this '
      'tap\'s own "Đơn này đã được xử lý" is the last thing shown',
      (tester) async {
        var rings = 0;
        StaffCredentialsHolder.instance.value = creds;
        onPost = (_) async => http.Response('x', 409);
        // The id was seeded as awaiting (unrung) at mount; coming back
        // `preparing` is exactly the case that also rings the one-time
        // "new work" chime (restaurant-orders-show-payment-method). Both
        // must happen without one silently losing the other.
        onGet = (_) async =>
            json([transfer('order-482913', OrderStatus.preparing).toJson()]);
        await start(tester, [
          transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
        ], chime: () => rings++);

        await tester.tap(confirmButton());
        await tester.pumpAndSettle();

        expect(rings, 1);
        expect(gets, hasLength(1));
        expect(gets.single.url.path, '/api/orders');
        // The re-read shows it has actually moved on.
        expect(confirmButton(), findsNothing);
        expect(switchButton(), findsNothing);
        // The tap's own answer is what's left on screen, not overwritten
        // by the chime's "Đơn mới từ …" snackbar.
        expect(find.text('Đơn này đã được xử lý'), findsOneWidget);
        expect(find.textContaining('Đơn mới từ'), findsNothing);
      },
    );

    testWidgets('an accent in the staff ID is refused before sending', (
      tester,
    ) async {
      await start(tester, [
        transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
      ]);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      await tester.enterText(idField(), 'nhân-viên');
      await tester.enterText(passwordField(), creds.password);
      await tester.pump();
      await tester.tap(confirmDialogButton());
      await tester.pumpAndSettle();

      expect(
        find.text('Chỉ dùng chữ không dấu, số và ký hiệu thông thường'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a confirm via the button rings the one-time chime', (
      tester,
    ) async {
      var rings = 0;
      StaffCredentialsHolder.instance.value = creds;
      onPost = (_) async =>
          json(transfer('order-482913', OrderStatus.preparing).toJson());
      await start(tester, [
        transfer('order-482913', OrderStatus.awaiting_payment, due: soon),
      ], chime: () => rings++);
      expect(rings, 0);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(rings, 1);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('both buttons fit at 360 px (text x$scale)', (tester) async {
        await pumpOrders(
          tester,
          [transfer('order-482913', OrderStatus.awaiting_payment, due: soon)],
          width: 360,
          textScale: scale,
          now: () => now,
        );
        expect(tester.takeException(), isNull);
        expect(confirmButton(), findsOneWidget);
        expect(switchButton(), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
