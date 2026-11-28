import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'orders_export.dart';
import 'orders_report.dart';
import 'report_detail.dart';
import 'report_summary.dart';
import 'shop_settings.dart';
import 'staff_gate.dart';
import 'vietqr.dart';

/// The orders API: routes plus the storage behind them.
///
/// Orders live in the SQLite [Database] passed in (see `database.dart`), so
/// they survive a restart. Tests pass an in-memory database per test.
/// `bin/server.dart` creates exactly one instance.
///
/// Serves the order routes (list, create, change status), the payment routes
/// (switch to cash, renew, confirm, QR, bank info), the staff month export
/// and the live `/orders/stream`. Every change to an order is also sent to
/// all stream clients. Lifecycle: [startExpirySweep] opens a timer and
/// [close] stops it and closes the stream.
class OrdersApi {
  /// [maxStoredOrders] is for tests; the server uses the default. Without a
  /// [staffGate] the staff-only routes (month export, staff switch to cash,
  /// confirm payment) answer 403 (fail closed).
  /// Without [shopSettings] bank transfer counts as not set up (fail closed).
  /// [now] is the server clock used for `paymentDueAt`; tests inject one.
  OrdersApi(
    this._db, {
    this.maxStoredOrders = defaultMaxStoredOrders,
    StaffGate? staffGate,
    ShopSettings? shopSettings,
    DateTime Function()? now,
  }) : _gate = staffGate ?? StaffGate(),
       _settings = shopSettings ?? ShopSettings({}),
       _now = now ?? DateTime.now;

  /// Bank details; bank transfer orders need [ShopSettings.transferEnabled].
  final ShopSettings _settings;

  /// The server's own clock (never the client's).
  final DateTime Function() _now;

  /// Guards the staff-only routes (the month export, `staff-switch-to-cash`
  /// and `confirm-payment`).
  final StaffGate _gate;

  /// New orders are refused (503) once this many are stored, so a flood of
  /// POSTs can't fill the disk. Old orders are never deleted automatically.
  final int maxStoredOrders;

  /// Shared with `MenuApi`. Whoever opened it closes it — not this class.
  final Database _db;

  /// Fan-out channel for live order updates. Every connected SSE client
  /// subscribes to this stream and gets a copy of each mutation.
  final StreamController<Map<String, dynamic>> _events =
      StreamController.broadcast();

  /// The shelf handler for the order and payment routes (`/orders...` and
  /// `/payment-info`), with CORS applied. Built on first use.
  /// Request logging is left to the caller (`bin/server.dart`).
  late final Handler handler = _buildHandler();

  /// The repeating expiry timer; null until [startExpirySweep] and after
  /// [close].
  Timer? _sweepTimer;

  /// Set by [close]; stops any sweep tick that is still pending.
  bool _closed = false;

  /// Starts the periodic expiry sweep (see [expireOverdue]). Safe to call
  /// twice. `bin/server.dart` calls it; [close] cancels it. It is not started
  /// by the constructor, so a test that never calls it leaves no timer behind.
  void startExpirySweep({Duration interval = expirySweepInterval}) {
    if (_closed || _sweepTimer != null) return;
    _sweepTimer = Timer.periodic(interval, (_) {
      if (_closed) return;
      try {
        expireOverdue();
      } on Object {
        // Never let one failed sweep kill the server; the next tick retries.
        stderr.writeln('expiry sweep failed');
      }
    });
  }

  /// Cancels the sweep timer and closes the event stream. Open SSE
  /// connections stop receiving events. The database stays open; its opener
  /// closes it.
  Future<void> close() {
    _closed = true;
    _sweepTimer?.cancel();
    _sweepTimer = null;
    return _events.close();
  }

  /// Cancels every `awaiting_payment` bank transfer order whose deadline is
  /// at or before the server clock, and publishes each on the stream.
  /// `paymentDueAt` is kept: it marks "cancelled by expiry" and starts the
  /// renew window. Returns how many orders were cancelled.
  int expireOverdue() {
    // Only the id and the deadline: the items are never decoded here, so one
    // malformed stored row can't stop the others from expiring.
    final rows = _db.select(
      'SELECT id, payment_due_at FROM orders WHERE status = ? '
      'AND payment_method = ?',
      [statusAwaitingPayment, paymentBankTransfer],
    );
    var count = 0;
    for (final row in rows) {
      final id = row['id'] as String;
      try {
        if (_cancelIfOverdue(id, row['payment_due_at'])) count++;
      } on Object {
        // Fixed message; the id is JSON-quoted so it can't forge a log line.
        stderr.writeln('expiry sweep: order ${jsonEncode(id)} failed');
      }
    }
    return count;
  }

