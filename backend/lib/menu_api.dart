import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'menu_image.dart';
import 'menu_slug.dart';
import 'staff_gate.dart';

/// The `/menu` and `/toppings` routes, backed by the `menu_items` and
/// `toppings` tables. Reads are public; the two writes, `PATCH /menu/{id}`
/// (price and sold-out) and `POST /menu` (add an item), need the staff ID
/// and password.
///
/// Shares the database handle opened by `bin/server.dart` with `OrdersApi`.
/// It doesn't own the handle, so it never closes it.
class MenuApi {
  /// Without a [staffGate], menu writes are disabled (403): fail closed.
  MenuApi(this._db, {StaffGate? staffGate}) : _gate = staffGate ?? StaffGate();

  /// Shared with `OrdersApi`; opened and closed by `bin/server.dart`.
  final Database _db;

  /// Guards `PATCH /menu/{id}` and `POST /menu`, the staff routes here.
  final StaffGate _gate;

  /// The shelf handler for `/menu` and `/toppings`, with CORS applied.
  /// Built on first use. Request logging is left to `bin/server.dart`.
  late final Handler handler = _buildHandler();

  /// Creates the router with the routes below and wraps it with CORS.
  Handler _buildHandler() {
    final router = Router();

    // GET /menu (public): 200 with every item in insertion order.
    // Read on every request, no caching: an edit made with the sqlite3 CLI
    // shows up on the next GET without restarting the backend.
    router.get('/menu', (Request req) {
      final rows = _db.select('$_selectItems ORDER BY rowid');
      return _json([for (final row in rows) _itemJson(row)]);
    });

    // POST /menu (staff only): add a menu item. Answers 201 with the new item
    // and `Cache-Control: no-store`; 401 / 403 / 429 from the staff check (made
    // before the body is read, so a disabled gate fails closed); 413 body over
    // 4 KB; 400 a body that isn't valid JSON or breaks [_newItemProblem];
    // 409 same name in the same category, or no free id; 503 the menu is full.
    // Every message is fixed text, never request text. The id is made by
    // [menuSlug] (only `[a-z0-9-]`); all values are bound parameters. The cap,
    // duplicate check, id pick and INSERT run in one BEGIN IMMEDIATE
    // transaction, so a concurrent sqlite3 CLI write can't slip in between.
    router.post('/menu', (Request req) async {
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
      final problem = _newItemProblem(decoded);
      if (problem != null) return Response.badRequest(body: problem);
      final item = decoded as Map<String, dynamic>;

      final name = (item['name'] as String).trim();
      final description = (item['description'] as String?) ?? '';
      final price = (item['price'] as num).toInt();
      final category = item['category'] as String;
      final allowToppings = item['allowToppings'] == true;
      final image = item['image'] as String?;

      _db.execute('BEGIN IMMEDIATE');
      try {
        final count =
            _db.select('SELECT count(*) AS n FROM menu_items').first['n']
                as int;
        if (count >= maxMenuItems) {
          _db.execute('ROLLBACK');
          return Response(503, body: 'Menu is full');
        }
        final folded = foldMenuText(name);
        final sameCategory = _db.select(
          'SELECT name FROM menu_items WHERE category = ?',
          [category],
        );
        final duplicate = sameCategory.any(
          (row) => foldMenuText((row['name'] as String).trim()) == folded,
        );
        if (duplicate) {
          _db.execute('ROLLBACK');
          return Response(
            409,
            body: 'An item with this name already exists in this category',
          );
        }
        final base = menuSlug(name);
        String? id;
        for (var n = 1; n <= maxIdAttempts; n++) {
          final candidate = n == 1 ? base : '$base-$n';
          final taken = _db.select('SELECT 1 FROM menu_items WHERE id = ?', [
            candidate,
          ]);
          if (taken.isEmpty) {
            id = candidate;
            break;
          }
        }
        if (id == null) {
          _db.execute('ROLLBACK');
          return Response(409, body: 'Could not make a free id for this item');
        }
        _db.execute(
          'INSERT INTO menu_items '
          '(id, name, description, price, category, allow_toppings, image, '
          'available) VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
          [
            id,
            name,
            description,
            price,
            category,
            allowToppings ? 1 : 0,
            image,
          ],
        );
        final row = _db.select('$_selectItems WHERE id = ?', [id]).first;
        _db.execute('COMMIT');
        return Response(
          201,
          body: jsonEncode(_itemJson(row)),
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'no-store',
          },
        );
      } catch (_) {
        // Any failure leaves the table as it was; the error goes on (500).
        try {
          _db.execute('ROLLBACK');
        } catch (_) {
          // No transaction left to roll back.
        }
        rethrow;
      }
    });

