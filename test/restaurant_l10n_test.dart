import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/restaurant/api/export_client.dart';
import 'package:food_orders/restaurant/api/menu_admin_client.dart';
import 'package:food_orders/restaurant/main.dart';
import 'package:food_orders/restaurant/pages/export_month_dialog.dart';
import 'package:food_orders/restaurant/pages/menu_edit_page.dart';
import 'package:food_orders/restaurant/pages/orders_page.dart';
import 'package:food_orders/restaurant/state/menu_admin_state.dart';
import 'package:food_orders/restaurant/state/staff_credentials.dart';
import 'package:food_orders/restaurant/widgets/staff_login_dialog.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:food_orders/shared/l10n.dart';
import 'package:food_orders/shared/localized_labels.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:food_orders/shared/widgets/language_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/l10n_app.dart';

final _now = DateTime.utc(2026, 11, 12, 9);

Order _order(
  OrderStatus status, {
  String id = 'order-0001',
  PaymentMethod method = PaymentMethod.cash,
  DateTime? due,
}) => Order(
  id: id,
  customerName: 'An',
  items: [OrderItem(name: 'Trà đá', quantity: 1, price: 4000)],
  status: status,
  placedAt: DateTime(2026, 11, 12, 8, 30),
  paymentMethod: method,
  paymentDueAt: due,
);