  /// The conditional cancel behind both the sweep and the lazy check. [due]
  /// is the deadline as read; the write only matches that exact state.
  /// Publishes the full order only when a row changed.
  bool _cancelIfOverdue(String id, Object? due) {
    final deadline = _parseDue(due);
    if (deadline == null || deadline.isAfter(_now())) return false;
    _db.execute(
      'UPDATE orders SET status = ? WHERE id = ? AND status = ? '
      'AND payment_method = ? AND payment_due_at = ?',
      [statusCancelled, id, statusAwaitingPayment, paymentBankTransfer, due],
    );
    if (_db.updatedRows == 0) return false;
    try {
      _events.add(_findOrder(id)!);
    } on Object {
      stderr.writeln('expiry sweep: order ${jsonEncode(id)} not published');
    }
    return true;
  }

  /// Lazy check at the start of a payment route: cancels this one order if it
  /// is an overdue `awaiting_payment` transfer order, like the sweep does.
  void _expireIfOverdue(String id) {
    final rows = _db.select(
      'SELECT payment_due_at FROM orders WHERE id = ? AND status = ? '
      'AND payment_method = ?',
      [id, statusAwaitingPayment, paymentBankTransfer],
    );
    if (rows.isEmpty) return;
    _cancelIfOverdue(id, rows.first['payment_due_at']);
  }

  /// The deadline as an instant, or null when absent or unreadable.
  DateTime? _parseDue(Object? due) =>
      due is String ? DateTime.tryParse(due) : null;

  /// Cancelled by the expiry: a `bank_transfer` order that is `cancelled`
  /// and still has its deadline (a staff cancel clears it).
  bool _isExpired(Map<String, dynamic> o) =>
      o['status'] == statusCancelled &&
      o['paymentMethod'] == paymentBankTransfer &&
      o['paymentDueAt'] != null;

  /// Expired and still inside the customer's renew window.
  bool _inRenewWindow(Map<String, dynamic> o) {
    final due = _parseDue(o['paymentDueAt']);
    return _isExpired(o) &&
        due != null &&
        !_now().isAfter(due.add(renewWindow));
  }

  /// A `bank_transfer` order still in `awaiting_payment`. The routes call
  /// [_expireIfOverdue] first, so an overdue one is already cancelled.
  bool _isLiveAwaiting(Map<String, dynamic> o) =>
      o['status'] == statusAwaitingPayment &&
      o['paymentMethod'] == paymentBankTransfer;

  /// Makes [order] a cash order in `preparing`, conditional on the state it
  /// was read in. Null when no row matched (someone got there first).
  Map<String, dynamic>? _switchToCash(Map<String, dynamic> order) {
    final id = order['id'] as String;
    _db.execute(
      'UPDATE orders SET payment_method = ?, payment_due_at = NULL, '
      'status = ? WHERE id = ? AND status = ? AND payment_method = ? '
      'AND payment_due_at IS ?',
      [
        paymentCash,
        'preparing',
        id,
        order['status'],
        paymentBankTransfer,
        order['paymentDueAt'],
      ],
    );
    return _publishIfChanged(id);
  }

  /// After a conditional UPDATE: null when no row changed, otherwise sends
  /// the updated order to the stream and returns it.
  Map<String, dynamic>? _publishIfChanged(String id) {
    if (_db.updatedRows == 0) return null;
    final updated = _findOrder(id)!;
    _events.add(updated);
    return updated;
  }

  /// The shared 409 reply of the payment routes (fixed text, no request data).
  Response _conflict() =>
      Response(409, body: 'The order is not in a state that allows this');

  /// Shared body of the two switch routes: 200 the order now in cash and
  /// `preparing`, 404 unknown id, 409 not allowed. A live `awaiting_payment`
  /// order always qualifies; an expired one only for [staff] (no time limit)
  /// or, for the customer, inside the renew window. Nothing here awaits, so no
  /// other request runs between the read and the write.
  Response _switchRoute(String id, {required bool staff}) {
    _expireIfOverdue(id);
    final order = _findOrder(id);
    if (order == null) return Response.notFound('Order not found');
    final allowed =
        _isLiveAwaiting(order) ||
        (staff ? _isExpired(order) : _inRenewWindow(order));
    if (!allowed) return _conflict();
    final updated = _switchToCash(order);
    return updated == null ? _conflict() : _json(updated);
  }

