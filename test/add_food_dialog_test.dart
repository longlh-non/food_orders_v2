import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_app.dart';

import 'package:food_orders/customer/pages/menu_page.dart';
import 'package:food_orders/customer/state/cart.dart';
import 'package:food_orders/customer/state/menu_state.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/money.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object> item(
  String id,
  String name,
  double price,
  String category, {
  bool allowToppings = false,
}) => {
  'id': id,
  'name': name,
  'description': '',
  'price': price,
  'category': category,
  'allowToppings': allowToppings,
};

final xoiThit = item(
  'xoi-thit',
  'Xôi thịt',
  25000,
  'food',
  allowToppings: true,
);
final xoiRuoc = item('xoi-ruoc', 'Xôi ruốc', 25000, 'food');
final traDa = item('tra-da', 'Trà đá', 4000, 'drink');
final boHuc = item('bo-huc', 'Bò húc', 20000, 'drink');
final trungNgaiCuu = item('trung-ngai-cuu', 'Trứng ngải cứu', 10000, 'snack');
final khoai = item('khoai', 'Khoai lang nướng', 15000, 'nibble');

const allToppings = [
  {'id': 'cha', 'name': 'Thêm chả', 'price': 10000},
  {'id': 'thit', 'name': 'Thêm thịt', 'price': 10000},
  {'id': 'trung', 'name': 'Thêm trứng tráng', 'price': 8000},
];

http.Response ok(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<MenuState> loadedState({
  List<Map<String, Object>>? menu,
  List<Object> toppings = allToppings,
}) async {
  final state = MenuState(
    OrderApiClient(
      client: MockClient(
        (request) async => request.url.path.endsWith('/toppings')
            ? ok(toppings)
            : ok(menu ?? [xoiThit, xoiRuoc, traDa, boHuc, trungNgaiCuu, khoai]),
      ),
    ),
  );
  await state.load();
  return state;
}

Future<void> pumpMenu(
  WidgetTester tester,
  MenuState state, {
  double width = 800,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    l10nApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: MenuPage(state: state),
    ),
  );
}

Finder get dialog => find.byType(AlertDialog);
Finder inDialog(String text) =>
    find.descendant(of: dialog, matching: find.text(text));

/// Taps the round "+" on the tile named [name] (on the open tab).
Future<void> tapTileAdd(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Thêm $name'));
  await tester.pumpAndSettle();
}

