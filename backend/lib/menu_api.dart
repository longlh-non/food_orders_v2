import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'menu_image.dart';
import 'staff_gate.dart';

/// The `/menu` and `/toppings` routes, backed by the `menu_items` and
/// `toppings` tables. Reads are public; the one write, `PATCH /menu/{id}`
/// (price and sold-out), needs the staff ID and password.
///
/// Shares the database handle opened by `bin/server.dart` with `OrdersApi`.
/// It doesn't own the handle, so it never closes it.
class MenuApi {
  /// Without a [staffGate], menu writes are disabled (403): fail closed.
  MenuApi(this._db, {StaffGate? staffGate}) : _gate = staffGate ?? StaffGate();

  final Database _db;
  final StaffGate _gate;

  late final Handler handler = _buildHandler();

  Handler _buildHandler() {
    final router = Router();

    // Read on every request, no caching: an edit made with the sqlite3 CLI
    // shows up on the next GET without restarting the backend.
    router.get('/menu', (Request req) {
      final rows = _db.select('$_selectItems ORDER BY rowid');
      return _json([for (final row in rows) _itemJson(row)]);
    });

    // Staff only: change an item's price and/or sold-out switch. The staff
    // ID and password are checked before the body is read; the id is only ever a bound
    // parameter. Only the named fields change (last write wins).
    router.patch('/menu/<id>', (Request req, String rawId) async {
      final denied = _gate.check(req);
      if (denied != null) return denied;

      final body = await _readSmallBody(req);
      if (body == null) {
        return Response(413, body: 'Request body is too large');
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        return Response.badRequest(body: 'Request body must be a JSON object');
      }
      final problem = _menuEditProblem(decoded);
      if (problem != null) return Response.badRequest(body: problem);
      final edit = decoded as Map<String, dynamic>;

      final String id;
      try {
        id = Uri.decodeComponent(rawId);
      } on ArgumentError {
        return Response.notFound('Menu item not found');
      } on FormatException {
        return Response.notFound('Menu item not found');
      }
      final sets = <String>[];
      final values = <Object?>[];
      if (edit.containsKey('price')) {
        sets.add('price = ?');
        values.add(edit['price']);
      }
      if (edit.containsKey('available')) {
        sets.add('available = ?');
        values.add(edit['available'] == true ? 1 : 0);
      }
      // Column names come from the fixed list above, never from the request.
      _db.execute('UPDATE menu_items SET ${sets.join(', ')} WHERE id = ?', [
        ...values,
        id,
      ]);
      if (_db.updatedRows == 0) return Response.notFound('Menu item not found');
      final row = _db.select('$_selectItems WHERE id = ?', [id]).first;
      return _json(_itemJson(row));
    });

    router.get('/toppings', (Request req) {
      final rows = _db.select(
        'SELECT id, name, price FROM toppings ORDER BY rowid',
      );
      return _json([
        for (final row in rows)
          {'id': row['id'], 'name': row['name'], 'price': row['price']},
      ]);
    });

    return const Pipeline()
        .addMiddleware(corsHeaders())
        .addHandler(router.call);
  }
}

const _selectItems =
    'SELECT id, name, description, price, category, allow_toppings, image, '
    'available FROM menu_items';

/// One menu row in the `GET /menu` shape (also the `PATCH` reply).
Map<String, Object?> _itemJson(Row row) => {
  'id': row['id'],
  'name': row['name'],
  'description': row['description'],
  'price': row['price'],
  'category': row['category'],
  // Only foods take toppings, whatever the column says for a snack or drink.
  'allowToppings': row['category'] == 'food' && row['allow_toppings'] == 1,
  // A picture file name, or null. A stored value that breaks the exact rule
  // (the table only checks it coarsely) counts as none.
  'image': switch (row['image']) {
    final String name when isValidImageName(name) => name,
    _ => null,
  },
  // false = sold out (the column is 0 or 1).
  'available': row['available'] == 1,
};

/// Highest menu price staff can set, in VND (MENU-EDIT3).
const maxMenuPrice = 1000000;

/// A menu edit is a few bytes; anything bigger is refused (413) without
/// reading it all. The proxy also caps bodies at 64 KB.
const maxMenuEditBytes = 4096;

/// The body as text, or null when it is longer than [maxMenuEditBytes].
Future<String?> _readSmallBody(Request req) async {
  final declared = req.contentLength;
  if (declared != null && declared > maxMenuEditBytes) return null;
  final bytes = <int>[];
  await for (final chunk in req.read()) {
    bytes.addAll(chunk);
    if (bytes.length > maxMenuEditBytes) return null;
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// Checks a `PATCH /menu/{id}` body: a JSON object with at least one of
/// `price` (a whole number from 0 to [maxMenuPrice]) and `available` (strictly
/// true or false), and nothing else. Returns a fixed message, or null.
String? _menuEditProblem(Object? edit) {
  if (edit is! Map<String, dynamic>) {
    return 'Request body must be a JSON object';
  }
  if (edit.isEmpty || edit.keys.any((k) => k != 'price' && k != 'available')) {
    return 'Body must have price and/or available, and nothing else';
  }
  if (edit.containsKey('price')) {
    final price = edit['price'];
    // Whole VND only, like every price in the app (25000, not 25000.5).
    if (price is! num ||
        !price.isFinite ||
        price < 0 ||
        price > maxMenuPrice ||
        price != price.truncate()) {
      return 'price must be a whole number from 0 to $maxMenuPrice';
    }
  }
  if (edit.containsKey('available') && edit['available'] is! bool) {
    return 'available must be true or false';
  }
  return null;
}

Response _json(Object body) => Response.ok(
  jsonEncode(body),
  headers: {'Content-Type': 'application/json'},
);