  /// Creates the router with every route below and wraps it with CORS.
  /// Routes are registered here, in the order they are matched.
  Handler _buildHandler() {
    final router = Router();

    // GET /orders/export (staff only): one month of orders as a CSV file for
    // Excel, or with `report=summary|detail` an xlsx report of the finished
    // orders. Checked in this order: staff ID and password (403 staff routes
    // disabled, 401 wrong, 429 locked), `month` = YYYY-MM (400), `report`
    // (400 for anything but absent, `summary` or `detail`; the old `format`
    // parameter is refused too), the summary report being set up (503), and
    // only then is anything read. A stored order that can't be read gives 500
    // with a fixed message. 200 = the file. Reads only; the file holds
    // customer names, so it is never cached and its content never logged.
    router.get('/orders/export', (Request req) {
      final denied = _gate.check(req);
      if (denied != null) return denied;

      final String? month;
      try {
        month = req.url.queryParameters['month'];
      } on ArgumentError {
        // A broken `%` escape in the query.
        return Response.badRequest(body: 'month must be YYYY-MM');
      } on FormatException {
        return Response.badRequest(body: 'month must be YYYY-MM');
      }
      if (month == null || !isValidMonth(month)) {
        return Response.badRequest(body: 'month must be YYYY-MM');
      }

      // `report`: absent = the CSV; `summary` / `detail` = an xlsx report.
      // Anything else (empty, repeated, other names) is refused.
      final String? report;
      try {
        // The first draft of this route used `format=xlsx`; it is refused,
        // not silently answered with a CSV.
        if (req.url.queryParametersAll.containsKey('format')) {
          return Response.badRequest(body: 'report must be summary or detail');
        }
        final all = req.url.queryParametersAll['report'];
        if (all == null) {
          report = null;
        } else if (all.length == 1 &&
            (all.first == 'summary' || all.first == 'detail')) {
          report = all.first;
        } else {
          return Response.badRequest(body: 'report must be summary or detail');
        }
      } on ArgumentError {
        return Response.badRequest(body: 'report must be summary or detail');
      } on FormatException {
        return Response.badRequest(body: 'report must be summary or detail');
      }
      if (report == 'summary' && !_settings.reportEnabled) {
        return Response(503, body: 'The summary report is not set up');
      }

      // Only this month's rows; `placed_at` starts with "YYYY-MM-".
      final rows = _db.select(
        'SELECT * FROM orders WHERE substr(placed_at, 1, 8) = ? '
        'ORDER BY rowid',
        ['$month-'],
      );
      final lines = <List<Object>>[];
      final orders = <Map<String, dynamic>>[];
      for (final row in rows) {
        try {
          orders.add(_orderFromRow(row));
        } on FormatException {
          return _exportFailed(row['id']);
        } on TypeError {
          return _exportFailed(row['id']);
        }
      }
      if (report != null) {
        final finished = <ReportOrder>[];
        for (final order in ordersInMonth(orders, month)) {
          try {
            finished.addAll(finishedOrders([order], month));
          } on TypeError {
            return _exportFailed(order['id']);
          }
        }
        final List<int> bytes;
        final String fileName;
        if (report == 'summary') {
          bytes = buildSummaryReport(
            shop: _settings,
            month: month,
            days: dailyTotals(finished, month),
          );
          fileName = 'bao-cao-tong-hop-$month.xlsx';
        } else {
          bytes = buildDetailReport(
            month: month,
            days: daysWithOrders(finished, month),
          );
          fileName = 'chi-tiet-$month.xlsx';
        }
        return Response.ok(
          bytes,
          headers: {
            'content-type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            // Fixed prefix plus the validated month: plain ASCII.
            'content-disposition': 'attachment; filename="$fileName"',
            'cache-control': 'no-store',
          },
        );
      }
      for (final order in ordersInMonth(orders, month)) {
        try {
          lines.addAll(exportRows([order]));
        } on TypeError {
          return _exportFailed(order['id']);
        }
      }
      return Response.ok(
        csvBytes(lines),
        headers: {
          'content-type': 'text/csv; charset=utf-8',
          // Built only from the validated month.
          'content-disposition': 'attachment; filename="orders-$month.csv"',
          'cache-control': 'no-store',
        },
      );
    });

    // GET /orders: 200 with the newest orders first. Newest first = most
    // recently inserted first. `rowid` grows with every insert; `placed_at` is client-supplied, so it isn't used for ordering.
    // Only the newest [maxOrdersReturned]: the response stays small however
    // many orders pile up.
    router.get('/orders', (Request req) {
      final rows = _db.select(
        'SELECT * FROM orders ORDER BY rowid DESC LIMIT ?',
        [maxOrdersReturned],
      );
      return _json(rows.map(_orderFromRow).toList());
    });

    // POST /orders: place a new order. Answers 200 with the stored order
    // (including `paymentMethod` and `paymentDueAt`), 400 for a body that is
    // not a JSON object or breaks the rules in [_orderProblem], 503 for a
    // bank transfer while bank details aren't set up, 409 for a duplicate id,
    // 503 when [maxStoredOrders] are stored. The order is sent to the stream.
    // The client still assigns the id (a millisecond timestamp). We only
    // refuse duplicates; generating ids server-side is a later contract change.
    router.post('/orders', (Request req) async {
      final body = await _readJsonObject(req);
      if (body == null) return _badRequest();
      final problem = _orderProblem(body);
      if (problem != null) return Response.badRequest(body: problem);
      final method = body['paymentMethod'] ?? paymentCash;
      if (method == paymentBankTransfer && !_settings.transferEnabled) {
        return Response(503, body: 'Bank transfer is not set up');
      }
      if (_findOrder(body['id'] as String) != null) {
        return Response(409, body: 'An order with this id already exists');
      }
      final count = _db.select('SELECT COUNT(*) AS n FROM orders').first['n'];
      if ((count as int) >= maxStoredOrders) {
        return Response(503, body: 'Order storage is full');
      }
      // Always `?` placeholders: request data is never pasted into SQL text.
      // The server sets the deadline from its own clock; a client can't.
      final dueAt = method == paymentBankTransfer ? _deadline() : null;
      _db.execute(
        'INSERT INTO orders (id, customer_name, status, placed_at, items_json, '
        'payment_method, payment_due_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          body['id'],
          body['customerName'],
          body['status'],
          body['placedAt'],
          jsonEncode(body['items']),
          method,
          dueAt,
        ],
      );
      final stored = _findOrder(body['id'] as String)!;
      _events.add(stored);
      return _json(stored);
    });

