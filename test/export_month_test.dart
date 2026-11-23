import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/restaurant/api/export_client.dart';
import 'package:food_orders/restaurant/pages/export_month_dialog.dart';
import 'package:food_orders/restaurant/pages/orders_page.dart';
import 'package:food_orders/restaurant/state/staff_credentials.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/l10n_app.dart';

// Obviously fake test values.
const staffId = 'test-staff';
const token = 'test-password-1234';
const creds = StaffCredentials(id: staffId, password: token);

Finder idField() => find.widgetWithText(TextField, 'Mã nhân viên');
Finder passwordField() => find.widgetWithText(TextField, 'Mật khẩu nhân viên');

/// Types the test staff ID and password into the dialog.
Future<void> typeCreds(WidgetTester tester) async {
  await tester.enterText(idField(), staffId);
  await tester.enterText(passwordField(), token);
}

final csv = [0xEF, 0xBB, 0xBF, ...'sep=;\r\n'.codeUnits];

void main() {
  setUp(StaffCredentialsHolder.instance.clear);
  tearDown(() {
    StaffCredentialsHolder.instance.clear();
    OrderRepository.instance.setOrdersForTest(const []);
  });

  group('ExportClient', () {
    late List<http.Request> sent;
    ExportClient answering(Future<http.Response> Function() respond) {
      sent = [];
      return ExportClient(
        client: MockClient((r) {
          sent.add(r);
          return respond();
        }),
      );
    }

    test('GETs /api/orders/export?month= with the staff ID and password in headers', () async {
      final api = answering(() async => http.Response.bytes(csv, 200));

      final bytes = await api.fetchMonth('2026-11', credentials: creds);

      expect(bytes, csv);
      final r = sent.single;
      expect(r.method, 'GET');
      expect(r.url.path, '/api/orders/export');
      expect(r.url.queryParameters, {'month': '2026-11'});
      expect(r.headers['X-Staff-Id'], staffId);
      expect(r.headers['X-Staff-Password'], token);
      expect(r.headers.containsKey('X-Staff-Token'), isFalse);
      expect(r.url.toString(), isNot(contains(token)));
    });

    for (final (report, query) in [
      (ExportReport.lines, {'month': '2026-11'}),
      (ExportReport.summary, {'month': '2026-11', 'report': 'summary'}),
      (ExportReport.detail, {'month': '2026-11', 'report': 'detail'}),
    ]) {
      test(
        '${report.name}: exact path and query, staff headers only',
        () async {
          final api = answering(() async => http.Response.bytes(csv, 200));
          await api.fetchMonth('2026-11', report: report, credentials: creds);
          final r = sent.single;
          expect(r.url.path, '/api/orders/export');
          expect(r.url.queryParameters, query);
          expect(r.headers['X-Staff-Id'], staffId);
          expect(r.headers['X-Staff-Password'], token);
          expect(r.url.toString(), isNot(contains(token)));
          expect(r.url.toString(), isNot(contains(staffId)));
        },
      );
    }

    test('a month that is not YYYY-MM is refused without sending', () {
      final api = answering(() async => http.Response.bytes(csv, 200));
      for (final bad in ['2026-13', '2026-1', '../x', '']) {
        expect(
          () => api.fetchMonth(bad, credentials: creds),
          throwsArgumentError,
        );
      }
      expect(sent, isEmpty);
    });

    for (final (status, failure) in [
      (401, ExportFailure.wrongCredentials),
      (429, ExportFailure.tooManyTries),
      (403, ExportFailure.disabled),
      (503, ExportFailure.notConfigured),
      (400, ExportFailure.other),
      (500, ExportFailure.other),
    ]) {
      test(
        '$status -> ${failure.name}, credentials never in the error',
        () async {
          final api = answering(
            () async => http.Response('text $token', status),
          );
          try {
            await api.fetchMonth('2026-11', credentials: creds);
            fail('should throw');
          } on ExportException catch (e) {
            expect(e.failure, failure);
            expect(e.statusCode, status);
            expect(e.toString(), isNot(contains(token)));
            expect(e.toString(), isNot(contains(staffId)));
          }
        },
      );
    }

    test('429 carries the Retry-After seconds, or null without one', () async {
      Future<ExportException> failWith(Map<String, String> headers) async {
        final api = answering(
          () async => http.Response('locked', 429, headers: headers),
        );
        try {
          await api.fetchMonth('2026-11', credentials: creds);
        } on ExportException catch (e) {
          return e;
        }
        throw StateError('should throw');
      }

      final withHeader = await failWith({'retry-after': '42'});
      expect(withHeader.failure, ExportFailure.tooManyTries);
      expect(withHeader.retryAfterSeconds, 42);
      expect((await failWith({})).retryAfterSeconds, isNull);
      // Nonsense values aren't shown to staff.
      for (final bad in ['-5', '0', '99999', 'soon']) {
        expect(
          (await failWith({'retry-after': bad})).retryAfterSeconds,
          isNull,
        );
      }
    });

    test('no answer -> other, no status', () async {
      final api = answering(() async => throw http.ClientException('refused'));
      await expectLater(
        api.fetchMonth('2026-11', credentials: creds),
        throwsA(
          isA<ExportException>()
              .having((e) => e.failure, 'failure', ExportFailure.other)
              .having((e) => e.statusCode, 'statusCode', isNull),
        ),
      );
    });
  });

  test('recentMonths: 12 months, newest first, across a year end', () {
    final months = recentMonths(DateTime(2026, 2, 15));
    expect(months, hasLength(12));
    expect(months.first, '2026-02');
    expect(months[1], '2026-01');
    expect(months[2], '2025-12');
    expect(months.last, '2025-03');
  });

  group('Export month dialog', () {
    late List<(List<int>, String, String)> saved;
    late List<http.Request> requests;

    Future<void> openDialog(
      WidgetTester tester,
      Future<http.Response> Function(http.Request) respond, {
      double width = 800,
      double textScale = 1.0,
    }) async {
      saved = [];
      requests = [];
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
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showExportMonthDialog(
                    context,
                    client: ExportClient(
                      client: MockClient((r) {
                        requests.add(r);
                        return respond(r);
                      }),
                    ),
                    saveFile: (bytes, name, type) =>
                        saved.add((bytes, name, type)),
                    now: DateTime(2026, 11, 19),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    /// Opens the "Loại báo cáo" dropdown and picks [label].
    Future<void> pickReport(WidgetTester tester, String label) async {
      await tester.tap(find.text('Báo cáo tổng hợp theo ngày (Excel)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Finder downloadButton() => find.widgetWithText(FilledButton, 'Tải xuống');

    testWidgets('12 months, newest first, current month selected', (
      tester,
    ) async {
      await openDialog(tester, (_) async => http.Response.bytes(csv, 200));

      expect(find.text('2026-11'), findsOneWidget);
      await tester.tap(find.text('2026-11'));
      await tester.pumpAndSettle();
      final items = tester
          .widgetList<DropdownMenuItem<String>>(
            find.byType(DropdownMenuItem<String>),
          )
          .map((i) => i.value)
          .toSet()
          .toList();
      expect(items, recentMonths(DateTime(2026, 11, 19)));
      // A month that isn't selected appears once, in the open list.
      expect(find.text('2026-10'), findsOneWidget);
    });

    testWidgets('Download is disabled until both ID and password are typed', (
      tester,
    ) async {
      await openDialog(tester, (_) async => http.Response.bytes(csv, 200));
      expect(tester.widget<FilledButton>(downloadButton()).onPressed, isNull);

      await tester.enterText(idField(), staffId);
      await tester.pump();
      expect(tester.widget<FilledButton>(downloadButton()).onPressed, isNull);

      await tester.enterText(passwordField(), token);
      await tester.pump();
      expect(
        tester.widget<FilledButton>(downloadButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('download: one request for the chosen month, file saved, '
        'dialog closes, ID and password remembered', (tester) async {
      await openDialog(tester, (_) async => http.Response.bytes(csv, 200));
      await tester.tap(find.text('2026-11'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-09').last);
      await tester.pumpAndSettle();
      await pickReport(tester, 'Danh sách dòng món (CSV)');
      await typeCreds(tester);
      await tester.pump();
      await tester.tap(downloadButton());
      await tester.pumpAndSettle();

      expect(requests.single.url.queryParameters, {'month': '2026-09'});
      expect(saved.single.$1, csv);
      expect(saved.single.$2, 'orders-2026-09.csv');
      expect(saved.single.$3, startsWith('text/csv'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(StaffCredentialsHolder.instance.value?.id, staffId);
      expect(StaffCredentialsHolder.instance.value?.password, token);

      // A second export in the same session: both are already there.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(downloadButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('the report choice defaults to the summary', (tester) async {
      await openDialog(tester, (_) async => http.Response.bytes(csv, 200));
      expect(find.text('Loại báo cáo'), findsOneWidget);
      expect(find.text('Báo cáo tổng hợp theo ngày (Excel)'), findsOneWidget);
      await typeCreds(tester);
      await tester.pump();
      await tester.tap(downloadButton());
      await tester.pumpAndSettle();
      expect(requests.single.url.queryParameters['report'], 'summary');
      expect(saved.single.$2, 'bao-cao-tong-hop-2026-11.xlsx');
    });

    for (final (label, report, name, mime) in [
      (
        'Báo cáo tổng hợp theo ngày (Excel)',
        'summary',
        'bao-cao-tong-hop-2026-11.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
      (
        'Chi tiết từng đơn trong tháng (Excel)',
        'detail',
        'chi-tiet-2026-11.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
      (
        'Danh sách dòng món (CSV)',
        null,
        'orders-2026-11.csv',
        'text/csv;charset=utf-8',
      ),
    ]) {
      testWidgets('choice "$label" downloads once as $name', (tester) async {
        await openDialog(tester, (_) async => http.Response.bytes(csv, 200));
        await pickReport(tester, label);
        await typeCreds(tester);
        await tester.pump();
        await tester.tap(downloadButton());
        await tester.pumpAndSettle();

        expect(requests, hasLength(1));
        expect(requests.single.url.queryParameters['report'], report);
        expect(saved, hasLength(1));
        expect(saved.single.$2, name);
        expect(saved.single.$3, mime);
        expect(find.byType(AlertDialog), findsNothing);
      });
    }

    testWidgets('503 shows the fixed text, stays open and usable', (
      tester,
    ) async {
      await openDialog(tester, (_) async => http.Response('x', 503));
      await typeCreds(tester);
      await tester.pump();
      await tester.tap(downloadButton());
      await tester.pumpAndSettle();

      expect(
        find.text('Chưa cài đặt thông tin quán trên máy chủ'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(saved, isEmpty);
      expect(
        tester.widget<FilledButton>(downloadButton()).onPressed,
        isNotNull,
      );
      // The CSV needs no shop settings; it can be chosen next.
      expect(
        tester
            .widget<DropdownButtonFormField<ExportReport>>(
              find.byType(DropdownButtonFormField<ExportReport>),
            )
            .onChanged,
        isNotNull,
      );
    });

    testWidgets('both dropdowns are disabled while downloading', (
      tester,
    ) async {
      final gate = Completer<http.Response>();
      await openDialog(tester, (_) => gate.future);
      await typeCreds(tester);
      await tester.pump();
      await tester.tap(downloadButton());
      await tester.pump();

      expect(
        tester
            .widget<DropdownButtonFormField<ExportReport>>(
              find.byType(DropdownButtonFormField<ExportReport>),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .onChanged,
        isNull,
      );
      gate.complete(http.Response.bytes(csv, 200));
      await tester.pumpAndSettle();
    });

    for (final (status, message) in [
      (403, 'Chức năng xuất dữ liệu đang tắt trên máy chủ'),
      (500, 'Không thể xuất dữ liệu. Thử lại.'),
      (400, 'Không thể xuất dữ liệu. Thử lại.'),
    ]) {
      testWidgets('$status shows "$message" and stays open', (tester) async {
        await openDialog(tester, (_) async => http.Response('x', status));
        await typeCreds(tester);
        await tester.pump();
        await tester.tap(downloadButton());
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(saved, isEmpty);
      });
    }

    testWidgets('401 shows "Sai mã nhân viên hoặc mật khẩu" and forgets both', (
      tester,
    ) async {
      StaffCredentialsHolder.instance.value = const StaffCredentials(
        id: 'old-staff',
        password: 'old-password-123',
      );
      await openDialog(tester, (_) async => http.Response('x', 401));
      String text(Finder f) => tester.widget<TextField>(f).controller!.text;
      expect(text(idField()), 'old-staff');
      expect(text(passwordField()), 'old-password-123');

      await tester.tap(downloadButton());
      await tester.pumpAndSettle();

      expect(find.text('Sai mã nhân viên hoặc mật khẩu'), findsOneWidget);
      expect(StaffCredentialsHolder.instance.value, isNull);
      expect(text(idField()), isEmpty);
      expect(text(passwordField()), isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('429 says to wait, with the seconds from Retry-After', (
      tester,
    ) async {
      await openDialog(
        tester,
        (_) async => http.Response('x', 429, headers: {'retry-after': '37'}),
      );
      await typeCreds(tester);
      await tester.pump();
      await tester.tap(downloadButton());
      await tester.pumpAndSettle();

      expect(
        find.text('Thử sai quá nhiều lần. Thử lại sau 37 giây.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('accented characters are refused before sending', (
      tester,
    ) async {
      await openDialog(tester, (_) async => http.Response.bytes(csv, 200));
      await tester.enterText(idField(), 'nhân-viên');
      await tester.enterText(passwordField(), token);
      await tester.pump();
      await tester.tap(downloadButton());
      await tester.pumpAndSettle();

      expect(
        find.text('Chỉ dùng chữ không dấu, số và ký hiệu thông thường'),
        findsOneWidget,
      );
      expect(requests, isEmpty);
    });

    testWidgets('429 without Retry-After says to try again later', (
      tester,
    ) async {
      await openDialog(tester, (_) async => http.Response('x', 429));
      await typeCreds(tester);
      await tester.pump();
      await tester.tap(downloadButton());
      await tester.pumpAndSettle();

      expect(
        find.text('Thử sai quá nhiều lần. Vui lòng thử lại sau.'),
        findsOneWidget,
      );
    });

    // Checks the messages and labels only: what's typed lives in the
    // fields' controllers, and the password field is checked as obscured
    // in its own test.
    for (final status in [401, 403, 429, 500]) {
      testWidgets('after HTTP $status no message shows the ID or password', (
        tester,
      ) async {
        await openDialog(tester, (_) async => http.Response('x', status));
        await typeCreds(tester);
        await tester.pump();
        await tester.tap(downloadButton());
        await tester.pumpAndSettle();

        final shown = [
          for (final t in tester.widgetList<RichText>(find.byType(RichText)))
            t.text.toPlainText(),
        ].join(' ');
        expect(shown, contains('Tải xuống'));
        expect(shown, isNot(contains(token)));
        expect(shown, isNot(contains(staffId)));
      });
    }

    testWidgets('Cancel and tapping outside send nothing', (tester) async {
      await openDialog(tester, (_) async => http.Response.bytes(csv, 200));
      await typeCreds(tester);
      await tester.pump();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(requests, isEmpty);
      expect(saved, isEmpty);
      expect(StaffCredentialsHolder.instance.value, isNull);
    });

    testWidgets('a failing browser download shows the error, not a stuck '
        'dialog', (tester) async {
      await tester.pumpWidget(
        l10nApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showExportMonthDialog(
                  context,
                  client: ExportClient(
                    client: MockClient(
                      (_) async => http.Response.bytes(csv, 200),
                    ),
                  ),
                  saveFile: (_, _, _) => throw UnsupportedError('no browser'),
                  now: DateTime(2026, 11, 19),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await typeCreds(tester);
      await tester.pump();
      await tester.tap(downloadButton());
      await tester.pumpAndSettle();

      expect(find.text('Không thể xuất dữ liệu. Thử lại.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(downloadButton()).onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Hủy'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
      'the password is hidden, the ID is not, and neither autofills',
      (tester) async {
        await openDialog(tester, (_) async => http.Response.bytes(csv, 200));
        final id = tester.widget<TextField>(idField());
        final password = tester.widget<TextField>(passwordField());
        expect(password.obscureText, isTrue);
        expect(id.obscureText, isFalse);
        expect(id.autofillHints, isEmpty);
        expect(password.autofillHints, isEmpty);
      },
    );

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('fits at 360 px (text x$scale), also with an error', (
        tester,
      ) async {
        await openDialog(
          tester,
          (_) async => http.Response('x', 403),
          width: 360,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await typeCreds(tester);
        await tester.pump();
        await tester.ensureVisible(downloadButton());
        await tester.tap(downloadButton());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Chức năng xuất dữ liệu đang tắt trên máy chủ'),
          findsOneWidget,
        );
      });
    }
  });

  testWidgets('the orders page has an "Export month" button that opens it', (
    tester,
  ) async {
    OrderRepository.instance.setOrdersForTest(const []);
    await tester.pumpWidget(l10nApp(home: const OrdersPage()));

    await tester.tap(find.byTooltip('Xuất đơn hàng theo tháng'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(AlertDialog, 'Xuất đơn hàng theo tháng'),
      findsOneWidget,
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
  });
}