void main() {
  setUp(() {
    OrderRepository.instance
      ..setApiForTest(OrderApiClient())
      ..setOrdersForTest(const []);
    StaffCredentialsHolder.instance.clear();
    LocaleController.instance.setLocale(LocaleController.defaultLocale);
  });
  tearDown(() {
    OrderRepository.instance.setOrdersForTest(const []);
    StaffCredentialsHolder.instance.clear();
    LocaleController.instance.setLocale(LocaleController.defaultLocale);
  });

  Future<void> pumpOrders(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      l10nApp(
        locale: locale,
        home: OrdersPage(now: () => _now, chime: () {}),
      ),
    );
  }

  group('orders page text follows the language', () {
    final cases = <(Locale, String, String, String, String)>[
      // locale, title, status chip, action button, total
      (
        const Locale('vi'),
        'Danh sách đơn hàng',
        'Đang chuẩn bị',
        'Đánh dấu sẵn sàng',
        'Tổng: 4.000 VNĐ',
      ),
      (
        const Locale('en'),
        'Incoming Orders',
        'Preparing',
        'Mark ready',
        'Total: 4.000 VNĐ',
      ),
      // Non-Latin script: catches missing glyph or encoding problems.
      (const Locale('ja'), '受信した注文', '準備中', '準備完了にする', '合計：4.000 VNĐ'),
      (const Locale('ko'), '들어온 주문', '준비 중', '준비 완료로 표시', '합계: 4.000 VNĐ'),
    ];
    for (final (locale, title, chip, action, total) in cases) {
      testWidgets('$locale', (tester) async {
        OrderRepository.instance.setOrdersForTest([
          _order(OrderStatus.preparing),
        ]);
        await pumpOrders(tester, locale);
        expect(find.text(title), findsOneWidget);
        expect(find.widgetWithText(Chip, chip), findsOneWidget);
        expect(find.widgetWithText(FilledButton, action), findsOneWidget);
        expect(find.text(total), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('unpaid and expired cards, payment buttons: vi then en', (
    tester,
  ) async {
    OrderRepository.instance.setOrdersForTest([
      _order(
        OrderStatus.awaiting_payment,
        id: 'a-111111',
        method: PaymentMethod.bank_transfer,
        due: _now.add(const Duration(minutes: 3)),
      ),
      _order(
        OrderStatus.cancelled,
        id: 'a-222222',
        method: PaymentMethod.bank_transfer,
        due: _now.subtract(const Duration(minutes: 3)),
      ),
    ]);
    await pumpOrders(tester, const Locale('vi'));
    expect(find.text('Chưa thanh toán'), findsOneWidget);
    expect(find.text('Nội dung chuyển khoản: DH111111'), findsOneWidget);
    expect(find.text('Hết hạn thanh toán'), findsOneWidget);
    expect(find.text('Đã nhận chuyển khoản'), findsOneWidget);
    expect(find.text('Chuyển sang tiền mặt'), findsNWidgets(2));
    expect(find.text('Chuyển khoản'), findsNWidgets(2));

    await pumpOrders(tester, const Locale('en'));
    await tester.pump();
    expect(find.text('Not paid yet'), findsOneWidget);
    expect(find.text('Payment expired'), findsOneWidget);
    expect(find.text('Switch to cash'), findsNWidgets(2));
    expect(find.text('Chưa thanh toán'), findsNothing);
  });

  testWidgets('the empty message follows the language', (tester) async {
    await pumpOrders(tester, const Locale('vi'));
    expect(find.text('Chưa có đơn hàng nào. Đang chờ khách…'), findsOneWidget);
    await pumpOrders(tester, const Locale('en'));
    await tester.pump();
    expect(find.text('Chưa có đơn hàng nào. Đang chờ khách…'), findsNothing);
    expect(
      find.text(
        AppLocalizations.of(tester.element(find.byType(OrdersPage)))!
            .ordersEmpty,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the app bar has the language picker, which switches the text', (
    tester,
  ) async {
    await tester.pumpWidget(const RestaurantApp());
    final bar = find.byType(AppBar);
    expect(
      find.descendant(of: bar, matching: find.byType(LanguagePicker)),
      findsOneWidget,
    );
    expect(find.text('Danh sách đơn hàng'), findsOneWidget);

    await tester.tap(find.byType(LanguagePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Incoming Orders'), findsOneWidget);
    expect(find.text('Danh sách đơn hàng'), findsNothing);
    expect(
      tester.widget<Title>(find.byType(Title)).title,
      'Food Orders — Restaurant',
    );
  });

  testWidgets('the restaurant app renders in Vietnamese, then English', (
    tester,
  ) async {
    await tester.pumpWidget(const RestaurantApp());
    expect(find.text('Danh sách đơn hàng'), findsOneWidget);
    expect(
      tester.widget<Title>(find.byType(Title)).title,
      'Đặt Món — Nhà hàng',
    );
    LocaleController.instance.setLocale(const Locale('en'));
    await tester.pump();
    expect(find.text('Incoming Orders'), findsOneWidget);
  });

  group('export dialog', () {
    Future<void> open(WidgetTester tester, Locale locale) async {
      await tester.pumpWidget(
        l10nApp(
          locale: locale,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showExportMonthDialog(
                  context,
                  client: _noNetworkExportClient(),
                  saveFile: (_, _, _) {},
                  now: DateTime(2026, 11, 12),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('title and an error switch language while open', (
      tester,
    ) async {
      await open(tester, const Locale('vi'));
      expect(find.text('Xuất đơn hàng theo tháng'), findsOneWidget);
      // An accent in the ID is refused before anything is sent.
      await tester.enterText(find.byType(TextField).at(0), 'Nhân');
      await tester.enterText(find.byType(TextField).at(1), 'password-12345');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Tải xuống'));
      await tester.pump();
      expect(
        find.text('Chỉ dùng chữ không dấu, số và ký hiệu thông thường'),
        findsOneWidget,
      );

      // Same dialog, new language.
      await tester.pumpWidget(
        l10nApp(locale: const Locale('en'), home: const SizedBox()),
      );
      await tester.pump();
      expect(find.text('Export month'), findsOneWidget);
      expect(
        find.text('Use plain letters, digits and symbols, no accents'),
        findsOneWidget,
      );
      expect(find.text('Xuất đơn hàng theo tháng'), findsNothing);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('title in Japanese', (tester) async {
      await open(tester, const Locale('ja'));
      expect(find.text('月別の注文をエクスポート'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('every status and payment method has text in every language', () {
    expect(AppLocalizations.supportedLocales, hasLength(10));
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final s in OrderStatus.values) {
        expect(s.localized(l10n).trim(), isNotEmpty, reason: '$locale $s');
      }
      for (final m in PaymentMethod.values) {
        expect(m.localized(l10n).trim(), isNotEmpty, reason: '$locale $m');
      }
    }
  });

  test('Vietnamese status names are the ones the owner accepted', () {
    final vi = lookupAppLocalizations(const Locale('vi'));
    expect(OrderStatus.awaiting_payment.localized(vi), 'Chờ thanh toán');
    expect(OrderStatus.preparing.localized(vi), 'Đang chuẩn bị');
    expect(OrderStatus.ready.localized(vi), 'Sẵn sàng lấy hàng');
    expect(OrderStatus.delivered.localized(vi), 'Đã giao');
    expect(OrderStatus.cancelled.localized(vi), 'Đã hủy');
    expect(PaymentMethod.cash.localized(vi), 'Tiền mặt');
    expect(PaymentMethod.bank_transfer.localized(vi), 'Chuyển khoản');
  });

  group('menu edit page', () {
    testWidgets('texts and a save error follow the language', (tester) async {
      final mock = MockClient((r) async {
        if (r.method == 'GET') {
          return http.Response(
            '[{"id":"a","name":"Trà đá","description":"","price":4000,'
            '"category":"drink","allowToppings":false,"image":null,'
            '"available":false}]',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('x', 403);
      });
      final state = MenuAdminState(
        api: OrderApiClient(client: mock),
        admin: MenuAdminClient(client: mock),
      );
      addTearDown(state.dispose);
      StaffCredentialsHolder.instance.value = const StaffCredentials(
        id: 'test-staff',
        password: 'test-password-1234',
      );
      await tester.pumpWidget(l10nApp(home: MenuEditPage(state: state)));
      await tester.pumpAndSettle();
      expect(find.text('Chỉnh sửa thực đơn'), findsOneWidget);
      expect(find.text('4.000 VNĐ · Hết hàng'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(state.saveError, MenuSaveError.editingDisabled);
      expect(
        find.text('Chức năng sửa thực đơn đang tắt trên máy chủ'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        l10nApp(
          locale: const Locale('en'),
          home: MenuEditPage(state: state),
        ),
      );
      await tester.pump();
      expect(find.text('Edit menu'), findsOneWidget);
      expect(
        find.text(
          AppLocalizations.of(tester.element(find.byType(MenuEditPage)))!
              .menuEditingDisabled,
        ),
        findsOneWidget,
      );
      expect(
        find.text('Chức năng sửa thực đơn đang tắt trên máy chủ'),
        findsNothing,
      );
    });
  });

  // The longest languages must still fit a 360 px phone (text x1.0 and the
  // larger x1.5). An overflow would throw and show up in takeException.
  for (final code in ['de', 'ru', 'lo']) {
    for (final scale in [1.0, 1.5]) {
      group('fits at 360 px in $code (text x$scale)', () {
        final locale = Locale(code);

        Future<void> pump(WidgetTester tester, Widget home) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            l10nApp(
              locale: locale,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: home,
            ),
          );
          await tester.pumpAndSettle();
        }

        testWidgets('orders page: unpaid, expired and preparing cards', (
          tester,
        ) async {
          OrderRepository.instance.setOrdersForTest([
            _order(
              OrderStatus.awaiting_payment,
              id: 'a-111111',
              method: PaymentMethod.bank_transfer,
              due: _now.add(const Duration(minutes: 3)),
            ),
            _order(
              OrderStatus.cancelled,
              id: 'a-222222',
              method: PaymentMethod.bank_transfer,
              due: _now.subtract(const Duration(minutes: 3)),
            ),
            _order(OrderStatus.preparing, id: 'a-333333'),
            _order(OrderStatus.ready, id: 'a-444444'),
          ]);
          await pump(tester, OrdersPage(now: () => _now, chime: () {}));
          expect(tester.takeException(), isNull);
          await tester.drag(find.byType(ListView), const Offset(0, -2000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('orders page: empty state', (tester) async {
          await pump(tester, OrdersPage(now: () => _now, chime: () {}));
          expect(tester.takeException(), isNull);
        });

        testWidgets('export dialog with an error', (tester) async {
          await pump(
            tester,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showExportMonthDialog(
                  context,
                  client: _noNetworkExportClient(),
                  saveFile: (_, _, _) {},
                  now: DateTime(2026, 11, 12),
                ),
                child: const Text('open'),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).at(0), 'Nhân');
          await tester.enterText(
            find.byType(TextField).at(1),
            'password-12345',
          );
          await tester.pump();
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('staff login dialog with an error', (tester) async {
          await pump(
            tester,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showStaffLoginDialog(
                  context,
                  initialError: lookupAppLocalizations(locale)
                      .staffWrongCredentials,
                ),
                child: const Text('open'),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(
            find.text(lookupAppLocalizations(locale).staffLoginTitle),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('menu edit page: list, sold-out row, error banner', (
          tester,
        ) async {
          final mock = MockClient((r) async {
            if (r.method == 'GET') {
              return http.Response(
                '[{"id":"a","name":"Trà đá","description":"","price":4000,'
                '"category":"drink","allowToppings":false,"image":null,'
                '"available":false}]',
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return http.Response('x', 429, headers: {'retry-after': '42'});
          });
          final state = MenuAdminState(
            api: OrderApiClient(client: mock),
            admin: MenuAdminClient(client: mock),
          );
          addTearDown(state.dispose);
          StaffCredentialsHolder.instance.value = const StaffCredentials(
            id: 'test-staff',
            password: 'test-password-1234',
          );
          await pump(tester, MenuEditPage(state: state));
          await tester.tap(find.byType(Switch));
          await tester.pumpAndSettle();
          expect(state.saveError, MenuSaveError.tooManyTries);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byIcon(Icons.edit));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '9999999');
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      });
    }
  }
}

ExportClient _noNetworkExportClient() =>
    ExportClient(client: MockClient((_) async => http.Response('x', 500)));