    // PATCH /orders/{id} (staff only): change the status. The staff check
    // comes first, before the body is read and before the lookup (401 / 403 /
    // 429). Then 400 when `status` is missing or not a known status (or the
    // body is not a JSON object), 404 unknown id, 409 by the rules below, 200
    // the updated order. A changed order is sent to the stream.
    // Only `status` can change (and `paymentDueAt` is cleared by a change);
    // any other field in the body is ignored, and the payment method is never
    // touched.
    router.patch('/orders/<id>', (Request req, String id) async {
      final denied = _gate.check(req);
      if (denied != null) return denied;
      final body = await _readJsonObject(req);
      if (body == null) return _badRequest();
      final status = body['status'];
      if (status is! String || !orderStatuses.contains(status)) {
        return Response.badRequest(body: 'status must be a known order status');
      }
      final current = _findOrder(id);
      if (current == null) return Response.notFound('Order not found');
      final from = current['status'] as String;
      final isTransfer = current['paymentMethod'] == paymentBankTransfer;

      // Same status: nothing changes, and this wins over the rules below.
      // One exception: cancelled -> cancelled on an order that still has its
      // deadline (cancelled by the expiry) is a real staff cancel that ends
      // the customer's renew / switch-to-cash window by clearing it.
      if (status == from) {
        if (from == statusCancelled && current['paymentDueAt'] != null) {
          _db.execute(
            'UPDATE orders SET payment_due_at = NULL '
            'WHERE id = ? AND status = ?',
            [id, statusCancelled],
          );
          final updated = _publishIfChanged(id);
          return updated == null ? _conflict() : _json(updated);
        }
        return _json(current);
      }
      // A cancelled order of any kind is final.
      if (from == statusCancelled) {
        return Response(
          409,
          body: isTransfer
              ? 'Use the payment routes'
              : "A cancelled order can't be changed",
        );
      }
      // `awaiting_payment` is reached by a bank transfer order only through
      // POST. A cash order may be put there by staff; it stays cash.
      if (status == statusAwaitingPayment && isTransfer) {
        return Response(409, body: 'Use the payment routes');
      }
      // One guarded write: only if the status is still the one just read. A
      // change always clears the deadline; the method is never written.
      _db.execute(
        'UPDATE orders SET status = ?, payment_due_at = NULL '
        'WHERE id = ? AND status = ?',
        [status, id, from],
      );
      final updated = _publishIfChanged(id);
      return updated == null ? _conflict() : _json(updated);
    });

    // POST /orders/{id}/switch-to-cash (customer, no staff ID): switch an
    // unpaid, or expired within 15 minutes of its deadline, transfer order to
    // cash. 200 the order, 404 unknown id, 409 any other state.
    router.post('/orders/<id>/switch-to-cash', (Request req, String id) {
      return _switchRoute(id, staff: false);
    });

    // POST /orders/{id}/staff-switch-to-cash (staff only): like the customer
    // switch but an expired order has no time limit. 200, 401 / 403 / 429
    // from the staff check (made before any lookup), 404, 409.
    router.post('/orders/<id>/staff-switch-to-cash', (Request req, String id) {
      final denied = _gate.check(req);
      if (denied != null) return denied;
      return _switchRoute(id, staff: true);
    });

