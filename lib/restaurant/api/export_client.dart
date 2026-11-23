import 'package:http/http.dart' as http;

import '../state/staff_credentials.dart';

/// Why a month export failed. The dialog shows its own short text for each;
/// [ExportException.message] is for developers only.
enum ExportFailure {
  /// 401: the staff ID or password is missing or wrong.
  wrongCredentials,

  /// 403: the server has no usable staff ID and password, so exports are
  /// off.
  disabled,

  /// 429: too many wrong attempts; staff routes are locked for a while.
  tooManyTries,

  /// 503: the shop details for the summary report aren't set on the server.
  notConfigured,

  /// Anything else: a bad month (400), a server error, or no answer.
  other,
}

/// A failed [ExportClient.fetchMonth]. Never contains the staff ID,
/// password or the server's reply text.
class ExportException implements Exception {
  const ExportException(
    this.failure,
    this.message, {
    this.statusCode,
    this.retryAfterSeconds,
  });

  final ExportFailure failure;
  final String message;

  /// The HTTP status, or null when there was no answer.
  final int? statusCode;

  /// For [ExportFailure.tooManyTries]: how many seconds the server asked to
  /// wait (`Retry-After`), when it said.
  final int? retryAfterSeconds;

  @override
  String toString() => 'ExportException(${failure.name}): $message';
}

/// Which file to download. [lines] is the CSV with one row per order line;
/// [summary] and [detail] are the Excel reports.
enum ExportReport { lines, summary, detail }

final _month = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

/// Downloads one month of orders as CSV bytes from
/// `GET /api/orders/export?month=YYYY-MM` (staff only).
///
/// Restaurant-only, like the menu admin client. The staff ID and password
/// are passed to each call and sent only in the `X-Staff-Id` and
/// `X-Staff-Password` headers (never in the URL, which servers log); they
/// are never stored here.
class ExportClient {
  ExportClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Closes the underlying HTTP client. Call when done with this client.
  void close() => _client.close();

  /// The file's bytes (CSV or .xlsx, see [report]) for [month] (`YYYY-MM`). Throws [ArgumentError]
  /// without sending anything when [month] isn't `YYYY-MM` or
  /// [credentials] aren't sendable, and [ExportException] when the server
  /// says no or can't be reached.
  Future<List<int>> fetchMonth(
    String month, {
    ExportReport report = ExportReport.lines,
    required StaffCredentials credentials,
  }) async {
    if (!_month.hasMatch(month)) {
      throw ArgumentError.value(month, 'month', 'must be YYYY-MM');
    }
    if (!credentials.isSendable) {
      throw ArgumentError('Staff ID and password must be plain characters');
    }
    final http.Response response;
    try {
      response = await _client.get(
        Uri(
          path: '/api/orders/export',
          queryParameters: {
            'month': month,
            if (report != ExportReport.lines) 'report': report.name,
          },
        ),
        headers: credentials.headers,
      );
    } on http.ClientException {
      throw const ExportException(
        ExportFailure.other,
        'GET /orders/export: no answer from the server',
      );
    }
    final status = response.statusCode;
    if (status == 200) return response.bodyBytes;
    throw ExportException(
      switch (status) {
        401 => ExportFailure.wrongCredentials,
        403 => ExportFailure.disabled,
        429 => ExportFailure.tooManyTries,
        503 => ExportFailure.notConfigured,
        _ => ExportFailure.other,
      },
      'GET /orders/export failed with HTTP $status',
      statusCode: status,
      retryAfterSeconds: retryAfterSeconds(response.headers['retry-after']),
    );
  }
}