Future<void> tapInDialog(WidgetTester tester, String text) async {
  await tester.tap(inDialog(text));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

bool isTicked(WidgetTester tester, String label) => tester
    .widget<CheckboxListTile>(
      find.ancestor(
        of: inDialog(label),
        matching: find.byType(CheckboxListTile),
      ),
    )
    .value!;

/// Each cart line as "name [topping ids] x quantity".
List<String> cartLines() => [
  for (final MapEntry(key: line, value: quantity)
      in Cart.instance.lines.entries)
    '${line.item.name} ${[for (final t in line.toppings) t.id]} x$quantity',
];

void main() {
  setUp(Cart.instance.clear);
  tearDown(Cart.instance.clear);

  testWidgets('Add on a food opens the dialog, unticked, cart untouched', (
    tester,
  ) async {
    await pumpMenu(tester, await loadedState());

    await tapTileAdd(tester, 'Xôi thịt');

    expect(dialog, findsOneWidget);
    expect(inDialog('Thêm Xôi thịt'), findsOneWidget);
    expect(isTicked(tester, 'Thêm topping'), isFalse);
    expect(isTicked(tester, 'Thêm đồ uống'), isFalse);
    expect(Cart.instance.lines, isEmpty);
  });

  testWidgets('Add with nothing ticked adds one plain line', (tester) async {
    await pumpMenu(tester, await loadedState());

    await tapTileAdd(tester, 'Xôi thịt');
    await tapInDialog(tester, 'Thêm');

    expect(dialog, findsNothing);
    expect(cartLines(), ['Xôi thịt [] x1']);
    expect(find.text('Đã thêm Xôi thịt'), findsOneWidget);
  });

  testWidgets('toppings: pick two, the shown total matches the cart', (
    tester,
  ) async {
    await pumpMenu(tester, await loadedState());

    await tapTileAdd(tester, 'Xôi thịt');
    await tapInDialog(tester, 'Thêm topping');
    await tapInDialog(tester, 'Tiếp');
    expect(inDialog('Thêm chả'), findsOneWidget);
    expect(inDialog('+${formatVnd(8000)}'), findsOneWidget);
    expect(inDialog('Xôi thịt: ${formatVnd(25000)}'), findsOneWidget);

    await tapInDialog(tester, 'Thêm chả');
    await tapInDialog(tester, 'Thêm trứng tráng');
    final shown = 'Xôi thịt: ${formatVnd(43000)}';
    expect(inDialog(shown), findsOneWidget);
    await tapInDialog(tester, 'Thêm');

    expect(cartLines(), ['Xôi thịt [cha, trung] x1']);
    expect(shown, 'Xôi thịt: ${formatVnd(Cart.instance.total)}');
  });

  testWidgets('drink: drinks listed on Đồ ăn; dish and drink are two lines', (
    tester,
  ) async {
    await pumpMenu(tester, await loadedState());

    await tapTileAdd(tester, 'Xôi thịt');
    await tapInDialog(tester, 'Thêm đồ uống');
    await tapInDialog(tester, 'Tiếp');
    expect(inDialog('Trà đá'), findsOneWidget);
    expect(inDialog('Bò húc'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: dialog,
              matching: find.widgetWithText(FilledButton, 'Thêm'),
            ),
          )
          .onPressed,
      isNull,
      reason: 'a drink must be chosen first',
    );

    await tapInDialog(tester, 'Trà đá');
    await tapInDialog(tester, 'Thêm');

    expect(cartLines(), ['Xôi thịt [] x1', 'Trà đá [] x1']);
    expect(find.text('Đã thêm Xôi thịt + Trà đá'), findsOneWidget);
  });

  testWidgets('both ticked: toppings step, then drink step', (tester) async {
    await pumpMenu(tester, await loadedState());

    await tapTileAdd(tester, 'Xôi thịt');
    await tapInDialog(tester, 'Thêm topping');
    await tapInDialog(tester, 'Thêm đồ uống');
    await tapInDialog(tester, 'Tiếp');
    expect(inDialog('Thêm topping'), findsOneWidget, reason: 'title');
    await tapInDialog(tester, 'Thêm thịt');
    await tapInDialog(tester, 'Tiếp');
    await tapInDialog(tester, 'Bò húc');
    await tapInDialog(tester, 'Thêm');

    expect(cartLines(), ['Xôi thịt [thit] x1', 'Bò húc [] x1']);
  });

  testWidgets('Back keeps the earlier ticks', (tester) async {
    await pumpMenu(tester, await loadedState());

    await tapTileAdd(tester, 'Xôi thịt');
    await tapInDialog(tester, 'Thêm topping');
    await tapInDialog(tester, 'Thêm đồ uống');
    await tapInDialog(tester, 'Tiếp');
    await tapInDialog(tester, 'Thêm chả');
    await tapInDialog(tester, 'Tiếp');
    await tapInDialog(tester, 'Trà đá');

    await tapInDialog(tester, 'Quay lại');
    expect(isTicked(tester, 'Thêm chả'), isTrue);
    await tapInDialog(tester, 'Quay lại');
    expect(isTicked(tester, 'Thêm topping'), isTrue);
    expect(isTicked(tester, 'Thêm đồ uống'), isTrue);

    await tapInDialog(tester, 'Tiếp');
    await tapInDialog(tester, 'Tiếp');
    await tapInDialog(tester, 'Thêm');
    expect(cartLines(), ['Xôi thịt [cha] x1', 'Trà đá [] x1']);
  });

  testWidgets(
    'Back from the drink step (no toppings ticked) goes to the start',
    (tester) async {
      await pumpMenu(tester, await loadedState());

      await tapTileAdd(tester, 'Xôi thịt');
      await tapInDialog(tester, 'Thêm đồ uống');
      await tapInDialog(tester, 'Tiếp');
      await tapInDialog(tester, 'Quay lại');

      expect(inDialog('Thêm Xôi thịt'), findsOneWidget);
      expect(isTicked(tester, 'Thêm topping'), isFalse);
      expect(isTicked(tester, 'Thêm đồ uống'), isTrue);
    },
  );

  testWidgets('unticking after Back drops that choice', (tester) async {
    await pumpMenu(tester, await loadedState());

    await tapTileAdd(tester, 'Xôi thịt');
    await tapInDialog(tester, 'Thêm topping');
    await tapInDialog(tester, 'Thêm đồ uống');
    await tapInDialog(tester, 'Tiếp');
    await tapInDialog(tester, 'Thêm chả');
    await tapInDialog(tester, 'Tiếp');
    await tapInDialog(tester, 'Trà đá');
    await tapInDialog(tester, 'Quay lại');
    await tapInDialog(tester, 'Quay lại');
    await tapInDialog(tester, 'Thêm topping');
    await tapInDialog(tester, 'Thêm đồ uống');
    await tapInDialog(tester, 'Thêm');

    expect(cartLines(), ['Xôi thịt [] x1']);
  });

  group('dismissing adds nothing', () {
    Future<void> expectNothingAdded(WidgetTester tester) async {
      expect(dialog, findsNothing);
      expect(Cart.instance.lines, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    }

    testWidgets('Cancel', (tester) async {
      await pumpMenu(tester, await loadedState());
      await tapTileAdd(tester, 'Xôi thịt');
      await tapInDialog(tester, 'Thêm topping');
      await tapInDialog(tester, 'Hủy');
      await expectNothingAdded(tester);
    });

    testWidgets('tap outside', (tester) async {
      await pumpMenu(tester, await loadedState());
      await tapTileAdd(tester, 'Xôi thịt');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await expectNothingAdded(tester);
    });

    testWidgets('Escape in the toppings step', (tester) async {
      await pumpMenu(tester, await loadedState());
      await tapTileAdd(tester, 'Xôi thịt');
      await tapInDialog(tester, 'Thêm topping');
      await tapInDialog(tester, 'Tiếp');
      await tapInDialog(tester, 'Thêm chả');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await expectNothingAdded(tester);
    });

    testWidgets('tap outside in the drink step', (tester) async {
      await pumpMenu(tester, await loadedState());
      await tapTileAdd(tester, 'Xôi thịt');
      await tapInDialog(tester, 'Thêm đồ uống');
      await tapInDialog(tester, 'Tiếp');
      await tapInDialog(tester, 'Trà đá');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await expectNothingAdded(tester);
    });
  });

  testWidgets('same choice twice merges; other toppings make a new line', (
    tester,
  ) async {
    await pumpMenu(tester, await loadedState());

    Future<void> addWith(String topping) async {
      await tapTileAdd(tester, 'Xôi thịt');
      await tapInDialog(tester, 'Thêm topping');
      await tapInDialog(tester, 'Tiếp');
      await tapInDialog(tester, topping);
      await tapInDialog(tester, 'Thêm');
    }

    await addWith('Thêm chả');
    await addWith('Thêm chả');
    await addWith('Thêm thịt');

    expect(cartLines(), ['Xôi thịt [cha] x2', 'Xôi thịt [thit] x1']);
  });

  group('added directly, with no dialog', () {
    for (final (tab, name) in [
      ('Đồ uống', 'Trà đá'),
      ('Ăn nhẹ', 'Trứng ngải cứu'),
      ('Ăn vặt', 'Khoai lang nướng'),
    ]) {
      testWidgets('$name on $tab', (tester) async {
        await pumpMenu(tester, await loadedState());
        await openTab(tester, tab);

        await tapTileAdd(tester, name);

        expect(dialog, findsNothing);
        expect(cartLines(), ['$name [] x1']);
      });
    }

    testWidgets('a food when there are no toppings and no drinks', (
      tester,
    ) async {
      await pumpMenu(
        tester,
        await loadedState(menu: [xoiThit], toppings: const []),
      );
      await tapTileAdd(tester, 'Xôi thịt');
      expect(dialog, findsNothing);
      expect(cartLines(), ['Xôi thịt [] x1']);
    });

    testWidgets('a no-toppings dish when there are no drinks', (tester) async {
      await pumpMenu(tester, await loadedState(menu: [xoiRuoc]));
      await tapTileAdd(tester, 'Xôi ruốc');
      expect(dialog, findsNothing);
      expect(cartLines(), ['Xôi ruốc [] x1']);
    });
  });

  group('rows only for what can be offered', () {
    testWidgets('no toppings on the menu: only "Add drinks"', (tester) async {
      await pumpMenu(tester, await loadedState(toppings: const []));
      await tapTileAdd(tester, 'Xôi thịt');
      expect(inDialog('Thêm topping'), findsNothing);
      expect(inDialog('Thêm đồ uống'), findsOneWidget);
    });

    testWidgets('no drinks on the menu: only "Extra toppings"', (tester) async {
      await pumpMenu(tester, await loadedState(menu: [xoiThit]));
      await tapTileAdd(tester, 'Xôi thịt');
      expect(inDialog('Thêm topping'), findsOneWidget);
      expect(inDialog('Thêm đồ uống'), findsNothing);
    });

    testWidgets('a dish with allowToppings false: only "Add drinks"', (
      tester,
    ) async {
      await pumpMenu(tester, await loadedState());
      await tapTileAdd(tester, 'Xôi ruốc');
      expect(inDialog('Thêm topping'), findsNothing);
      expect(inDialog('Thêm đồ uống'), findsOneWidget);
    });
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('every step fits at 360 px (text x$scale)', (tester) async {
      await pumpMenu(tester, await loadedState(), width: 360, textScale: scale);

      await tapTileAdd(tester, 'Xôi thịt');
      expect(tester.takeException(), isNull);
      await tapInDialog(tester, 'Thêm topping');
      await tapInDialog(tester, 'Thêm đồ uống');
      await tester.ensureVisible(inDialog('Tiếp'));
      await tapInDialog(tester, 'Tiếp');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(inDialog('Thêm trứng tráng'));
      await tapInDialog(tester, 'Thêm trứng tráng');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(inDialog('Tiếp'));
      await tapInDialog(tester, 'Tiếp');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(inDialog('Bò húc'));
      await tapInDialog(tester, 'Bò húc');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(inDialog('Thêm'));
      await tapInDialog(tester, 'Thêm');
      expect(tester.takeException(), isNull);

      expect(cartLines(), ['Xôi thịt [trung] x1', 'Bò húc [] x1']);
    });
  }
}
