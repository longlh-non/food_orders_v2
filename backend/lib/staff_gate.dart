import 'dart:convert';

import 'package:shelf/shelf.dart';

/// The headers a staff request carries the shared staff ID and password in.
const staffIdHeader = 'x-staff-id';
const staffPasswordHeader = 'x-staff-password';

/// Longest staff ID accepted.
const maxStaffIdLength = 64;

/// Shorter configured passwords turn staff routes off. A human-chosen
/// password is weaker than a long random token, so it can't be shorter.
const minStaffPasswordLength = 12;

/// Wrong attempts allowed within [lockoutWindow] before staff routes lock.
const maxStaffFailures = 5;

/// How long the wrong attempts are counted, and how long the lock lasts.
const lockoutWindow = Duration(seconds: 60);

// Header values must stay plain: browsers refuse other characters there.
final _printableAscii = RegExp(r'^[\x20-\x7E]+$');

/// The check in front of staff-only routes (the month export, menu writes).
///
/// The backend reads `STAFF_ID` and `STAFF_PASSWORD` from its environment and
/// passes them here; both are trimmed. It fails closed: unless the ID is 1 to
/// [maxStaffIdLength] printable ASCII characters and the password at least
/// [minStaffPasswordLength], every staff request gets 403.
///
/// Both halves are always compared, in constant time, and a wrong pair gets
/// one fixed 401 that never says which half was wrong. After
/// [maxStaffFailures] wrong attempts within [lockoutWindow], every staff
/// request (even a correct one) gets 429 for the next [lockoutWindow]. The
/// limit is global, not per address: behind the proxy every request comes
/// from 127.0.0.1. Anyone who can reach the apps can therefore lock staff out
/// for a minute at a time; accepted (owner, 2026-11-19).
///
/// One shared ID and password for all staff, kept in plain text in the
/// process environment, and sent over plain HTTP on the wifi. Real staff
/// login is still needed before real customers.
class StaffGate {
  StaffGate({String? id, String? password, DateTime Function()? now})
    : _id = _usableId(id?.trim()),
      _password = _usablePassword(password?.trim()),
      _now = now ?? DateTime.now;

  static String? _usableId(String? id) =>
      (id != null &&
          id.isNotEmpty &&
          id.length <= maxStaffIdLength &&
          _printableAscii.hasMatch(id))
      ? id
      : null;

  static String? _usablePassword(String? password) =>
      (password != null &&
          password.length >= minStaffPasswordLength &&
          _printableAscii.hasMatch(password))
      ? password
      : null;

  final String? _id;
  final String? _password;
  final DateTime Function() _now;

  /// Times of the recent wrong attempts; never more than [maxStaffFailures].
  final List<DateTime> _failures = [];
  DateTime? _lockedUntil;

  /// Whether staff routes can be used at all. Safe to print: it says
  /// nothing about the ID or password.
  bool get enabled => _id != null && _password != null;

  /// Null when [req] may go on; otherwise the 403, 429 or 401 response.
  ///
  /// Bodies are fixed text, so neither the configured nor the sent values can
  /// ever appear in a response. No `WWW-Authenticate` header, so browsers
  /// never pop up their own login box.
  Response? check(Request req) {
    final id = _id;
    final password = _password;
    if (id == null || password == null) {
      return _error(403, 'Staff routes are disabled on this server');
    }

    final now = _now();
    final lockedUntil = _lockedUntil;
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      final seconds = (lockedUntil.difference(now).inMilliseconds / 1000)
          .ceil();
      return _error(
        429,
        'Too many wrong attempts; try again later',
        headers: {'retry-after': '$seconds'},
      );
    }

    // Compare both halves every time (no short-circuit), so the time taken
    // doesn't tell which half was right.
    final idMatches = constantTimeEquals(req.headers[staffIdHeader] ?? '', id);
    final passwordMatches = constantTimeEquals(
      req.headers[staffPasswordHeader] ?? '',
      password,
    );
    if (idMatches & passwordMatches) return null;

    _failures
      ..removeWhere((t) => now.difference(t) >= lockoutWindow)
      ..add(now);
    if (_failures.length >= maxStaffFailures) {
      _lockedUntil = now.add(lockoutWindow);
      _failures.clear();
    }
    return _error(401, 'Missing or wrong staff ID or password');
  }
}

Response _error(int status, String message, {Map<String, String>? headers}) =>
    Response(
      status,
      body: jsonEncode({'error': message}),
      headers: {'content-type': 'application/json', ...?headers},
    );

/// Compares [sent] with [expected] in a time that depends only on the
/// length of [sent], so response timing doesn't reveal how many leading
/// characters of a guess were right. Compares UTF-8 bytes.
bool constantTimeEquals(String sent, String expected) {
  final a = utf8.encode(sent);
  final b = utf8.encode(expected);
  var diff = a.length ^ b.length;
  for (var i = 0; i < a.length; i++) {
    // Past the end of [b] keep comparing against 0, so the loop always runs
    // a.length times; the length check above already marks a mismatch.
    diff |= a[i] ^ (i < b.length ? b[i] : 0);
  }
  return diff == 0;
}
