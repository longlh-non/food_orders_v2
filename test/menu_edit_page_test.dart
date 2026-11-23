import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/restaurant/api/menu_admin_client.dart';
import 'package:food_orders/restaurant/pages/menu_edit_page.dart';
import 'package:food_orders/restaurant/pages/orders_page.dart';
import 'package:food_orders/restaurant/state/menu_admin_state.dart';
import 'package:food_orders/restaurant/state/staff_credentials.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/l10n_app.dart';

// Obviously fake test values.
const staffId = 'test-staff';
const password = 'test-password-1234';

Map<String, Object?> item(
  String id,
  String name, {
  num price = 4000,
  bool available = true,
}) => {
  'id': id,
  'name': name,
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

void main() {
  late List<http.Request> patches;
  late Future<http.Response> Function(http.Request) onGet;
  late Future<http.Response> Function(http.Request) onPatch;
  late MenuAdminState state;

  setUp(() {
    patches = [];
    onGet = (_) async =>
        json([item('a', 'Trà đá'), item('b', 'Cà phê', price: 25000)]);
    onPatch = (r) async {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return json(
        item(
          r.url.pathSegments.last,
          r.url.pathSegments.last == 'a' ? 'Trà đá' : 'Cà phê',
          price: (body['price'] as num?) ?? 4000,
          available: (body['available'] as bool?) ?? true,
        ),
      );
    };
    StaffCredentialsHolder.instance.clear();
    final mock = MockClient((r) {
      if (r.method == 'GET') return onGet(r);
      patches.add(r);
      return onPatch(r);
    });
    state = MenuAdminState(
      api: OrderApiClient(client: mock),
      admin: MenuAdminClient(client: mock),
    );
  });
  tearDown(() {
    StaffCredentialsHolder.instance.clear();
    state.dispose();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    double width = 800,
    double textScale = 1.0,
  }) async {
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
        home: MenuEditPage(state: state),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder fieldLabelled(String label) => find.widgetWithText(TextField, label);

  Future<void> logIn(WidgetTester tester) async {
    await tester.enterText(fieldLabelled('Mã nhân viên'), staffId);
    await tester.enterText(fieldLabelled('Mật khẩu nhân viên'), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    await tester.pumpAndSettle();
  }

  Finder switchOf(String name) => find.descendant(
    of: find.widgetWithText(ListTile, name),
    matching: find.byType(Switch),
  );

  Finder editOf(String name) => find.byTooltip('Sửa giá $name');

  testWidgets('renders items with prices and switches', (tester) async {
    await pumpPage(tester);
    expect(find.text('Trà đá'), findsOneWidget);
    expect(find.textContaining('4.000 VNĐ'), findsOneWidget);
    expect(find.textContaining('25.000 VNĐ'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(tester.widget<Switch>(switchOf('Trà đá')).value, isTrue);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    final gate = Completer<http.Response>();
    onGet = (_) => gate.future;
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(l10nApp(home: MenuEditPage(state: state)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete(json([item('a', 'Trà đá')]));
    await tester.pumpAndSettle();
    expect(find.text('Trà đá'), findsOneWidget);
  });

  testWidgets('error shows Retry, which reloads', (tester) async {
    onGet = (_) async => http.Response('x', 500);
    await pumpPage(tester);
    expect(find.text('Không tải được thực đơn.'), findsOneWidget);
    onGet = (_) async => json([item('a', 'Trà đá')]);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Trà đá'), findsOneWidget);
    expect(find.text('Không tải được thực đơn.'), findsNothing);
  });

  testWidgets('empty menu shows the empty message', (tester) async {
    onGet = (_) async => json([]);
    await pumpPage(tester);
    expect(find.text('Thực đơn đang trống.'), findsOneWidget);
  });

  testWidgets('the credentials dialog comes before the first save, obscured', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(switchOf('Trà đá'));
    await tester.pumpAndSettle();
    expect(patches, isEmpty);
    expect(find.text('Đăng nhập nhân viên'), findsOneWidget);
    expect(
      tester.widget<TextField>(fieldLabelled('Mật khẩu nhân viên')).obscureText,
      isTrue,
    );
    expect(
      tester.widget<TextField>(fieldLabelled('Mã nhân viên')).obscureText,
      isFalse,
    );
    await logIn(tester);
    expect(patches, hasLength(1));
    expect(jsonDecode(patches.single.body), {'available': false});
    expect(patches.single.headers['X-Staff-Id'], staffId);
    expect(tester.widget<Switch>(switchOf('Trà đá')).value, isFalse);
    expect(find.textContaining('Hết hàng'), findsOneWidget);
  });

  testWidgets('cancelling the credentials dialog saves nothing', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(switchOf('Trà đá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(patches, isEmpty);
    expect(tester.widget<Switch>(switchOf('Trà đá')).value, isTrue);
  });

  testWidgets('with credentials in memory the dialog is skipped', (
    tester,
  ) async {
    StaffCredentialsHolder.instance.value = const StaffCredentials(
      id: staffId,
      password: password,
    );
    await pumpPage(tester);
    await tester.tap(switchOf('Trà đá'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập nhân viên'), findsNothing);
    expect(patches, hasLength(1));
  });

  testWidgets('price dialog rejects bad input without calling the client', (
    tester,
  ) async {
    StaffCredentialsHolder.instance.value = const StaffCredentials(
      id: staffId,
      password: password,
    );
    await pumpPage(tester);
    await tester.tap(editOf('Trà đá'));
    await tester.pumpAndSettle();
    for (final bad in ['', 'abc', '-5', '1000001', '12.5']) {
      await tester.enterText(find.byType(TextField), bad);
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pump();
      expect(
        find.text('Nhập số nguyên từ 0 đến 1.000.000'),
        findsOneWidget,
        reason: bad,
      );
    }
    expect(patches, isEmpty);
    await tester.enterText(find.byType(TextField), '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(jsonDecode(patches.single.body), {'price': 5000});
    expect(find.text('5.000 VNĐ · Còn hàng'), findsOneWidget);
  });

  testWidgets('wrong credentials: asks again with the message', (tester) async {
    onPatch = (_) async => http.Response('x', 401);
    await pumpPage(tester);
    await tester.tap(switchOf('Trà đá'));
    await tester.pumpAndSettle();
    await logIn(tester);
    // Asked again, fields empty, the error shown in the dialog.
    expect(find.text('Đăng nhập nhân viên'), findsOneWidget);
    expect(find.text('Sai mã nhân viên hoặc mật khẩu'), findsOneWidget);
    expect(StaffCredentialsHolder.instance.value, isNull);
    expect(tester.widget<Switch>(switchOf('Trà đá')).value, isTrue);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Sai mã nhân viên hoặc mật khẩu'), findsNothing);
  });

  testWidgets('403 and 429 show their messages on the page', (tester) async {
    onPatch = (_) async => http.Response('x', 403);
    await pumpPage(tester);
    await tester.tap(switchOf('Trà đá'));
    await tester.pumpAndSettle();
    await logIn(tester);
    expect(
      find.text('Chức năng sửa thực đơn đang tắt trên máy chủ'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(switchOf('Trà đá')).value, isTrue);

    onPatch = (_) async =>
        http.Response('x', 429, headers: {'retry-after': '30'});
    await tester.tap(switchOf('Trà đá'));
    await tester.pumpAndSettle();
    expect(
      find.text('Thử sai quá nhiều lần. Thử lại sau 30 giây.'),
      findsOneWidget,
    );
  });

  testWidgets('the row is disabled while saving', (tester) async {
    final gate = Completer<http.Response>();
    onPatch = (_) => gate.future;
    StaffCredentialsHolder.instance.value = const StaffCredentials(
      id: staffId,
      password: password,
    );
    await pumpPage(tester);
    await tester.tap(switchOf('Trà đá'));
    await tester.pump();
    expect(tester.widget<Switch>(switchOf('Trà đá')).onChanged, isNull);
    expect(editOf('Trà đá'), findsNothing);
    expect(tester.widget<Switch>(switchOf('Cà phê')).onChanged, isNotNull);
    gate.complete(json(item('a', 'Trà đá', available: false)));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(switchOf('Trà đá')).onChanged, isNotNull);
  });

  testWidgets('neither the ID nor the password appears in the widget tree', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(switchOf('Trà đá'));
    await tester.pumpAndSettle();
    await logIn(tester);
    // Also after a failure that shows an error.
    onPatch = (_) async => http.Response('$staffId $password', 401);
    await tester.tap(switchOf('Trà đá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    for (final secret in [staffId, password]) {
      expect(find.textContaining(secret), findsNothing);
      expect(
        find.byWidgetPredicate((w) {
          if (w is Text) return (w.data ?? '').contains(secret);
          if (w is EditableText) return w.controller.text.contains(secret);
          if (w is Tooltip) return (w.message ?? '').contains(secret);
          return false;
        }),
        findsNothing,
      );
    }
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('fits at 360 px (text x$scale), with an error and dialogs', (
      tester,
    ) async {
      onPatch = (_) async => http.Response('x', 403);
      await pumpPage(tester, width: 360, textScale: scale);
      expect(tester.takeException(), isNull);
      await tester.tap(switchOf('Trà đá'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await logIn(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text('Chức năng sửa thực đơn đang tắt trên máy chủ'),
        findsOneWidget,
      );
      await tester.tap(editOf('Trà đá'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'x');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  group('OrdersPage', () {
    setUp(() => OrderRepository.instance.setOrdersForTest(const []));
    tearDown(() => OrderRepository.instance.setOrdersForTest(const []));

    testWidgets('the menu button opens the editing page', (tester) async {
      final mock = MockClient((_) async => json([item('a', 'Trà đá')]));
      OrderRepository.instance.setApiForTest(OrderApiClient(client: mock));
      addTearDown(
        () => OrderRepository.instance.setApiForTest(OrderApiClient()),
      );
      await tester.pumpWidget(l10nApp(home: OrdersPage(chime: () {})));
      expect(find.byTooltip('Chỉnh sửa thực đơn'), findsOneWidget);
      // The export and bell buttons are still there.
      expect(find.byTooltip('Xuất đơn hàng theo tháng'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      await tester.tap(find.byTooltip('Chỉnh sửa thực đơn'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(MenuEditPage), findsOneWidget);
      expect(find.text('Chỉnh sửa thực đơn'), findsWidgets);
      // The page makes its own client; under flutter test it answers 400, so
      // the load fails and the page settles on its error state.
      await tester.pumpAndSettle();
      await goBack(tester);
      await tester.pumpAndSettle();
      expect(find.byType(MenuEditPage), findsNothing);
    });
  });
}
