// ignore_for_file: avoid_print

import 'dart:io';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/images_api.dart';
import 'package:food_orders_backend/menu_api.dart';
import 'package:food_orders_backend/no_sniff.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:food_orders_backend/shop_settings.dart';
import 'package:food_orders_backend/staff_gate.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Starts the backend: opens the database and the images folder, builds the
/// staff gate and the shop settings, combines the menu, images and orders
/// APIs behind logging and the no-sniff header, listens on port 3000 and
/// prints a few startup lines (never the staff ID or password). Ctrl-C closes
/// everything and exits.
void main() async {
  // Default: backend/data/orders.db, found relative to this script so it
  // doesn't depend on the directory you run from. That default assumes
  // `dart run bin/server.dart`; a compiled binary must set `ORDERS_DB`.
  // An empty `ORDERS_DB` counts as unset: SQLite would otherwise open a
  // temporary database and every order would silently vanish on exit.
  final fromEnv = Platform.environment['ORDERS_DB'];
  final dbPath = (fromEnv != null && fromEnv.isNotEmpty)
      ? fromEnv
      : File.fromUri(Platform.script).parent.parent.uri
            .resolve('data/orders.db')
            .toFilePath();
  final db = openDatabase(dbPath);

  // Menu pictures: one folder, created if missing. Same rule as the
  // database: `IMAGES_DIR` overrides, an empty value counts as unset.
  final imagesDir = Directory(
    imagesDirPath(Platform.environment['IMAGES_DIR'], Platform.script),
  )..createSync(recursive: true);

  // The shared staff ID and password for staff-only routes. Unset or invalid
  // means those routes answer 403. Never print the values, not even lengths.
  final staffGate = StaffGate(
    id: Platform.environment['STAFF_ID'],
    password: Platform.environment['STAFF_PASSWORD'],
  );

  // Shop and bank details (reports, bank transfer orders).
  // Invalid or missing values only turn their own feature off.
  final shopSettings = ShopSettings(Platform.environment);

  // Cascade tries each API in turn and moves on when one answers 404/405,
  // so /orders and /menu are served from one port. Orders goes LAST: Cascade
  // returns the last 404, so an unknown order still answers
  // "Order not found" rather than the menu router's generic text. Images sit
  // in between: a missing picture falls through too, so callers see Orders'
  // 404 body ("Image not found" only shows when ImagesApi is used alone).
  // The status is 404 either way, and a bad name's 400 stops the cascade.
  final ordersApi = OrdersApi(
    db,
    staffGate: staffGate,
    shopSettings: shopSettings,
  )..startExpirySweep();
  final apis = Cascade()
      .add(MenuApi(db, staffGate: staffGate).handler)
      .add(ImagesApi(imagesDir).handler)
      .add(ordersApi.handler)
      .handler;
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(noSniff())
      .addHandler(apis);

  // Loopback only by default: Caddy and nginx reach the backend on
  // localhost, and nothing else on the wifi can get around their 64 KB
  // body limit by calling :3000 directly. `BIND_ADDRESS` overrides it
  // (empty counts as unset), e.g. for a different hosting layout.
  final bindFromEnv = Platform.environment['BIND_ADDRESS'];
  final Object bindAddress = (bindFromEnv != null && bindFromEnv.isNotEmpty)
      ? bindFromEnv
      : InternetAddress.loopbackIPv4;
  final server = await io.serve(handler, bindAddress, 3000);
  // Why this handler exists: without it Ctrl-C kills the process with the
  // sweep timer and the open streams still running. This stops the timer and
  // the stream, then exits 130 (the usual code for SIGINT). `stopping` makes a
  // second Ctrl-C do nothing while the first is still closing, and `finally`
  // guarantees the exit even if a close throws.
  var stopping = false;
  ProcessSignal.sigint.watch().listen((_) async {
    if (stopping) return;
    stopping = true;
    try {
      await ordersApi.close();
      await server.close(force: true);
      db.close();
    } finally {
      exit(130);
    }
  });
  print(
    'food_orders backend listening on http://${server.address.host}:${server.port}',
  );
  print('orders database: $dbPath');
  print('menu pictures: ${imagesDir.path}');
  print(
    staffGate.enabled
        ? 'staff routes: enabled (STAFF_ID and STAFF_PASSWORD set)'
        : 'staff routes: disabled (STAFF_ID / STAFF_PASSWORD unset or invalid: '
              'ID 1-$maxStaffIdLength characters, password at least '
              '$minStaffPasswordLength, printable ASCII)',
  );
  print(shopSettings.describe());
  // The old single token is no longer used; say so instead of failing
  // silently. Only the name is printed, never a value.
  if ((Platform.environment['STAFF_TOKEN'] ?? '').isNotEmpty) {
    print(
      'note: STAFF_TOKEN is no longer used; set STAFF_ID and STAFF_PASSWORD',
    );
  }
}
