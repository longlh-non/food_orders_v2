import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/restaurant/api/menu_admin_client.dart';
import 'package:food_orders/restaurant/pages/menu_edit_page.dart';
import 'package:food_orders/restaurant/state/menu_admin_state.dart';
import 'package:food_orders/restaurant/state/staff_credentials.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/l10n.dart';
import 'package:food_orders/shared/models/menu_item.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/l10n_app.dart';

// Obviously fake test values.
const staffId = 'test-staff';
const password = 'test-password-1234';

Map<String, Object?> menuJson(
  String id,
  String name, {
  num price = 4000,
  String category = 'drink',
  bool allowToppings = false,
  String? image,
}) => {
  'id': id,
  'name': name,
  'description': '',
  'price': price,
  'category': category,
  'allowToppings': allowToppings,
  'image': image,
  'available': true,
};

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late List<http.Request> posts;
  late Future<http.Response> Function(http.Request) onGet;
  late Future<http.Response> Function(http.Request) onPost;
  late MenuAdminState state;

  // The server's reply to a good POST: the body, plus an id.
  http.Response created(http.Request r) {
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    return json(
      menuJson(
        'moi',
        body['name'] as String,
        price: body['price'] as num,
        category: body['category'] as String,
        allowToppings: body['allowToppings'] as bool,
        image: body['image'] as String?,
      ),
      201,
    );
  }

  setUp(() {
    posts = [];
    onGet = (_) async => json([menuJson('a', 'Trà đá')]);
    onPost = (r) async => created(r);
    StaffCredentialsHolder.instance.clear();
    final mock = MockClient((r) {
      if (r.method == 'GET') return onGet(r);
      posts.add(r);
      return onPost(r);
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

  void withCredentials() {
    StaffCredentialsHolder.instance.value = const StaffCredentials(
      id: staffId,
      password: password,
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    double width = 800,
    double height = 1200,
    double textScale = 1.0,
    Locale locale = const Locale('vi'),
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      l10nApp(
        locale: locale,
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

  final addButton = find.byIcon(Icons.add);
  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(addButton);
    await tester.pumpAndSettle();
  }

  Future<void> pickCategory(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<MenuCategory>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, [String label = 'Thêm']) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> fillValid(WidgetTester tester) async {
    await tester.enterText(field('Tên món'), '  Xôi gà  ');
    await tester.enterText(field('Mô tả (không bắt buộc)'), 'Nhiều xôi');
    await tester.enterText(field('Giá (VNĐ)'), '30000');
    await pickCategory(tester, 'Đồ ăn');
  }

  Future<void> logIn(WidgetTester tester) async {
    await tester.enterText(field('Mã nhân viên'), staffId);
    await tester.enterText(field('Mật khẩu nhân viên'), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    await tester.pumpAndSettle();
  }

  group('the add button', () {
    testWidgets('is hidden while loading and when the load failed', (
      tester,
    ) async {
      final gate = Completer<http.Response>();
      onGet = (_) => gate.future;
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(l10nApp(home: MenuEditPage(state: state)));
      await tester.pump();
      expect(addButton, findsNothing);
      gate.complete(http.Response('x', 500));
      await tester.pumpAndSettle();
      expect(find.text('Không tải được thực đơn.'), findsOneWidget);
      expect(addButton, findsNothing);
      // After a good retry it shows.
      onGet = (_) async => json([menuJson('a', 'Trà đá')]);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(addButton, findsOneWidget);
    });

    testWidgets('shows with an empty menu, with a tooltip', (tester) async {
      onGet = (_) async => json([]);
      await pumpPage(tester);
      expect(find.text('Thực đơn đang trống.'), findsOneWidget);
      expect(addButton, findsOneWidget);
      expect(find.byTooltip('Thêm món'), findsOneWidget);
    });

    testWidgets('shows with items and is disabled while adding', (
      tester,
    ) async {
      final gate = Completer<http.Response>();
      onPost = (_) => gate.future;
      withCredentials();
      await pumpPage(tester);
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
            .onPressed,
        isNotNull,
      );
      await openForm(tester);
      await fillValid(tester);
      await submit(tester);
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(button.onPressed, isNull);
      gate.complete(json(menuJson('moi', 'Xôi gà', category: 'food'), 201));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
            .onPressed,
        isNotNull,
      );
    });
  });

  group('credentials', () {
    testWidgets('are asked before the form', (tester) async {
      await pumpPage(tester);
      await openForm(tester);
      expect(find.text('Đăng nhập nhân viên'), findsOneWidget);
      expect(find.text('Thêm món mới'), findsNothing);
      await logIn(tester);
      expect(find.text('Thêm món mới'), findsOneWidget);
      expect(posts, isEmpty);
    });

    testWidgets('cancelling the login opens no form', (tester) async {
      await pumpPage(tester);
      await openForm(tester);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm món mới'), findsNothing);
      expect(posts, isEmpty);
    });

    testWidgets('a 401 asks again, then sends the same form', (tester) async {
      onPost = (_) async => http.Response('x', 401);
      await pumpPage(tester);
      await openForm(tester);
      await logIn(tester);
      await fillValid(tester);
      await submit(tester);
      expect(posts, hasLength(1));
      expect(find.text('Đăng nhập nhân viên'), findsOneWidget);
      expect(find.text('Sai mã nhân viên hoặc mật khẩu'), findsOneWidget);
      expect(StaffCredentialsHolder.instance.value, isNull);
      onPost = (r) async => created(r);
      await logIn(tester);
      expect(posts, hasLength(2));
      expect(jsonDecode(posts.last.body)['name'], 'Xôi gà');
      expect(find.text('Thêm món mới'), findsNothing);
      expect(find.text('Xôi gà'), findsOneWidget);
    });
  });

  group('the form', () {
    setUp(withCredentials);

    testWidgets('blocks an empty form and sends nothing', (tester) async {
      await pumpPage(tester);
      await openForm(tester);
      await submit(tester);
      expect(find.text('Nhập tên món, tối đa 100 ký tự'), findsOneWidget);
      expect(find.text('Nhập số nguyên từ 0 đến 1.000.000'), findsOneWidget);
      expect(find.text('Hãy chọn một mục'), findsOneWidget);
      expect(posts, isEmpty);
      expect(find.text('Thêm món mới'), findsOneWidget);
    });

    testWidgets('blocks a blank name, a bad price and a bad image name', (
      tester,
    ) async {
      await pumpPage(tester);
      await openForm(tester);
      await fillValid(tester);
      await tester.enterText(field('Tên món'), '   ');
      await tester.enterText(field('Giá (VNĐ)'), '1000001');
      await tester.enterText(
        field('Tên tệp ảnh (không bắt buộc)'),
        'IMG_1.JPG',
      );
      await submit(tester);
      expect(find.text('Nhập tên món, tối đa 100 ký tự'), findsOneWidget);
      expect(find.text('Nhập số nguyên từ 0 đến 1.000.000'), findsOneWidget);
      expect(posts, isEmpty);
      // Fix the name and price: the image is the one left.
      await tester.enterText(field('Tên món'), 'Xôi');
      await tester.enterText(field('Giá (VNĐ)'), '5000');
      await submit(tester);
      expect(find.textContaining('Tên tệp không hợp lệ'), findsOneWidget);
      expect(posts, isEmpty);
    });

    testWidgets('the price field takes digits only', (tester) async {
      await pumpPage(tester);
      await openForm(tester);
      await tester.enterText(field('Giá (VNĐ)'), '1a2-3.4');
      expect(
        tester.widget<TextField>(field('Giá (VNĐ)')).controller!.text,
        '1234',
      );
    });

    testWidgets('limits the name and an over-long name (emoji) is refused', (
      tester,
    ) async {
      await pumpPage(tester);
      await openForm(tester);
      await tester.enterText(field('Tên món'), 'a' * 150);
      expect(
        tester.widget<TextField>(field('Tên món')).controller!.text.length,
        100,
      );
      // 60 emoji are 60 characters but 120 UTF-16 units: over the limit.
      await tester.enterText(field('Tên món'), '😀' * 60);
      await tester.enterText(field('Giá (VNĐ)'), '1000');
      await pickCategory(tester, 'Đồ uống');
      await submit(tester);
      expect(find.text('Nhập tên món, tối đa 100 ký tự'), findsOneWidget);
      expect(posts, isEmpty);
    });

    testWidgets('the toppings switch is only for Food and resets', (
      tester,
    ) async {
      await pumpPage(tester);
      await openForm(tester);
      expect(find.byType(SwitchListTile), findsNothing);
      await pickCategory(tester, 'Đồ ăn');
      expect(find.byType(SwitchListTile), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await pickCategory(tester, 'Đồ uống');
      expect(find.byType(SwitchListTile), findsNothing);
      await pickCategory(tester, 'Đồ ăn');
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    });

    testWidgets('a valid form sends exactly what was typed', (tester) async {
      await pumpPage(tester);
      await openForm(tester);
      await fillValid(tester);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await submit(tester);
      expect(posts, hasLength(1));
      expect(jsonDecode(posts.single.body), {
        'name': 'Xôi gà',
        'description': 'Nhiều xôi',
        'price': 30000,
        'category': 'food',
        'allowToppings': true,
      });
      expect(find.text('Thêm món mới'), findsNothing);
      expect(find.text('Xôi gà'), findsOneWidget);
      expect(find.text('Đã thêm: Xôi gà'), findsOneWidget);
    });

    testWidgets('a picture name is sent trimmed', (tester) async {
      await pumpPage(tester);
      await openForm(tester);
      await fillValid(tester);
      await tester.enterText(
        field('Tên tệp ảnh (không bắt buộc)'),
        ' xoi-ga.webp ',
      );
      await submit(tester);
      expect(jsonDecode(posts.single.body)['image'], 'xoi-ga.webp');
    });

    testWidgets('cancel sends nothing', (tester) async {
      await pumpPage(tester);
      await openForm(tester);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm món mới'), findsNothing);
      expect(posts, isEmpty);
    });
  });

  group('server answers reopen the form with the typed values', () {
    setUp(withCredentials);
    final cases = <String, (http.Response, String)>{
      '409': (http.Response('x', 409), 'Đã có món trùng tên trong mục này'),
      '503': (
        http.Response('x', 503),
        'Thực đơn đã đầy, không thêm được món nữa',
      ),
      '429 without wait': (
        http.Response('x', 429),
        'Thử sai quá nhiều lần. Vui lòng thử lại sau.',
      ),
      '429 with wait': (
        http.Response('x', 429, headers: {'retry-after': '30'}),
        'Thử sai quá nhiều lần. Thử lại sau 30 giây.',
      ),
      '403': (
        http.Response('x', 403),
        'Chức năng sửa thực đơn đang tắt trên máy chủ',
      ),
      '400': (http.Response('x', 400), 'Không lưu được. Thử lại.'),
      '500': (http.Response('x', 500), 'Không lưu được. Thử lại.'),
    };
    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        onPost = (_) async => entry.value.$1;
        await pumpPage(tester);
        await openForm(tester);
        await fillValid(tester);
        await tester.enterText(
          field('Tên tệp ảnh (không bắt buộc)'),
          'xoi-ga.webp',
        );
        await submit(tester);
        expect(posts, hasLength(1));
        expect(find.text('Thêm món mới'), findsOneWidget);
        expect(find.text(entry.value.$2), findsOneWidget);
        String textOf(String label) =>
            tester.widget<TextField>(field(label)).controller!.text;
        expect(textOf('Tên món'), 'Xôi gà');
        expect(textOf('Mô tả (không bắt buộc)'), 'Nhiều xôi');
        expect(textOf('Giá (VNĐ)'), '30000');
        expect(textOf('Tên tệp ảnh (không bắt buộc)'), 'xoi-ga.webp');
        expect(find.byType(SwitchListTile), findsOneWidget);
        // The list is unchanged and a second try can succeed.
        onPost = (r) async => created(r);
        await submit(tester);
        expect(posts, hasLength(2));
        expect(find.text('Thêm món mới'), findsNothing);
        expect(find.text('Xôi gà'), findsOneWidget);
      });
    }

    testWidgets('cancelling the reopened form ends it', (tester) async {
      onPost = (_) async => http.Response('x', 409);
      await pumpPage(tester);
      await openForm(tester);
      await fillValid(tester);
      await submit(tester);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm món mới'), findsNothing);
      expect(find.text('Đã có món trùng tên trong mục này'), findsNothing);
      expect(posts, hasLength(1));
    });
  });

  testWidgets('neither the ID nor the password appears in the widget tree', (
    tester,
  ) async {
    onPost = (_) async => http.Response('$staffId $password', 409);
    await pumpPage(tester);
    await openForm(tester);
    await logIn(tester);
    await fillValid(tester);
    await submit(tester);
    for (final secret in [staffId, password]) {
      expect(find.textContaining(secret), findsNothing);
      expect(
        find.byWidgetPredicate((w) {
          if (w is EditableText) return w.controller.text.contains(secret);
          if (w is Tooltip) return (w.message ?? '').contains(secret);
          return false;
        }),
        findsNothing,
      );
    }
  });

  group('large text on a 360 px screen', () {
    for (final (locale, scale) in [
      ('de', 1.0),
      ('de', 2.0),
      ('ru', 1.3),
      ('ru', 2.0),
      ('lo', 1.3),
      ('lo', 2.0),
    ]) {
      testWidgets('$locale x$scale: the form scrolls, no overflow', (
        tester,
      ) async {
        withCredentials();
        await pumpPage(
          tester,
          width: 360,
          height: 500,
          textScale: scale,
          locale: Locale(locale),
        );
        await openForm(tester);
        expect(tester.takeException(), isNull);
        // Choose Food (the longest form), then submit empty for the errors.
        final dropdown = find.byType(DropdownButtonFormField<MenuCategory>);
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .text(lookupAppLocalizations(Locale(locale)).customerCategoryFood)
              .last,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SwitchListTile), findsOneWidget);
        await tester.ensureVisible(find.byType(FilledButton).last);
        await tester.tap(find.byType(FilledButton).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // The whole form can be scrolled to its last field.
        await tester.scrollUntilVisible(
          find.byType(TextField).last,
          100,
          scrollable: find.byType(Scrollable).last,
        );
        expect(tester.takeException(), isNull);
        expect(posts, isEmpty);
      });
    }
  });

  group('wording', () {
    testWidgets('vi labels', (tester) async {
      withCredentials();
      await pumpPage(tester);
      await openForm(tester);
      for (final text in [
        'Thêm món mới',
        'Tên món',
        'Mô tả (không bắt buộc)',
        'Giá (VNĐ)',
        'Mục',
        'Tên tệp ảnh (không bắt buộc)',
        'Tệp ảnh phải có sẵn trong thư mục ảnh trên máy chủ.',
        'Hủy',
        'Thêm',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });

    testWidgets('en labels', (tester) async {
      withCredentials();
      await pumpPage(tester, locale: const Locale('en'));
      expect(find.byTooltip('Add item'), findsOneWidget);
      await openForm(tester);
      for (final text in [
        'Add a new item',
        'Name',
        'Description (optional)',
        'Category',
        'Picture file name (optional)',
        'Cancel',
        'Add',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });
  });
}
