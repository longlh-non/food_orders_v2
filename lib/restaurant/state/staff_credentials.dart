/// The shared staff ID and password, as typed by staff.
class StaffCredentials {
  const StaffCredentials({required this.id, required this.password});

  final String id;
  final String password;

  /// The two request headers the backend checks. Never put these values in
  /// a URL, a body, a log or an error message.
  Map<String, String> get headers => {
    'X-Staff-Id': id,
    'X-Staff-Password': password,
  };

  /// True when both are non-empty and plain printable characters. Browsers
  /// refuse other characters in request headers, which would otherwise look
  /// like a network failure. Length rules are the server's to check.
  bool get isSendable => _sendable.hasMatch(id) && _sendable.hasMatch(password);

  /// Never shows the values.
  @override
  String toString() => 'StaffCredentials(<hidden>)';
}

final _sendable = RegExp(r'^[\x20-\x7E]+$');

/// The seconds in a 429 reply's `Retry-After` header, or null when it is
/// missing or isn't a sensible number of seconds (1 to 3600). The server
/// sends at most 60; anything else isn't shown to staff.
int? retryAfterSeconds(String? header) {
  final seconds = int.tryParse(header?.trim() ?? '');
  return seconds != null && seconds > 0 && seconds <= 3600 ? seconds : null;
}

/// The staff ID and password typed in this browser tab, kept in memory
/// only, so staff type them once per visit (month export, and later menu
/// editing). Never saved anywhere: no localStorage, no cookie. A page reload
/// forgets them. Cleared when the server says they are wrong.
class StaffCredentialsHolder {
  StaffCredentialsHolder._();

  static final StaffCredentialsHolder instance = StaffCredentialsHolder._();

  /// The remembered credentials, or null.
  StaffCredentials? value;

  void clear() => value = null;
}
