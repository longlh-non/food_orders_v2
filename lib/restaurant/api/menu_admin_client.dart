import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/models/menu_item.dart';
import '../state/staff_credentials.dart';

/// Why a staff menu edit failed. UI code shows its own short text for each;
/// [MenuAdminException.message] is for developers only.
enum MenuAdminFailure {
  /// 401: the staff ID or password is missing or wrong.
  wrongCredentials,

  /// 403: the server has no usable staff ID and password, so menu editing is off.
  editingDisabled,

  /// 404: no menu item with that id.
  notFound,

  /// 400: the server refused the values (e.g. a price out of range).
  invalid,

  /// 429: too many wrong attempts; staff routes are locked for a while.
  tooManyTries,

  /// 409 on adding: an item with that name already exists in that category
  /// (or no free id could be made).
  duplicate,

  /// 503 on adding: the menu already holds the most items it can.
  menuFull,

  /// Anything else: no answer, a server error, or an unreadable reply.
  other,
}

/// A failed [MenuAdminClient.updateItem] or [MenuAdminClient.addItem]. Never contains the staff ID,
/// password or the server's reply text.
class MenuAdminException implements Exception {
  const MenuAdminException(
    this.failure,
    this.message, {
    this.statusCode,
    this.retryAfterSeconds,
  });

  final MenuAdminFailure failure;
  final String message;

  /// The HTTP status, or null when there was no answer.
  final int? statusCode;

  /// For [MenuAdminFailure.tooManyTries]: how many seconds the server asked
  /// to wait (`Retry-After`), when it said.
  final int? retryAfterSeconds;

  @override
  String toString() => 'MenuAdminException(${failure.name}): $message';
}

/// What staff typed for a new menu item, ready to send with
/// [MenuAdminClient.addItem]. The server makes the id and sets it available.
class NewMenuItem {
  const NewMenuItem({
    required this.name,
    this.description = '',
    required this.price,
    required this.category,
    this.allowToppings = false,
    this.image,
  });

  final String name;
  final String description;

  /// VND, whole number.
  final int price;
  final MenuCategory category;
  final bool allowToppings;

  /// A picture file name, or null for none.
  final String? image;

  /// The request body: exactly these keys, `image` only when set.
  Map<String, Object> toJson() => {
    'name': name,
    'description': description,
    'price': price,
    'category': category.name,
    'allowToppings': allowToppings,
    'image': ?image,
  };
}

/// Staff-only menu edits for the restaurant app: `PATCH /api/menu/{id}` and
/// `POST /api/menu`.
///
/// Restaurant-only on purpose (it isn't in `lib/shared/`): customers never
/// carry staff code. The staff ID and password are passed to each call, sent
/// only in the `X-Staff-Id` and `X-Staff-Password` headers, and never
/// stored, printed or put in an error.
class MenuAdminClient {
  MenuAdminClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Changes [price] and/or [available] of item [id], and returns the item
  /// as the server now has it. Throws [ArgumentError] (without sending
  /// anything) when neither is given, [id] is empty, `.` or `..`, or
  /// [credentials] aren't sendable, and [MenuAdminException] when the server
  /// says no or can't be reached.
  Future<MenuItem> updateItem(
    String id, {
    required StaffCredentials credentials,
    double? price,
    bool? available,
  }) async {
    if (price == null && available == null) {
      throw ArgumentError('Give a price, an available flag, or both');
    }
    // Encoding keeps `/`, `?` and `%` inside the id, but an id of exactly
    // `.` or `..` would still be read as "this folder" / "up one folder".
    if (id.isEmpty || id == '.' || id == '..') {
      throw ArgumentError.value(id, 'id', 'not a menu item id');
    }
    if (!credentials.isSendable) {
      throw ArgumentError('Staff ID and password must be plain characters');
    }
    final body = {'price': ?price, 'available': ?available};

    final http.Response response;
    try {
      response = await _client.patch(
        // Encoded, so an id stays one path segment with no query.
        Uri(path: '/api/menu/${Uri.encodeComponent(id)}'),
        headers: {'Content-Type': 'application/json', ...credentials.headers},
        body: jsonEncode(body),
      );
    } on http.ClientException {
      throw const MenuAdminException(
        MenuAdminFailure.other,
        'PATCH /menu/{id}: no answer from the server',
      );
    }

    final status = response.statusCode;
    if (status != 200) {
      final failure = switch (status) {
        400 => MenuAdminFailure.invalid,
        401 => MenuAdminFailure.wrongCredentials,
        403 => MenuAdminFailure.editingDisabled,
        404 => MenuAdminFailure.notFound,
        429 => MenuAdminFailure.tooManyTries,
        _ => MenuAdminFailure.other,
      };
      throw MenuAdminException(
        failure,
        'PATCH /menu/{id} failed with HTTP $status',
        statusCode: status,
        retryAfterSeconds: retryAfterSeconds(response.headers['retry-after']),
      );
    }

    MenuAdminException invalidReply() => MenuAdminException(
      MenuAdminFailure.other,
      'PATCH /menu/{id} returned an invalid menu item',
      statusCode: status,
    );
    try {
      return MenuItem.fromJson(jsonDecode(response.body));
    } on FormatException {
      throw invalidReply();
    } on TypeError {
      throw invalidReply();
    }
  }

  /// Adds [draft] to the menu and returns the item as the server made it
  /// (with its new id). Throws [ArgumentError] (without sending anything)
  /// when [credentials] aren't sendable, and [MenuAdminException] when the
  /// server says no, can't be reached, or sends something unreadable.
  Future<MenuItem> addItem(
    NewMenuItem draft, {
    required StaffCredentials credentials,
  }) async {
    if (!credentials.isSendable) {
      throw ArgumentError('Staff ID and password must be plain characters');
    }

    final http.Response response;
    try {
      response = await _client.post(
        // A constant path: no user text in the URL.
        Uri(path: '/api/menu'),
        headers: {'Content-Type': 'application/json', ...credentials.headers},
        body: jsonEncode(draft.toJson()),
      );
    } on http.ClientException {
      throw const MenuAdminException(
        MenuAdminFailure.other,
        'POST /menu: no answer from the server',
      );
    }

    final status = response.statusCode;
    if (status != 201) {
      final failure = switch (status) {
        400 || 413 => MenuAdminFailure.invalid,
        401 => MenuAdminFailure.wrongCredentials,
        403 => MenuAdminFailure.editingDisabled,
        409 => MenuAdminFailure.duplicate,
        429 => MenuAdminFailure.tooManyTries,
        503 => MenuAdminFailure.menuFull,
        _ => MenuAdminFailure.other,
      };
      throw MenuAdminException(
        failure,
        'POST /menu failed with HTTP $status',
        statusCode: status,
        retryAfterSeconds: retryAfterSeconds(response.headers['retry-after']),
      );
    }

    MenuAdminException invalidReply() => MenuAdminException(
      MenuAdminFailure.other,
      'POST /menu returned an invalid menu item',
      statusCode: status,
    );
    try {
      return MenuItem.fromJson(jsonDecode(response.body));
    } on FormatException {
      throw invalidReply();
    } on TypeError {
      throw invalidReply();
    }
  }
}
