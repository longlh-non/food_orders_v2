import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/customer/api/payment_client.dart';
import 'package:food_orders/customer/pages/cart_page.dart';
import 'package:food_orders/customer/pages/payment_qr_page.dart';
import 'package:food_orders/customer/state/cart.dart';
import 'package:food_orders/customer/state/my_orders.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:food_orders/shared/models/menu_item.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const xoiThit = MenuItem(
  id: 'xoi-thit',
  name: 'Xôi thịt',
  description: '',
  price: 25000,
);

/// Echoes the posted order back, like the real backend's 200.
http.Response echo(http.Request request) => http.Response.bytes(
  utf8.encode(request.body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// A payment client whose `/payment-info` says transfer is [enabled]
/// (or fails with a 500 when [enabled] is null).
PaymentClient paymentClient({bool? enabled = true}) => PaymentClient(
  client: MockClient((_) async {
    if (enabled == null) return http.Response('boom', 500);
    return http.Response(
      jsonEncode(
        enabled
            ? {
                'transferEnabled': true,
                'bankName': 'ACB',
                'accountNumber': '123456',
                'accountName': 'QUAN XOI',
              }
            : {'transferEnabled': false},
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  void reset() {
    Cart.instance.clear();
    MyOrders.instance.clearForTest();
    OrderRepository.instance
      ..setApiForTest(OrderApiClient())
      ..setOrdersForTest(const []);
  }

  setUp(reset);
  tearDown(reset);

  /// Opens the cart from a home page (so it can pop), with the repository
  /// talking to [respond]. Returns how many requests were sent.
  Future<List<http.Request>> openCart(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) respond, {
    bool? transferEnabled = true,
  }) async {
    final sent = <http.Request>[];
    OrderRepository.instance.setApiForTest(
      OrderApiClient(
        client: MockClient((request) {
          sent.add(request);
          return respond(request);
        }),
      ),
    );
    Cart.instance.add(xoiThit);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CartPage(
                      paymentClient: paymentClient(enabled: transferEnabled),
                    ),
                  ),
                ),
                child: const Text('open cart'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open cart'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'An');
    return sent;
  }

  Finder placeButton() => find.byType(FilledButton);

  testWidgets('success: tracks the order, empties the cart, closes', (
    tester,
  ) async {
    final sent = await openCart(tester, (r) async => echo(r));

    await tester.tap(find.text('Place Order'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    final id = (jsonDecode(sent.single.body) as Map)['id'] as String;
    expect(MyOrders.instance.ids, contains(id));
    expect(Cart.instance.isEmpty, isTrue);
    expect(find.byType(CartPage), findsNothing);
    expect(find.text('Order placed, An!'), findsOneWidget);
    expect(OrderRepository.instance.orders.map((o) => o.id), [id]);
  });

  Map<String, dynamic> body(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  Future<void> chooseTransfer(WidgetTester tester) async {
    await tester.tap(find.text('Chuyển khoản'));
    await tester.pump();
  }

  testWidgets('default is Tiền mặt: posts cash + preparing, no paymentDueAt', (
    tester,
  ) async {
    final sent = await openCart(tester, (r) async => echo(r));
    expect(find.text('Tiền mặt'), findsOneWidget);

    await tester.tap(find.text('Place Order'));
    await tester.pumpAndSettle();

    final posted = body(sent.single);
    expect(posted['paymentMethod'], 'cash');
    expect(posted['status'], 'preparing');
    expect(posted.containsKey('paymentDueAt'), isFalse);
    expect(find.text('Order placed, An!'), findsOneWidget);
  });

  testWidgets(
    'Chuyển khoản: posts bank_transfer + awaiting_payment, opens QR',
    (tester) async {
      // Like the real backend: the stored copy carries the payment deadline.
      final sent = await openCart(tester, (r) async {
        final stored = body(r)
          ..['paymentDueAt'] = DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String();
        return http.Response.bytes(
          utf8.encode(jsonEncode(stored)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await chooseTransfer(tester);

      await tester.tap(find.text('Place Order'));
      // Not pumpAndSettle: the QR page's countdown timer keeps frames coming.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final posted = body(sent.single);
      expect(posted['paymentMethod'], 'bank_transfer');
      expect(posted['status'], 'awaiting_payment');
      expect(posted.containsKey('paymentDueAt'), isFalse);
      final id = posted['id'] as String;
      expect(MyOrders.instance.ids, contains(id));
      expect(Cart.instance.isEmpty, isTrue);
      expect(find.byType(CartPage), findsNothing);
      expect(
        tester.widget<PaymentQrPage>(find.byType(PaymentQrPage)).orderId,
        id,
      );
      expect(
        OrderRepository.instance.orders.single.status,
        OrderStatus.awaiting_payment,
      );
    },
  );

  for (final (label, enabled) in <(String, bool?)>[
    ('transferEnabled false', false),
    ('info call failed', null),
  ]) {
    testWidgets('$label: transfer disabled with the reason, cash works', (
      tester,
    ) async {
      final sent = await openCart(
        tester,
        (r) async => echo(r),
        transferEnabled: enabled,
      );

      expect(find.text('Chuyển khoản chưa được bật'), findsOneWidget);
      await tester.tap(find.text('Chuyển khoản'), warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(body(sent.single)['paymentMethod'], 'cash');
      expect(body(sent.single)['status'], 'preparing');
      expect(find.byType(PaymentQrPage), findsNothing);
    });
  }

  testWidgets('503 on a transfer order keeps the cart and says so', (
    tester,
  ) async {
    final sent = await openCart(
      tester,
      (_) async => http.Response('Bank transfer is not set up', 503),
    );
    await chooseTransfer(tester);

    await tester.tap(find.text('Place Order'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(find.byType(CartPage), findsOneWidget);
    expect(find.byType(PaymentQrPage), findsNothing);
    expect(find.text("Couldn't place your order. Try again."), findsOneWidget);
    expect(Cart.instance.isEmpty, isFalse);
    expect(MyOrders.instance.ids, isEmpty);
  });

  testWidgets('a typed name survives scrolling the field off-screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (var i = 0; i < 40; i++) {
      Cart.instance.add(
        MenuItem(id: 'i$i', name: 'Món $i', description: '', price: 1000),
      );
    }
    await tester.pumpWidget(
      MaterialApp(home: CartPage(paymentClient: paymentClient())),
    );
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byType(TextField),
      100,
      scrollable: list,
    );
    await tester.enterText(find.byType(TextField), 'Bình');
    // A focused field is kept alive by the list; drop focus so it is truly
    // disposed when it scrolls away.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(list, const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'scrolled away');

    await tester.scrollUntilVisible(
      find.byType(TextField),
      100,
      scrollable: list,
    );
    expect(find.widgetWithText(TextField, 'Bình'), findsOneWidget);
  });

  for (final (label, respond) in <(String, Future<http.Response> Function())>[
    ('400', () async => http.Response('items[0] has unknown fields', 400)),
    ('500', () async => http.Response('Internal Server Error', 500)),
    ('no answer', () async => throw http.ClientException('refused')),
  ]) {
    testWidgets('failure ($label): keeps cart and name, says so', (
      tester,
    ) async {
      final sent = await openCart(tester, (_) => respond());

      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(find.byType(CartPage), findsOneWidget);
      // Above the button, so it is on screen without scrolling.
      expect(
        find.text("Couldn't place your order. Try again."),
        findsOneWidget,
      );
      expect(find.text('Order placed, An!'), findsNothing);
      expect(Cart.instance.lines.values.single, 1);
      expect(find.widgetWithText(TextField, 'An'), findsOneWidget);
      expect(MyOrders.instance.ids, isEmpty);
      expect(OrderRepository.instance.orders, isEmpty);
      expect(tester.widget<FilledButton>(placeButton()).onPressed, isNotNull);
      // The server's text is never shown.
      expect(find.textContaining('unknown fields'), findsNothing);
      expect(find.textContaining('Internal Server Error'), findsNothing);
    });
  }

  testWidgets('while sending: button disabled with a spinner, no 2nd send', (
    tester,
  ) async {
    final answer = Completer<http.Response>();
    final sent = await openCart(tester, (_) => answer.future);

    await tester.tap(find.text('Place Order'));
    await tester.pump();

    expect(tester.widget<FilledButton>(placeButton()).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Place Order'), findsNothing);
    await tester.tap(placeButton(), warnIfMissed: false);
    await tester.pump();
    expect(sent, hasLength(1));
    expect(Cart.instance.isEmpty, isFalse, reason: 'nothing cleared yet');

    answer.complete(http.Response('Internal Server Error', 500));
    await tester.pumpAndSettle();
    expect(find.text('Place Order'), findsOneWidget);
    expect(tester.widget<FilledButton>(placeButton()).onPressed, isNotNull);
  });

  testWidgets('a retry after a failure sends a new order and succeeds', (
    tester,
  ) async {
    var calls = 0;
    final sent = await openCart(tester, (r) async {
      calls++;
      return calls == 1 ? http.Response('bad', 400) : echo(r);
    });

    await tester.tap(find.text('Place Order'));
    await tester.pumpAndSettle();
    expect(find.byType(CartPage), findsOneWidget);

    await tester.tap(find.text('Place Order'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(2));
    String idOf(http.Request r) => (jsonDecode(r.body) as Map)['id'] as String;
    expect(idOf(sent[0]), isNot(idOf(sent[1])), reason: 'a new order per try');
    expect(find.byType(CartPage), findsNothing);
    expect(Cart.instance.isEmpty, isTrue);
    expect(MyOrders.instance.ids, hasLength(1));
  });

  testWidgets('shows unit prices and the total in VND', (tester) async {
    const xoi = MenuItem(
      id: 'xoi-thit',
      name: 'Xôi thịt',
      description: '',
      price: 25000,
    );
    const traDa = MenuItem(
      id: 'tra-da',
      name: 'Trà đá',
      description: '',
      price: 4000,
    );
    Cart.instance
      ..add(xoi)
      ..add(xoi)
      ..add(traDa);

    await tester.pumpWidget(
      MaterialApp(home: CartPage(paymentClient: paymentClient())),
    );

    expect(find.text('25.000 VNĐ each'), findsOneWidget);
    expect(find.text('4.000 VNĐ each'), findsOneWidget);
    expect(find.text('Total: 54.000 VNĐ'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('leaving mid-request: the accepted order is still tracked', (
    tester,
  ) async {
    final answer = Completer<http.Response>();
    late http.Request request;
    await openCart(tester, (r) {
      request = r;
      return answer.future;
    });

    await tester.tap(find.text('Place Order'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CartPage), findsNothing);

    answer.complete(echo(request));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(MyOrders.instance.ids, hasLength(1));
    expect(Cart.instance.isEmpty, isTrue);
  });

  for (final scale in [1.0, 1.3, 1.6, 2.0]) {
    testWidgets('failure text fits at 360 px (text x$scale)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      Cart.instance
        ..add(xoiThit)
        ..add(
          const MenuItem(id: 'a', name: 'Trà đá', description: '', price: 4000),
        )
        ..add(
          const MenuItem(
            id: 'b',
            name: 'Cà phê',
            description: '',
            price: 20000,
          ),
        );
      OrderRepository.instance.setApiForTest(
        OrderApiClient(
          client: MockClient((_) async => http.Response('bad', 400)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: CartPage(paymentClient: paymentClient()),
        ),
      );
      // At large text the form is below the fold and not built yet: scroll
      // to each widget before using it.
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byType(TextField),
        100,
        scrollable: list,
      );
      await tester.enterText(find.byType(TextField), 'An');
      await tester.scrollUntilVisible(placeButton(), 100, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(placeButton());
      await tester.pumpAndSettle();
      // No scrolling: the failure line is on screen right after the tap.
      final failure = tester.getRect(
        find.text("Couldn't place your order. Try again."),
      );
      expect(failure.top, greaterThanOrEqualTo(0));
      expect(failure.bottom, lessThanOrEqualTo(800));

      expect(tester.takeException(), isNull);
      expect(
        find.text("Couldn't place your order. Try again."),
        findsOneWidget,
      );
    });
  }

  for (final (label, enabled, pickTransfer) in <(String, bool, bool)>[
    ('transfer disabled, reason shown', false, false),
    ('Chuyển khoản selected', true, true),
  ]) {
    testWidgets('$label fits at 360 px (text x2.0)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      Cart.instance.add(xoiThit);
      OrderRepository.instance.setApiForTest(
        OrderApiClient(
          client: MockClient((_) async => http.Response('bad', 400)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: CartPage(paymentClient: paymentClient(enabled: enabled)),
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).first;
      if (!enabled) {
        await tester.scrollUntilVisible(
          find.text('Chuyển khoản chưa được bật'),
          100,
          scrollable: list,
        );
      }
      if (pickTransfer) {
        await tester.scrollUntilVisible(
          find.text('Chuyển khoản'),
          100,
          scrollable: list,
        );
        await tester.tap(find.text('Chuyển khoản'));
        await tester.pump();
      }
      await tester.scrollUntilVisible(
        find.byType(TextField),
        100,
        scrollable: list,
      );
      await tester.enterText(find.byType(TextField), 'An');
      await tester.scrollUntilVisible(placeButton(), 100, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(placeButton());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final failure = tester.getRect(
        find.text("Couldn't place your order. Try again."),
      );
      expect(failure.top, greaterThanOrEqualTo(0));
      expect(failure.bottom, lessThanOrEqualTo(800));
    });
  }
}
