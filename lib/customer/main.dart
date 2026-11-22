import 'package:flutter/material.dart';

import '../shared/api/order_repository.dart';
import '../shared/theme.dart';
import 'pages/menu_page.dart';
import 'state/menu_state.dart';

/// Entry point for the customer app.
///
/// Run with: `flutter run -t lib/customer/main.dart -d chrome --web-port=8080`
/// or press F5 in VS Code and pick "Customer app (Chrome)".
///
/// The call to `init()` is fire-and-forget: `runApp` must happen immediately
/// so the UI shows while the first HTTP fetch and SSE subscription are set
/// up in the background.
void main() {
  OrderRepository.instance.init();
  // Fire-and-forget like init(): the menu page shows a spinner until it
  // arrives, or an error with Retry if the backend is down.
  MenuState.instance.load();
  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Orders',
      theme: customerTheme(),
      home: const MenuPage(),
    );
  }
}
