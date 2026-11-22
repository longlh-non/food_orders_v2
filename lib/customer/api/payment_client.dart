import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/models/display_text.dart';

/// Why a payment request failed. The pages pick their own fixed text.
enum PaymentFailure {
  /// 409: the order can't be paid by transfer any more (cash, paid, expired).
  notPayable,

  /// 503: bank transfer isn't set up on the server.
  notSetUp,

  /// 404: no such order.
  notFound,

  /// Anything else: other status, no answer, or a reply of the wrong shape.
  other,
}

/// A payment request that didn't give a usable answer.
///
/// [message] is for developers only. It never contains the server's text.
class PaymentException implements Exception {
  const PaymentException(this.failure, this.message, {this.statusCode});

  final PaymentFailure failure;
  final String message;

  /// The HTTP status, or null when there was no answer at all.
  final int? statusCode;

  @override
  String toString() => 'PaymentException: $message';
}

/// Whether bank transfer is set up, and the account to show next to the QR.
class PaymentInfo {
  const PaymentInfo({
    required this.transferEnabled,
    this.bankName,
    this.accountNumber,
    this.accountName,
  });

  final bool transferEnabled;

  /// Set only when [transferEnabled] is true.
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
}

/// The QR text and the details to show next to it for one order.
class PaymentQr {
  const PaymentQr({
    required this.payload,
    required this.amount,
    required this.reference,
    required this.dueAt,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  /// The exact text to draw as a QR code (not cleaned: it is data).
  final String payload;

  /// Whole VND, above 0.
  final int amount;

  /// The transfer content, e.g. `DH482913`.
  final String reference;

  /// The payment deadline, in UTC.
  final DateTime dueAt;
  final String bankName;
  final String accountNumber;
  final String accountName;
}

/// Small client for `GET /payment-info` and `GET /orders/{id}/payment-qr`.
///
/// No state, no caching, no timers: pages decide when to call. Replies are
/// parsed strictly and any wrong shape is a [PaymentException].
class PaymentClient {
  PaymentClient({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = '/api';

  final http.Client _client;

  void close() => _client.close();

  Future<PaymentInfo> fetchInfo() async {
    final json = await _get('GET /payment-info', '$_baseUrl/payment-info');
    final enabled = json['transferEnabled'];
    if (enabled is! bool) throw _invalid('GET /payment-info');
    if (!enabled) return const PaymentInfo(transferEnabled: false);
    return PaymentInfo(
      transferEnabled: true,
      bankName: _text(json, 'bankName', 'GET /payment-info'),
      accountNumber: _match(
        json,
        'accountNumber',
        _digits,
        'GET /payment-info',
      ),
      accountName: _text(json, 'accountName', 'GET /payment-info'),
    );
  }

  Future<PaymentQr> fetchQr(String orderId) async {
    const what = 'GET /orders/{id}/payment-qr';
    // Ids come from outside: encode so `/`, `?` or `%` can't change the path.
    // An empty id or `.` / `..` can't be an order, and a browser would fold
    // the dots out of the path. Not sent; reported as "no such order".
    if (orderId.isEmpty || RegExp(r'^\.+$').hasMatch(orderId)) {
      throw const PaymentException(
        PaymentFailure.notFound,
        '$what: not a valid order id',
      );
    }
    final json = await _get(
      what,
      '$_baseUrl/orders/${Uri.encodeComponent(orderId)}/payment-qr',
    );
    final payload = json['payload'];
    if (payload is! String || payload.isEmpty) throw _invalid(what);
    final amount = json['amount'];
    if (amount is! int || amount < 1 || amount > _maxAmount) {
      throw _invalid(what);
    }
    final accountNumber = _match(json, 'accountNumber', _digits, what);
    final reference = _match(json, 'reference', _reference, what);
    // The QR is what gets paid; the shown fields must agree with it.
    if (!_payloadMatches(payload, accountNumber, amount, reference)) {
      throw _invalid(what);
    }
    return PaymentQr(
      payload: payload,
      amount: amount,
      reference: reference,
      dueAt: _utc(json['dueAt'], what),
      bankName: _text(json, 'bankName', what),
      accountNumber: accountNumber,
      accountName: _text(json, 'accountName', what),
    );
  }

  /// Reads the payload as EMVCo TLV (tag 2 digits, length 2 digits, value)
  /// and checks the fields the customer sees next to it, all exactly: tag 54
  /// is the amount, tag 38 > 01 > 01 the account number and tag 62 > 08 the
  /// transfer content. A payload that doesn't parse is a mismatch.
  static bool _payloadMatches(
    String payload,
    String account,
    int amount,
    String reference,
  ) {
    final top = _tlv(payload);
    final merchant = _tlv(top?['38']);
    final consumer = _tlv(merchant?['01']);
    final extra = _tlv(top?['62']);
    return top != null &&
        top['54'] == '$amount' &&
        consumer != null &&
        consumer['01'] == account &&
        extra != null &&
        extra['08'] == reference;
  }

  /// One level of TLV, or null when it is malformed (bad tag or length, a
  /// value running past the end, a repeated tag, or no fields at all).
  static Map<String, String>? _tlv(String? text) {
    if (text == null || text.isEmpty) return null;
    final fields = <String, String>{};
    var i = 0;
    while (i < text.length) {
      if (i + 4 > text.length) return null;
      final tag = text.substring(i, i + 2);
      final lengthText = text.substring(i + 2, i + 4);
      if (!_twoDigits.hasMatch(tag) || !_twoDigits.hasMatch(lengthText)) {
        return null;
      }
      final end = i + 4 + int.parse(lengthText);
      if (end > text.length || fields.containsKey(tag)) return null;
      fields[tag] = text.substring(i + 4, end);
      i = end;
    }
    return fields;
  }

  static final _twoDigits = RegExp(r'^[0-9]{2}$');

  Future<Map<String, dynamic>> _get(String what, String path) async {
    final http.Response response;
    try {
      response = await _client.get(Uri(path: path));
    } on http.ClientException {
      throw PaymentException(
        PaymentFailure.other,
        '$what: no answer from the server',
      );
    }
    final status = response.statusCode;
    if (status != 200) {
      throw PaymentException(
        switch (status) {
          409 => PaymentFailure.notPayable,
          503 => PaymentFailure.notSetUp,
          404 => PaymentFailure.notFound,
          _ => PaymentFailure.other,
        },
        '$what failed with HTTP $status',
        statusCode: status,
      );
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // (utf8.decode errors are FormatExceptions too.) Falls through to the same error as a non-object body.
    }
    throw _invalid(what, status);
  }

  static PaymentException _invalid(String what, [int? status = 200]) =>
      PaymentException(
        PaymentFailure.other,
        '$what returned an invalid reply',
        statusCode: status,
      );

  /// 50 lines x quantity 100 x (price + 10 toppings) of 1,000,000 each.
  static const _maxAmount = 55000000000;

  static final _digits = RegExp(r'^[0-9]{1,19}$');
  // Matches backend transferReference: the last 6 digits, or all of them
  // when the id has fewer.
  static final _reference = RegExp(r'^DH[0-9]{1,6}$');

  /// A required string that matches [rule] exactly (no cleaning).
  static String _match(
    Map<String, dynamic> json,
    String key,
    RegExp rule,
    String what,
  ) {
    final raw = json[key];
    if (raw is! String || !rule.hasMatch(raw)) throw _invalid(what);
    return raw;
  }

  /// A required non-empty (after cleaning) string field.
  static String _text(Map<String, dynamic> json, String key, String what) {
    final raw = json[key];
    if (raw is! String) throw _invalid(what);
    final cleaned = displayText(raw);
    if (cleaned.isEmpty) throw _invalid(what);
    return cleaned;
  }

  static final _utcIso = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?Z$',
  );

  /// An ISO-8601 string that ends in `Z`, parsed as UTC.
  static DateTime _utc(Object? raw, String what) {
    final m = raw is String ? _utcIso.firstMatch(raw) : null;
    if (m == null) throw _invalid(what);
    final DateTime parsed;
    try {
      parsed = DateTime.parse(raw as String).toUtc();
    } on FormatException {
      throw _invalid(what);
    }
    // DateTime.parse rolls over impossible dates (month 13, day 45); compare
    // the parts so those are rejected instead.
    final parts = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
    final same = [
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    ];
    for (var i = 0; i < 6; i++) {
      if (parts[i] != same[i]) throw _invalid(what);
    }
    return parsed;
  }
}