    // POST /orders/{id}/renew-payment (customer, no staff ID): a fresh
    // 5-minute deadline for an order that expired within the last 15 minutes;
    // it goes back to `awaiting_payment` and stays a transfer order. 200 the
    // order, 404, 409 not renewable (or someone else changed it first), 503
    // bank transfer not set up.
    router.post('/orders/<id>/renew-payment', (Request req, String id) {
      _expireIfOverdue(id);
      final order = _findOrder(id);
      if (order == null) return Response.notFound('Order not found');
      if (!_inRenewWindow(order)) return _conflict();
      if (!_settings.transferEnabled) {
        return Response(503, body: 'Bank transfer is not set up');
      }
      _db.execute(
        'UPDATE orders SET status = ?, payment_due_at = ? WHERE id = ? '
        'AND status = ? AND payment_method = ? AND payment_due_at = ?',
        [
          statusAwaitingPayment,
          _deadline(),
          id,
          statusCancelled,
          paymentBankTransfer,
          order['paymentDueAt'],
        ],
      );
      final updated = _publishIfChanged(id);
      return updated == null ? _conflict() : _json(updated);
    });

    // POST /orders/{id}/confirm-payment (staff only): the money arrived, so a
    // live `awaiting_payment` transfer order becomes `preparing` and loses its
    // deadline. 200 the order, 401 / 403 / 429 from the staff check, 404, 409
    // otherwise. A cancelled (expired) order is refused.
    router.post('/orders/<id>/confirm-payment', (Request req, String id) {
      final denied = _gate.check(req);
      if (denied != null) return denied;
      _expireIfOverdue(id);
      final order = _findOrder(id);
      if (order == null) return Response.notFound('Order not found');
      if (!_isLiveAwaiting(order)) return _conflict();
      _db.execute(
        'UPDATE orders SET status = ?, payment_due_at = NULL WHERE id = ? '
        'AND status = ? AND payment_method = ? AND payment_due_at IS ?',
        [
          'preparing',
          id,
          statusAwaitingPayment,
          paymentBankTransfer,
          order['paymentDueAt'],
        ],
      );
      final updated = _publishIfChanged(id);
      return updated == null ? _conflict() : _json(updated);
    });

    // GET /payment-info (public): 200 with whether bank transfer is set up
    // and, when it is, which account to show next to the QR. Never cached.
    // Values come from ShopSettings only; nothing from the request.
    router.get('/payment-info', (Request req) {
      final s = _settings;
      return _noStoreJson({
        'transferEnabled': s.transferEnabled,
        if (s.transferEnabled) ...{
          'bankName': s.bankName,
          'accountNumber': s.bankAccount,
          'accountName': s.bankAccountName,
        },
      });
    });

    // GET /orders/{id}/payment-qr (public): the QR text for a live transfer
    // order. 200 `{payload, amount, reference, dueAt, bank details}` (never
    // cached), 404 unknown id, 409 not payable (not a live `awaiting_payment`
    // transfer order, past its deadline, or a total that isn't whole VND
    // above 0), 503 bank transfer not set up, 500 a stored order is
    // malformed. The amount is computed
    // from the stored items only, so it equals what the restaurant sees (also
    // after a renewal); the request carries nothing but the id.
    router.get('/orders/<id>/payment-qr', (Request req, String id) {
      // This GET can write: the lazy expiry cancels an already-overdue order,
      // the same as the sweep does.
      _expireIfOverdue(id);
      final Map<String, dynamic>? order;
      try {
        order = _findOrder(id);
      } on FormatException {
        return _qrFailed(id);
      } on TypeError {
        return _qrFailed(id);
      }
      if (order == null) return Response.notFound('Order not found');
      final due = _parseDue(order['paymentDueAt']);
      if (!_isLiveAwaiting(order) || due == null || !due.isAfter(_now())) {
        return _conflict();
      }
      if (!_settings.transferEnabled) {
        return Response(503, body: 'Bank transfer is not set up');
      }
      final num total;
      try {
        total = _orderTotal(order['items'] as List);
      } on Object {
        // Any corrupt stored item (not a map, text price ...): fixed 500.
        return _qrFailed(id);
      }
      // A QR needs whole VND above 0 (POST only checks above 0).
      if (!total.isFinite || total <= 0 || total != total.truncate()) {
        return _conflict();
      }
      final amount = total.toInt();
      final reference = transferReference(id);
      return _noStoreJson({
        'payload': vietQrPayload(
          bin: _settings.bankBin!,
          account: _settings.bankAccount!,
          amount: amount,
          reference: reference,
        ),
        'amount': amount,
        'reference': reference,
        'dueAt': order['paymentDueAt'],
        'bankName': _settings.bankName,
        'accountNumber': _settings.bankAccount,
        'accountName': _settings.bankAccountName,
      });
    });

