import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/customer/api/payment_client.dart';
import 'package:food_orders/customer/pages/payment_qr_page.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';

const note = 'Đổi sang thanh toán tiền mặt nếu bạn chưa muốn thanh toán luôn';
const cashButton = 'Chuyển sang tiền mặt';
const newQrButton = 'Tạo mã QR mới';
const question =
    'Đơn của bạn đã hết hạn thanh toán. '
    'Bạn có muốn chuyển sang thanh toán tiền mặt không?';
const tooLateText = 'Đã quá 15 phút. Hãy đặt lại đơn hoặc báo cho quán.';
const unavailableText = 'Chuyển khoản tạm thời không dùng được';
const failureText = 'Không thực hiện được. Vui lòng thử lại.';

final start = DateTime.utc(2026, 11, 19, 10);

Order orderWith({
  OrderStatus status = OrderStatus.awaiting_payment,
  PaymentMethod method = PaymentMethod.bank_transfer,
  DateTime? due,
  bool noDue = false,
}) => Order(
  id: 'o1',
  customerName: 'An',
  items: [OrderItem(name: 'Xôi thịt', quantity: 1, price: 25000)],
  status: status,
  placedAt: DateTime(2026, 11, 19, 10),
  paymentMethod: method,
  paymentDueAt: noDue ? null : (due ?? start.add(const Duration(minutes: 5))),
);

String _tlv(String tag, String value) =>
    '$tag${value.length.toString().padLeft(2, '0')}$value';

