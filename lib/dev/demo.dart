import 'package:flutter/material.dart';

import '../customer/pages/menu_page.dart';
import '../customer/state/menu_state.dart';
import '../restaurant/pages/orders_page.dart';
import '../shared/api/order_repository.dart';
import '../shared/theme.dart';

/// Dev-only split-view entry point: customer app on the left, restaurant app
/// on the right, both inside a single Dart process so they share one
/// [OrderRepository.instance] without any backend.
///
/// Useful for watching the full ordering flow in one browser window without
/// needing the shelf backend to be up. When the backend IS up and both apps
/// are running as separate processes, this view becomes redundant — but it
/// stays as a quick smoke-test tool.
///
/// Run with: `flutter run -t lib/dev/demo.dart -d chrome --web-port=8082`
void main() {
  OrderRepository.instance.init();
  // Fire-and-forget like init(): the menu page shows a spinner until it
  // arrives, or an error with Retry if the backend is down.
  MenuState.instance.load();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Orders — Demo',
      theme: customerTheme(),
      home: const _SplitView(),
    );
  }
}

/// Side-by-side layout. Each pane gets its own Theme so the colour palette
/// matches what the real customer / restaurant apps use. The customer side
/// is wrapped in a Navigator so pushing to CartPage works within the pane.
class _SplitView extends StatelessWidget {
  const _SplitView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Theme(
              data: customerTheme(),
              child: const Navigator(onGenerateRoute: _customerRoute),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Theme(data: restaurantTheme(), child: const OrdersPage()),
          ),
        ],
      ),
    );
  }
}

Route _customerRoute(RouteSettings settings) =>
    MaterialPageRoute(builder: (_) => const MenuPage());