    // GET /orders/stream: 200 `text/event-stream`, one `data:` line with an
    // Order JSON per change, first a `: connected` line, then a ping line
    // every 30 seconds.
    //
    // SSE via request.hijack:
    //
    // The obvious approach — `Response.ok(controller.stream, headers: ...)` —
    // flushed headers but silently swallowed the body in our shelf setup. No
    // bytes ever reached the client, with or without Caddy in front.
    //
    // Hijacking gives us the raw socket. We write the HTTP response ourselves
    // and push `data: ...\n\n` chunks straight to the sink. Downside: hijacked
    // responses skip shelf middleware (CORS, logging), so we embed the CORS
    // header inline. Logging just records the GET and a trivial duration;
    // open-connection time is not tracked.
    router.get('/orders/stream', (Request req) {
      req.hijack((channel) {
        final sink = channel.sink;

        sink.add(
          utf8.encode(
            'HTTP/1.1 200 OK\r\n'
            'Content-Type: text/event-stream\r\n'
            'Cache-Control: no-cache\r\n'
            'Connection: keep-alive\r\n'
            'X-Accel-Buffering: no\r\n'
            'Access-Control-Allow-Origin: *\r\n'
            '\r\n',
          ),
        );
        // Initial comment line so the client knows the stream is open even
        // when no orders exist yet.
        sink.add(utf8.encode(': connected\n\n'));

        final sub = _events.stream.listen((event) {
          sink.add(utf8.encode('data: ${jsonEncode(event)}\n\n'));
        });

        // Keep intermediaries (Caddy, nginx, corporate proxies) from closing
        // idle connections — a SSE "comment" line every 30s is enough.
        final pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          sink.add(utf8.encode(': ping\n\n'));
        });

        // Cleanup when the client disconnects. channel.stream completes when
        // the socket closes from either side.
        channel.stream.drain<void>().whenComplete(() {
          sub.cancel();
          pingTimer.cancel();
          sink.close();
        });
      });
    });

    return const Pipeline()
        .addMiddleware(corsHeaders())
        .addHandler(router.call);
  }

  /// Server clock + [paymentWindow], cut to whole milliseconds so the text
  /// always has 3 fractional digits and a `Z`.
  String _deadline() {
    final due = _now().toUtc().add(paymentWindow);
    return DateTime.fromMillisecondsSinceEpoch(
      due.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
  }

  /// One order in the `Order.toJson()` shape, or null for an unknown id.
  /// Throws if the stored row is malformed (e.g. broken `items_json`).
  Map<String, dynamic>? _findOrder(String id) {
    final rows = _db.select('SELECT * FROM orders WHERE id = ?', [id]);
    return rows.isEmpty ? null : _orderFromRow(rows.first);
  }
}

/// A stored order the export can't read (e.g. a price saved as text). The
/// export stops instead of silently leaving it out; only the order's id is
/// logged, never its content, and the reply is a fixed message. The id comes
/// from whoever placed the order, so it is JSON-quoted: a newline or a
/// terminal escape in it can't forge or garble a log line.
Response _exportFailed(Object? orderId) {
  stderr.writeln(
    'month export: stored order ${jsonEncode(orderId.toString())} is malformed',
  );
  return Response.internalServerError(
    body: 'Export failed: a stored order is malformed',
  );
}

/// A stored order the QR can't be built from. Fixed reply; the id (placed by
/// a client) is JSON-quoted in the log so it can't forge a line.
Response _qrFailed(String id) {
  stderr.writeln('payment qr: stored order ${jsonEncode(id)} is malformed');
  return Response.internalServerError(body: 'The payment QR could not be made');
}

/// Turns a database row back into the `Order.toJson()` shape.
Map<String, dynamic> _orderFromRow(Row row) => {
  'id': row['id'],
  'customerName': row['customer_name'],
  'items': jsonDecode(row['items_json'] as String),
  'status': row['status'],
  'placedAt': row['placed_at'],
  // NULL in the database = an order from before payment methods: cash.
  'paymentMethod': row['payment_method'] ?? paymentCash,
  'paymentDueAt': row['payment_due_at'],
};