/// A VietQR-shaped payload; [marker] (tag 62 > 05) tells payloads apart,
/// and 62 > 08 carries the reference the fake backend sends ('DH000001').
String payloadOf(String marker) {
  final consumer = _tlv('00', '970403') + _tlv('01', '123456789');
  final merchant =
      _tlv('00', 'A000000727') + _tlv('01', consumer) + _tlv('02', 'QRIBFTTA');
  return _tlv('00', '01') +
      _tlv('38', merchant) +
      _tlv('54', '25000') +
      _tlv('62', _tlv('05', marker) + _tlv('08', 'DH000001'));
}

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late DateTime clock;
  late int qrCalls;
  late List<http.Request> posts;
  late Future<http.Response> Function(http.Request) onPost;
  late Future<http.Response> Function(http.Request) onGet;
  late List<http.Request> gets;
  late Future<http.Response> Function(http.Request) onQr;

  setUp(() {
    clock = start;
    qrCalls = 0;
    posts = [];
    gets = [];
    onGet = (_) async => json([]);
    onPost = (_) async => http.Response('boom', 500);
    onQr = (request) async {
      qrCalls++;
      final due = _currentDue();
      return json({
        'payload': payloadOf('QR$qrCalls'),
        'amount': 25000,
        'reference': 'DH000001',
        'dueAt': due.toIso8601String(),
        'bankName': 'ACB',
        'accountNumber': '123456789',
        'accountName': 'QUAN XOI',
      });
    };
    OrderRepository.instance
      ..setApiForTest(
        OrderApiClient(
          client: MockClient((request) {
            if (request.method == 'GET') {
              gets.add(request);
              return onGet(request);
            }
            posts.add(request);
            return onPost(request);
          }),
        ),
      )
      ..setOrdersForTest(const []);
  });
  tearDown(() => OrderRepository.instance.setOrdersForTest(const []));

  /// Opens the page from a home page, so "back" has somewhere to go.
  Future<void> open(
    WidgetTester tester, {
    double scale = 1.0,
    double width = 800,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final client = PaymentClient(client: MockClient((r) => onQr(r)));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PaymentQrPage(
                    orderId: 'o1',
                    paymentClient: client,
                    now: () => clock,
                  ),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    // Not pumpAndSettle: a spinner on the page never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Moves the fake clock and the test clock together.
  Future<void> advance(WidgetTester tester, Duration d) async {
    clock = clock.add(d);
    await tester.pump(d);
  }

  void setOrder(Order order) =>
      OrderRepository.instance.setOrdersForTest([order]);

  Finder qr() => find.byType(QrImageView);
  String shownPayload(WidgetTester tester) =>
      (tester.widget<QrImageView>(qr()).key! as ValueKey<String>).value;

  group('awaiting payment', () {
    testWidgets('shows the QR, the details, the note and the countdown', (
      tester,
    ) async {
      setOrder(orderWith());
      await open(tester);

      expect(shownPayload(tester), contains('QR1'));
      for (final text in [
        'ACB',
        '123456789',
        'QUAN XOI',
        '25.000 VNĐ',
        'DH000001',
        note,
        cashButton,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.byType(SelectableText), findsNWidgets(5));
      expect(
        find.text('Hãy chuyển khoản trong vòng 5 phút để giữ đơn.'),
        findsOneWidget,
      );
      expect(find.text('Còn lại 05:00'), findsOneWidget);
      await advance(tester, const Duration(seconds: 1));
      expect(find.text('Còn lại 04:59'), findsOneWidget);
    });

    testWidgets('fetchQr failing shows a message and Retry refetches', (
      tester,
    ) async {
      onQr = (_) async => http.Response('secret server text', 500);
      setOrder(orderWith());
      await open(tester);

      expect(qr(), findsNothing);
      expect(find.text('Không tải được mã QR.'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
      expect(qrCalls, 0);

      onQr = (_) async {
        qrCalls++;
        return json({
          'payload': payloadOf('RETRIED'),
          'amount': 25000,
          'reference': 'DH000001',
          'dueAt': _currentDue().toIso8601String(),
          'bankName': 'ACB',
          'accountNumber': '123456789',
          'accountName': 'QUAN XOI',
        });
      };
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(shownPayload(tester), contains('RETRIED'));
    });

    testWidgets('a hung QR request ends in the Retry state', (tester) async {
      final never = Completer<http.Response>();
      onQr = (_) => never.future;
      setOrder(orderWith());
      await open(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await advance(tester, const Duration(seconds: 16));
      expect(find.text('Không tải được mã QR.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('the countdown reaching zero hides the QR, never negative', (
      tester,
    ) async {
      setOrder(orderWith());
      await open(tester);
      expect(qr(), findsOneWidget);

      await advance(tester, const Duration(seconds: 299));
      expect(find.text('Còn lại 00:01'), findsOneWidget);
      expect(qr(), findsOneWidget);

      await advance(tester, const Duration(seconds: 1));
      expect(qr(), findsNothing);
      expect(find.text('Đang kiểm tra thanh toán…'), findsOneWidget);
      expect(find.textContaining('Còn lại'), findsNothing);
      expect(find.text('ACB'), findsNothing);

      await advance(tester, const Duration(seconds: 30));
      expect(find.textContaining('-'), findsNothing);
    });

    testWidgets('a deadline already past is shown as checking, not as a QR', (
      tester,
    ) async {
      // The server can still say awaiting_payment for up to 15 s after.
      setOrder(orderWith(due: start.subtract(const Duration(seconds: 3))));
      await open(tester);
      expect(qr(), findsNothing);
      expect(qrCalls, 0);
      expect(find.text('Đang kiểm tra thanh toán…'), findsOneWidget);
    });
  });

  group('switch to cash', () {
    testWidgets('success hides the QR and shows the cash message', (
      tester,
    ) async {
      setOrder(orderWith());
      onPost = (_) async => json(
        orderWith(
          status: OrderStatus.preparing,
          method: PaymentMethod.cash,
        ).toJson(),
      );
      await open(tester);
      await tester.tap(find.text(cashButton));
      await tester.pumpAndSettle();

      expect(posts.single.url.path, endsWith('/orders/o1/switch-to-cash'));
      expect(qr(), findsNothing);
      expect(find.text('ACB'), findsNothing);
      expect(find.text('DH000001'), findsNothing);
      expect(
        find.text('Đơn của bạn sẽ được thanh toán bằng tiền mặt.'),
        findsOneWidget,
      );
      expect(
        OrderRepository.instance.orders.single.paymentMethod,
        PaymentMethod.cash,
      );
    });

    testWidgets('failure keeps the QR and shows the failure text', (
      tester,
    ) async {
      setOrder(orderWith());
      onPost = (_) async => http.Response('server says no', 500);
      await open(tester);
      await tester.tap(find.text(cashButton));
      await tester.pumpAndSettle();

      expect(qr(), findsOneWidget);
      expect(find.text(failureText), findsOneWidget);
      expect(find.textContaining('server says'), findsNothing);
    });

    testWidgets('the button is disabled while the call runs', (tester) async {
      setOrder(orderWith());
      final gate = Completer<http.Response>();
      onPost = (_) => gate.future;
      await open(tester);
      await tester.tap(find.text(cashButton));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, cashButton),
      );
      expect(button.onPressed, isNull);
      gate.complete(http.Response('boom', 500));
      await tester.pumpAndSettle();
    });

    testWidgets('a 409 re-reads the repository and shows the new state', (
      tester,
    ) async {
      setOrder(orderWith());
      onPost = (_) async {
        // Staff confirmed the transfer meanwhile; the stream says so.
        setOrder(orderWith(status: OrderStatus.preparing));
        return http.Response('conflict', 409);
      };
      await open(tester);
      await tester.tap(find.text(cashButton));
      await tester.pumpAndSettle();

      expect(qr(), findsNothing);
      expect(find.text('Đã nhận thanh toán. Cảm ơn bạn!'), findsOneWidget);
      expect(find.text(failureText), findsNothing);
    });
  });

  group('the order changes while the page is open', () {
    testWidgets('preparing by transfer: paid view, no QR', (tester) async {
      setOrder(orderWith());
      await open(tester);
      expect(qr(), findsOneWidget);

      setOrder(orderWith(status: OrderStatus.preparing));
      await tester.pump();
      expect(qr(), findsNothing);
      expect(find.text('Đã nhận thanh toán. Cảm ơn bạn!'), findsOneWidget);
      expect(find.text('Về menu'), findsOneWidget);
    });

    testWidgets('preparing as cash: cash view, no QR', (tester) async {
      setOrder(orderWith());
      await open(tester);
      setOrder(
        orderWith(status: OrderStatus.preparing, method: PaymentMethod.cash),
      );
      await tester.pump();
      expect(qr(), findsNothing);
      expect(
        find.text('Đơn của bạn sẽ được thanh toán bằng tiền mặt.'),
        findsOneWidget,
      );
    });

    testWidgets('the QR goes away at once on the status change', (
      tester,
    ) async {
      setOrder(orderWith());
      await open(tester);
      setOrder(orderWith(status: OrderStatus.cancelled, noDue: true));
      await tester.pump();
      expect(qr(), findsNothing);
      expect(find.text('Đơn của bạn đã bị hủy.'), findsOneWidget);
    });

    testWidgets('a staff-cancelled order is not asked', (tester) async {
      setOrder(orderWith(status: OrderStatus.cancelled, noDue: true));
      await open(tester);
      expect(find.text('Đơn của bạn đã bị hủy.'), findsOneWidget);
      expect(find.text(question), findsNothing);
      expect(find.text(cashButton), findsNothing);
      expect(find.text(newQrButton), findsNothing);
      expect(find.text('Về menu'), findsOneWidget);
    });

    testWidgets('an unknown order shows a message', (tester) async {
      await open(tester);
      expect(find.text('Không tìm thấy đơn hàng.'), findsOneWidget);
    });
  });

  group('expired order', () {
    Order expired({DateTime? due}) =>
        orderWith(status: OrderStatus.cancelled, due: due);

    testWidgets('flipping to cancelled asks the question, no QR', (
      tester,
    ) async {
      setOrder(orderWith());
      await open(tester);
      expect(qr(), findsOneWidget);

      await advance(tester, const Duration(minutes: 5));
      setOrder(expired());
      await tester.pump();

      expect(qr(), findsNothing);
      expect(find.text(question), findsOneWidget);
      expect(find.text(cashButton), findsOneWidget);
      expect(find.text(newQrButton), findsOneWidget);
    });

    testWidgets('"Chuyển sang tiền mặt" switches to cash', (tester) async {
      clock = start.add(const Duration(minutes: 6));
      setOrder(expired());
      onPost = (_) async => json(
        orderWith(
          status: OrderStatus.preparing,
          method: PaymentMethod.cash,
        ).toJson(),
      );
      await open(tester);
      await tester.tap(find.text(cashButton));
      await tester.pumpAndSettle();

      expect(posts.single.url.path, endsWith('/switch-to-cash'));
      expect(find.text(question), findsNothing);
      expect(
        find.text('Đơn của bạn sẽ được thanh toán bằng tiền mặt.'),
        findsOneWidget,
      );
    });

    testWidgets('"Tạo mã QR mới" renews: a new QR and a new countdown', (
      tester,
    ) async {
      clock = start.add(const Duration(minutes: 6));
      setOrder(expired());
      final newDue = clock.add(const Duration(minutes: 5));
      onPost = (_) async => json(
        orderWith(due: newDue).toJson()
          ..['paymentDueAt'] = newDue.toIso8601String(),
      );
      await open(tester);
      expect(qrCalls, 0);

      await tester.tap(find.text(newQrButton));
      await tester.pumpAndSettle();

      expect(posts.single.url.path, endsWith('/orders/o1/renew-payment'));
      expect(qrCalls, 1);
      expect(find.text(question), findsNothing);
      expect(shownPayload(tester), contains('QR1'));
      expect(find.text('Còn lại 05:00'), findsOneWidget);
      await advance(tester, const Duration(seconds: 1));
      expect(find.text('Còn lại 04:59'), findsOneWidget);
    });

    testWidgets('a second renewal fetches another QR, the old one is gone', (
      tester,
    ) async {
      setOrder(orderWith());
      await open(tester);
      expect(shownPayload(tester), contains('QR1'));

      await advance(tester, const Duration(minutes: 5));
      setOrder(expired());
      await tester.pump();
      expect(qr(), findsNothing);

      final newDue = clock.add(const Duration(minutes: 5));
      setOrder(orderWith(due: newDue));
      await tester.pumpAndSettle();
      expect(qrCalls, 2);
      expect(shownPayload(tester), contains('QR2'));
      expect(find.text('Còn lại 05:00'), findsOneWidget);
    });

    testWidgets('409 still expired: shows "đã quá 15 phút"', (tester) async {
      clock = start.add(const Duration(minutes: 6));
      setOrder(expired());
      onPost = (_) async => http.Response('late', 409);
      await open(tester);
      await tester.tap(find.text(newQrButton));
      await tester.pumpAndSettle();

      expect(find.text(tooLateText), findsOneWidget);
      expect(find.text(cashButton), findsNothing);
      expect(find.text(newQrButton), findsNothing);
      expect(find.text('Về menu'), findsOneWidget);
    });

    testWidgets('renew 503 shows the unavailable text, cash stays', (
      tester,
    ) async {
      clock = start.add(const Duration(minutes: 6));
      setOrder(expired());
      onPost = (_) async => http.Response('off', 503);
      await open(tester);
      await tester.tap(find.text(newQrButton));
      await tester.pumpAndSettle();

      expect(find.text(unavailableText), findsOneWidget);
      expect(find.text(cashButton), findsOneWidget);
      expect(find.text(question), findsOneWidget);
    });

    testWidgets('other failures show the failure text', (tester) async {
      clock = start.add(const Duration(minutes: 6));
      setOrder(expired());
      await open(tester);
      await tester.tap(find.text(cashButton));
      await tester.pumpAndSettle();
      expect(find.text(failureText), findsOneWidget);
      expect(find.text(cashButton), findsOneWidget);
    });

    testWidgets('both buttons are disabled while a call runs', (tester) async {
      clock = start.add(const Duration(minutes: 6));
      setOrder(expired());
      final gate = Completer<http.Response>();
      onPost = (_) => gate.future;
      await open(tester);
      await tester.tap(find.text(newQrButton));
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, cashButton))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, newQrButton),
            )
            .onPressed,
        isNull,
      );
      gate.complete(http.Response('boom', 500));
      await tester.pumpAndSettle();
    });

    testWidgets('a hung call ends with the failure text', (tester) async {
      clock = start.add(const Duration(minutes: 6));
      setOrder(expired());
      onPost = (_) => Completer<http.Response>().future;
      await open(tester);
      await tester.tap(find.text(cashButton));
      await tester.pump();
      await advance(tester, const Duration(seconds: 16));
      expect(find.text(failureText), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, cashButton))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('the 15 minutes: shown at +14:59, hidden after', (
      tester,
    ) async {
      clock = start.add(const Duration(minutes: 5, seconds: 1));
      setOrder(expired());
      await open(tester);
      // 14:59 after the deadline.
      await advance(tester, const Duration(minutes: 14, seconds: 58));
      expect(find.text(question), findsOneWidget);
      expect(find.text(newQrButton), findsOneWidget);

      await advance(tester, const Duration(seconds: 2));
      expect(find.text(question), findsNothing);
      expect(find.text(newQrButton), findsNothing);
      expect(find.text(tooLateText), findsOneWidget);
    });

    testWidgets('already past 15 minutes when opened', (tester) async {
      clock = start.add(const Duration(minutes: 21));
      setOrder(expired());
      await open(tester);
      expect(find.text(tooLateText), findsOneWidget);
      expect(find.text(cashButton), findsNothing);
    });

    testWidgets('an out-of-range deadline counts as not renewable', (
      tester,
    ) async {
      clock = start.add(const Duration(minutes: 6));
      setOrder(
        expired(
          due: DateTime.fromMillisecondsSinceEpoch(
            8640000000000000,
            isUtc: true,
          ),
        ),
      );
      await open(tester);
      expect(find.text(tooLateText), findsOneWidget);
    });

    testWidgets('staff switch it to cash while open: cash view', (
      tester,
    ) async {
      clock = start.add(const Duration(minutes: 6));
      setOrder(expired());
      await open(tester);
      expect(find.text(question), findsOneWidget);

      setOrder(
        orderWith(status: OrderStatus.preparing, method: PaymentMethod.cash),
      );
      await tester.pump();
      expect(find.text(question), findsNothing);
      expect(
        find.text('Đơn của bạn sẽ được thanh toán bằng tiền mặt.'),
        findsOneWidget,
      );
    });
  });

  Map<String, Object?> orderJson(Order o) =>
      o.toJson()..['paymentDueAt'] = o.paymentDueAt?.toIso8601String();

  group('stale cache (the stream is late or down)', () {
    testWidgets('past the deadline: a re-read 2 s later shows the question', (
      tester,
    ) async {
      setOrder(orderWith());
      final expired = orderWith(status: OrderStatus.cancelled);
      onGet = (_) async => json([orderJson(expired)]);
      await open(tester);
      await advance(tester, const Duration(seconds: 299));
      await advance(tester, const Duration(seconds: 1));
      expect(find.text('Đang kiểm tra thanh toán…'), findsOneWidget);
      expect(gets, isEmpty);

      await advance(tester, const Duration(seconds: 1));
      expect(gets, isEmpty);
      await advance(tester, const Duration(seconds: 1, milliseconds: 100));
      await tester.pump();
      expect(gets, hasLength(1));
      expect(find.text(question), findsOneWidget);
      expect(find.text('Đang kiểm tra thanh toán…'), findsNothing);
      expect(qr(), findsNothing);
    });

    testWidgets('the re-read happens once per deadline', (tester) async {
      setOrder(orderWith());
      await open(tester);
      await advance(tester, const Duration(seconds: 299));
      await advance(tester, const Duration(seconds: 4));
      await advance(tester, const Duration(seconds: 30));
      expect(gets, hasLength(1));
      expect(find.text('Đang kiểm tra thanh toán…'), findsOneWidget);
    });

    testWidgets('the checking view has "Kiểm tra lại" and "Về menu"', (
      tester,
    ) async {
      setOrder(orderWith(due: start.subtract(const Duration(seconds: 3))));
      await open(tester);
      await advance(tester, const Duration(seconds: 3));
      final before = gets.length;
      onGet = (_) async =>
          json([orderJson(orderWith(status: OrderStatus.preparing))]);
      await tester.tap(find.text('Kiểm tra lại'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(gets.length, before + 1);
      expect(find.text('Đã nhận thanh toán. Cảm ơn bạn!'), findsOneWidget);

      setOrder(orderWith(due: start.subtract(const Duration(seconds: 3))));
      await tester.pump();
      await tester.tap(find.text('Về menu'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('refresh errors are swallowed', (tester) async {
      setOrder(orderWith(due: start.subtract(const Duration(seconds: 3))));
      onGet = (_) async => http.Response('not json <html>', 500);
      await open(tester);
      await advance(tester, const Duration(seconds: 3));
      await tester.tap(find.text('Kiểm tra lại'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('Đang kiểm tra thanh toán…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Kiểm tra lại'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('a hung re-read is cut off by the timeout', (tester) async {
      setOrder(orderWith(due: start.subtract(const Duration(seconds: 3))));
      onGet = (_) => Completer<http.Response>().future;
      await open(tester);
      await tester.tap(find.text('Kiểm tra lại'));
      await tester.pump();
      await advance(tester, const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Kiểm tra lại'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('409 with a stale cache: the re-read shows the true state', (
      tester,
    ) async {
      clock = start.add(const Duration(minutes: 6));
      setOrder(orderWith(status: OrderStatus.cancelled));
      onPost = (_) async => http.Response('conflict', 409);
      onGet = (_) async => json([
        orderJson(
          orderWith(status: OrderStatus.preparing, method: PaymentMethod.cash),
        ),
      ]);
      await open(tester);
      await tester.tap(find.text(cashButton));
      await tester.pumpAndSettle();

      expect(gets, hasLength(1));
      expect(find.text(tooLateText), findsNothing);
      expect(
        find.text('Đơn của bạn sẽ được thanh toán bằng tiền mặt.'),
        findsOneWidget,
      );
    });

    testWidgets('409 on an unchanged QR view shows the short note', (
      tester,
    ) async {
      setOrder(orderWith());
      onPost = (_) async => http.Response('conflict', 409);
      onGet = (_) async => json([orderJson(orderWith())]);
      await open(tester);
      await tester.tap(find.text(cashButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Đơn vừa thay đổi, đang kiểm tra lại'), findsOneWidget);
      expect(find.text(cashButton), findsOneWidget);
      expect(find.text(failureText), findsNothing);
    });

    testWidgets('409 on an expired order still expired: too late', (
      tester,
    ) async {
      clock = start.add(const Duration(minutes: 6));
      final expired = orderWith(status: OrderStatus.cancelled);
      setOrder(expired);
      onPost = (_) async => http.Response('conflict', 409);
      onGet = (_) async => json([orderJson(expired)]);
      await open(tester);
      await tester.tap(find.text(newQrButton));
      await tester.pumpAndSettle();
      expect(gets, hasLength(1));
      expect(find.text(tooLateText), findsOneWidget);
    });
  });

  group('QR answers for the wrong window', () {
    testWidgets('a late answer for the old window is dropped after a renewal', (
      tester,
    ) async {
      final oldAnswer = Completer<http.Response>();
      var calls = 0;
      onQr = (_) {
        calls++;
        if (calls == 1) return oldAnswer.future;
        return Future.value(
          json({
            'payload': payloadOf('NEW'),
            'amount': 25000,
            'reference': 'DH000001',
            'dueAt': _currentDue().toIso8601String(),
            'bankName': 'ACB',
            'accountNumber': '123456789',
            'accountName': 'QUAN XOI',
          }),
        );
      };
      final oldDue = start.add(const Duration(minutes: 5));
      setOrder(orderWith(due: oldDue));
      await open(tester);
      expect(qr(), findsNothing);

      // Renewed while the first request is still in flight.
      final newDue = start.add(const Duration(minutes: 10));
      clock = start.add(const Duration(minutes: 5));
      setOrder(orderWith(due: newDue));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(shownPayload(tester), contains('NEW'));

      oldAnswer.complete(
        json({
          'payload': payloadOf('OLD'),
          'amount': 25000,
          'reference': 'DH000001',
          'dueAt': oldDue.toIso8601String(),
          'bankName': 'ACB',
          'accountNumber': '123456789',
          'accountName': 'QUAN XOI',
        }),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(shownPayload(tester), contains('NEW'));
      expect(find.byType(QrImageView), findsOneWidget);
    });

    Future<void> openWithDueOffset(WidgetTester tester, Duration offset) async {
      onQr = (_) async => json({
        'payload': payloadOf('X'),
        'amount': 25000,
        'reference': 'DH000001',
        'dueAt': _currentDue().add(offset).toIso8601String(),
        'bankName': 'ACB',
        'accountNumber': '123456789',
        'accountName': 'QUAN XOI',
      });
      setOrder(orderWith());
      await open(tester);
    }

    testWidgets('a dueAt 6 s off is not shown: Retry state', (tester) async {
      await openWithDueOffset(tester, const Duration(seconds: 6));
      expect(qr(), findsNothing);
      expect(find.text('Không tải được mã QR.'), findsOneWidget);
    });

    testWidgets('a dueAt 6 s early is not shown either', (tester) async {
      await openWithDueOffset(tester, const Duration(seconds: -6));
      expect(qr(), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('a dueAt 4 s off is accepted', (tester) async {
      await openWithDueOffset(tester, const Duration(seconds: 4));
      expect(qr(), findsOneWidget);
    });
  });

  testWidgets('leaving the page cancels the timer', (tester) async {
    setOrder(orderWith());
    await open(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    // flutter_test fails the test if a periodic timer survives the page.
    await advance(tester, const Duration(seconds: 5));
    expect(find.text('home'), findsOneWidget);
    expect(
      OrderRepository.instance.orders.single.status,
      OrderStatus.awaiting_payment,
    );
  });

  testWidgets('a QR answer arriving after leaving is ignored', (tester) async {
    final gate = Completer<http.Response>();
    onQr = (_) => gate.future;
    setOrder(orderWith());
    await open(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    gate.complete(http.Response('x', 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    for (final (label, build) in <(String, void Function())>[
      (
        'QR view',
        () => OrderRepository.instance.setOrdersForTest([orderWith()]),
      ),
      (
        'question view',
        () {
          clock = start.add(const Duration(minutes: 6));
          OrderRepository.instance.setOrdersForTest([
            orderWith(status: OrderStatus.cancelled),
          ]);
        },
      ),
      (
        'too late view',
        () {
          clock = start.add(const Duration(minutes: 30));
          OrderRepository.instance.setOrdersForTest([
            orderWith(status: OrderStatus.cancelled),
          ]);
        },
      ),
    ]) {
      testWidgets('$label fits at 360 px (text x$scale)', (tester) async {
        build();
        await open(tester, scale: scale, width: 360);
        expect(tester.takeException(), isNull);
        // Everything can be reached by scrolling: no overflow stripes.
        final scroll = find.byType(SingleChildScrollView);
        expect(scroll, findsOneWidget);
        await tester.drag(scroll, const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}

DateTime _currentDue() {
  final order = OrderRepository.instance.orders.single;
  return order.paymentDueAt ?? DateTime.utc(2026, 11, 19, 10, 5);
}