    // PATCH /menu/{id} (staff only): change an item's price and/or sold-out
    // switch. Answers 200 with the updated item, 401 / 403 / 429 from the
    // staff check (made before the body is read), 413 body over 4 KB, 400 a
    // body that isn't valid JSON or breaks [_menuEditProblem], 404 unknown id
    // (or an id with a broken `%` escape). The id is only ever a bound
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

    // GET /toppings (public, read-only): 200 with every topping in insertion
    // order, as `{id, name, price}`.
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

/// The columns of `menu_items` that `GET /menu` and the `PATCH` reply read.
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

/// The most items the menu can hold; `POST /menu` answers 503 beyond it.
const maxMenuItems = 300;

/// Longest new item name, in UTF-16 units (an emoji counts 2).
const maxMenuNameUnits = 100;

/// Longest new item description, in UTF-16 units.
const maxMenuDescriptionUnits = 500;

/// How many ids (`name`, `name-2`, ...) are tried before giving up (409).
const maxIdAttempts = 1000;

/// A menu edit is a few bytes; anything bigger is refused (413) without
/// reading it all. The proxy also caps bodies at 64 KB.
const maxMenuEditBytes = 4096;

/// The body as text, or null when it is longer than [maxMenuEditBytes]. Checks
/// the declared length first, then counts while reading, so a huge body is
/// never held in memory in full.
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

/// True when [text] has a control character (C0, DEL or C1), other than
/// `\n` when [allowNewline].
bool _hasControl(String text, {bool allowNewline = false}) {
  for (final unit in text.codeUnits) {
    if (allowNewline && unit == 0x0A) continue;
    if (unit < 0x20 || (unit >= 0x7F && unit <= 0x9F)) return true;
  }
  return false;
}

/// Checks a `POST /menu` body: a JSON object with `name`, `price` and
/// `category`, optionally `description`, `allowToppings` and `image`, and
/// nothing else. Returns a fixed message, or null.
String? _newItemProblem(Object? item) {
  if (item is! Map<String, dynamic>) {
    return 'Request body must be a JSON object';
  }
  const allowed = {
    'name',
    'description',
    'price',
    'category',
    'allowToppings',
    'image',
  };
  if (item.keys.any((k) => !allowed.contains(k))) {
    return 'Body has a field that is not allowed';
  }
  final name = item['name'];
  if (name is! String) return 'name is required';
  final trimmed = name.trim();
  if (trimmed.isEmpty ||
      trimmed.length > maxMenuNameUnits ||
      _hasControl(trimmed)) {
    return 'name must be 1 to $maxMenuNameUnits characters, '
        'with no control characters';
  }
  if (item.containsKey('description')) {
    final description = item['description'];
    if (description is! String ||
        description.length > maxMenuDescriptionUnits ||
        _hasControl(description, allowNewline: true)) {
      return 'description must be text of at most $maxMenuDescriptionUnits '
          'characters, with no control characters';
    }
  }
  final price = item['price'];
  if (price is! num ||
      !price.isFinite ||
      price < 0 ||
      price > maxMenuPrice ||
      price != price.truncate()) {
    return 'price must be a whole number from 0 to $maxMenuPrice';
  }
  final category = item['category'];
  if (category is! String ||
      !const {'food', 'snack', 'drink', 'nibble'}.contains(category)) {
    return 'category must be food, snack, drink or nibble';
  }
  if (item.containsKey('allowToppings')) {
    final allow = item['allowToppings'];
    if (allow is! bool) return 'allowToppings must be true or false';
    if (allow && category != 'food') {
      return 'allowToppings is only allowed for food';
    }
  }
  if (item.containsKey('image')) {
    final image = item['image'];
    if (image != null && (image is! String || !isValidImageName(image))) {
      return 'image must be null or a picture file name';
    }
  }
  return null;
}

/// Wraps any JSON-serialisable value as a 200 response.
Response _json(Object body) => Response.ok(
  jsonEncode(body),
  headers: {'Content-Type': 'application/json'},
);