/// Reads the request body as a JSON object. Returns null when the body is
/// not valid JSON or is valid JSON but not an object (e.g. a list or a
/// string), so the route can answer 400 instead of crashing.
Future<Map<String, dynamic>?> _readJsonObject(Request req) async {
  try {
    final decoded = jsonDecode(await req.readAsString());
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// Valid order status names. `backend/` can't import the Flutter code, so
/// this is a copy of `OrderStatus` in lib/shared/models/order.dart — keep
/// the two lists in sync. (`ready` and `delivered` no longer exist: schema
/// step 9 turned them into `preparing` and `finished`. `paid` comes with the
/// static QR work.)
const orderStatuses = {
  statusAwaitingPayment,
  'preparing',
  statusFinished,
  statusCancelled,
};

/// The status of a served order; the Excel reports count only these.
const statusFinished = 'finished';

/// The status of an unpaid order. A bank transfer order gets it only through
/// POST; staff may also put a cash order there.
const statusAwaitingPayment = 'awaiting_payment';

/// The status staff cancel to, and the expiry sweep sets.
const statusCancelled = 'cancelled';

/// Valid `paymentMethod` values.
const paymentCash = 'cash';
const paymentBankTransfer = 'bank_transfer';
const paymentMethods = {paymentCash, paymentBankTransfer};

/// How long a new (or renewed) bank transfer order may wait for payment.
const paymentWindow = Duration(minutes: 5);

/// After the deadline passes, the customer may still renew or switch to cash
/// for this long (staff have no limit).
const renewWindow = Duration(minutes: 15);

/// How often the server cancels overdue transfer orders.
const expirySweepInterval = Duration(seconds: 15);

// The exact keys allowed in a POSTed order, order line and topping. Any other
// key is refused by [_hasKeys], so a client can never send `paymentDueAt`.
const _orderRequired = {'id', 'customerName', 'items', 'status', 'placedAt'};
const _orderOptional = {'paymentMethod'};
const _itemRequired = {'name', 'quantity', 'price'};
const _itemOptional = {'id', 'toppings'};
const _toppingRequired = {'name', 'price'};
const _toppingOptional = {'id'};

/// The most toppings one order line may carry. Public so the tests can
/// check the exact boundary.
const maxToppingsPerItem = 10;

/// `GET /orders` returns at most this many orders, newest first.
const maxOrdersReturned = 500;

/// Default for [OrdersApi.maxStoredOrders].
const defaultMaxStoredOrders = 10000;

/// Longest customer, item or topping name accepted, in characters (UTF-16
/// units: a Vietnamese letter is 1, an emoji 2).
const maxNameLength = 200;

/// Longest order, item or topping id accepted. App ids are 13-digit
/// timestamps and short menu ids.
const maxIdLength = 64;

/// Most lines on one order.
const maxItemsPerOrder = 50;

/// Most of one item on one order line.
const maxQuantity = 100;

/// Highest item or topping price accepted, in VND (the same cap as menu
/// prices). Keeps `quantity × price` far from overflow.
const maxPrice = 1000000;

/// Checks that [order] has exactly the shape of `Order.toJson()` (plus the
/// optional `paymentMethod`) and obeys the limits above: id, name, status,
/// payment method, `placedAt`, line count, quantity and prices. Also that the
/// method and status agree (`cash` needs `preparing`; `bank_transfer` needs
/// `awaiting_payment` and a total above 0).
/// Returns a short message naming the first problem, or null if valid.
/// Messages are fixed strings — request data is never echoed back.
String? _orderProblem(Map<String, dynamic> order) {
  if (!_hasKeys(order, _orderRequired, _orderOptional)) {
    return 'order must have: ${_orderRequired.join(', ')}, '
        'and optionally paymentMethod';
  }
  final id = order['id'];
  if (id is! String || id.isEmpty) return 'id must be a non-empty string';
  if (id.length > maxIdLength) {
    return 'id must be at most $maxIdLength characters';
  }
  final customerName = order['customerName'];
  if (customerName is! String) return 'customerName must be a string';
  if (customerName.length > maxNameLength) {
    return 'customerName must be at most $maxNameLength characters';
  }
  final status = order['status'];
  if (status is! String || !orderStatuses.contains(status)) {
    return 'status must be a known order status';
  }
  // Absent means cash. `null` or any other value is refused.
  final Object? method = order.containsKey('paymentMethod')
      ? order['paymentMethod']
      : paymentCash;
  if (method is! String || !paymentMethods.contains(method)) {
    return 'paymentMethod must be cash or bank_transfer';
  }
  final placedAt = order['placedAt'];
  if (placedAt is! String ||
      !_isoDateTimeStart.hasMatch(placedAt) ||
      DateTime.tryParse(placedAt) == null) {
    return 'placedAt must be an ISO-8601 date-time string';
  }
  final items = order['items'];
  if (items is! List || items.isEmpty) return 'items must be a non-empty list';
  if (items.length > maxItemsPerOrder) {
    return 'an order can have at most $maxItemsPerOrder items';
  }
  for (final item in items) {
    if (item is! Map<String, dynamic> ||
        !_hasKeys(item, _itemRequired, _itemOptional) ||
        item['name'] is! String) {
      return 'each item must be {name: string, quantity: int, price: number} '
          'with optional id and toppings';
    }
    if ((item['name'] as String).length > maxNameLength) {
      return 'item name must be at most $maxNameLength characters';
    }
    // The menu item's id (TOP3). Optional until MENU-DB3 makes it required
    // and checks it against the menu.
    if (item.containsKey('id') && !_isNonEmptyString(item['id'])) {
      return 'item id must be a non-empty string of at most $maxIdLength characters';
    }
    final quantity = item['quantity'];
    if (quantity is! int || quantity < 1 || quantity > maxQuantity) {
      return 'quantity must be a whole number from 1 to $maxQuantity';
    }
    final price = item['price'];
    if (!_isValidPrice(price)) {
      return 'price must be a number from 0 to $maxPrice';
    }
    if (item.containsKey('toppings')) {
      final problem = _toppingsProblem(item['toppings']);
      if (problem != null) return problem;
    }
  }
  // Method and status must agree (the client still sends the status).
  if (method == paymentCash && status != 'preparing') {
    return 'a cash order must have status preparing';
  }
  if (method == paymentBankTransfer) {
    if (status != statusAwaitingPayment) {
      return 'a bank_transfer order must have status awaiting_payment';
    }
    if (_orderTotal(items) <= 0) {
      return 'a bank_transfer order must have a total above 0';
    }
  }
  return null;
}

/// Checks an item's `toppings`: a list of at most [maxToppingsPerItem]
/// objects, each `{name: string, price: number}` with an optional `id`.
/// `price` here is the topping's own price; the item's `price` stays the
/// base price of the dish.
String? _toppingsProblem(Object? toppings) {
  if (toppings is! List) return 'toppings must be a list';
  if (toppings.length > maxToppingsPerItem) {
    return 'an item can have at most $maxToppingsPerItem toppings';
  }
  for (final topping in toppings) {
    if (topping is! Map<String, dynamic> ||
        !_hasKeys(topping, _toppingRequired, _toppingOptional) ||
        topping['name'] is! String) {
      return 'each topping must be {name: string, price: number} '
          'with an optional id';
    }
    if ((topping['name'] as String).length > maxNameLength) {
      return 'topping name must be at most $maxNameLength characters';
    }
    if (topping.containsKey('id') && !_isNonEmptyString(topping['id'])) {
      return 'topping id must be a non-empty string of at most $maxIdLength characters';
    }
    if (!_isValidPrice(topping['price'])) {
      return 'topping price must be a number from 0 to $maxPrice';
    }
  }
  return null;
}

/// The order total in VND: sum of quantity x (price + toppings). Call only
/// after the items are validated.
num _orderTotal(List items) {
  num total = 0;
  for (final item in items) {
    num unit = item['price'] as num;
    for (final topping in (item['toppings'] as List?) ?? const []) {
      unit += topping['price'] as num;
    }
    total += (item['quantity'] as int) * unit;
  }
  return total;
}

/// Finite, not negative and at most [maxPrice]. `1e999` in JSON decodes to
/// infinity, which is still a `num` but can't be encoded back to JSON.
bool _isValidPrice(Object? price) =>
    price is num && price.isFinite && price >= 0 && price <= maxPrice;

/// A non-empty id of at most [maxIdLength] characters.
bool _isNonEmptyString(Object? value) =>
    value is String && value.isNotEmpty && value.length <= maxIdLength;

/// True when [map] has every key in [required], and no keys outside
/// [required] and [optional].
bool _hasKeys(
  Map<String, dynamic> map,
  Set<String> required,
  Set<String> optional,
) =>
    required.every(map.containsKey) &&
    map.keys.every((k) => required.contains(k) || optional.contains(k));

/// `DateTime.tryParse` also accepts bare forms like `2026` or `20261030`;
/// require the `YYYY-MM-DDT` start that `DateTime.toIso8601String()` emits.
final _isoDateTimeStart = RegExp(r'^\d{4}-\d{2}-\d{2}T');

/// The 400 reply when the body is not a JSON object.
Response _badRequest() =>
    Response.badRequest(body: 'Request body must be a JSON object');

/// Like [_json], but never cached (payment data).
Response _noStoreJson(Object? body) => Response.ok(
  jsonEncode(body),
  headers: {'Content-Type': 'application/json', 'Cache-Control': 'no-store'},
);

/// Helper: wrap any JSON-serialisable value as a 200 response.
Response _json(Object? body) => Response.ok(
  jsonEncode(body),
  headers: {'Content-Type': 'application/json'},
);
