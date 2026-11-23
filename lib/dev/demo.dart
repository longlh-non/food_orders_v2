import 'package:flutter/material.dart';

import '../customer/pages/menu_page.dart';
import '../customer/state/menu_state.dart';
import '../restaurant/pages/orders_page.dart';
import '../shared/api/order_repository.dart';
import '../shared/l10n.dart';
import '../shared/theme.dart';

/// Dev-only split-view entry point: customer screen on the left, restaurant
/// screen on the right, both inside a single Dart process so they share one
/// [OrderRepository.instance].
///
/// This file may import both `lib/customer/` and `lib/restaurant/` because
/// `lib/dev/` is the only place allowed to (CLAUDE.md, architecture invariant
/// 1; `make boundaries` checks it). The two panes share state because that
/// state lives in singletons (`static final instance`): [OrderRepository]
/// is the order cache for both panes, so an order placed on the left shows up
/// on the right with no extra wiring. The customer-only singletons (`Cart`,
/// `MyOrders`, [MenuState]) are used by the left pane alone.
///
/// It still needs the backend: the orders and the menu are fetched from
/// `/api/*` and live updates come over SSE, so it must be served where that
/// proxy exists. It is a quick one-window smoke test, not a replacement for
/// running the two real apps as separate processes.
///
/// Run with: `flutter run -t lib/dev/demo.dart -d chrome --web-port=8082`
void main() {
  LocaleController.instance.init();
  OrderRepository.instance.init();
  // Fire-and-forget like init(): the menu page shows a spinner until it
  // arrives, or an error with Retry if the backend is down.
  MenuState.instance.load();
  runApp(const DemoApp());
}

/// Root widget of the demo: a [MaterialApp] (customer theme as the base) whose
/// home is the two-pane [_SplitView]. It holds no state.
class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  /// Builds the app shell. It watches nothing, so it is built once.
  @override
  Widget build(BuildContext context) {
    // The customer pages read AppLocalizations, so this MaterialApp needs the
    // delegates and the language, like the real apps. It rebuilds when the
    // language picker changes the language.
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) => MaterialApp(
        title: 'Food Orders — Demo',
        theme: customerTheme(),
        locale: LocaleController.instance.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _SplitView(),
      ),
    );
  }
}

/// Side-by-side layout. Each pane gets its own Theme so the colour palette
/// matches what the real customer / restaurant apps use. The customer side
/// is wrapped in a Navigator so pushing to CartPage works within the pane.
class _SplitView extends StatelessWidget {
  const _SplitView();

  /// Builds two equal-width panes in a [Row] with a thin divider. It watches
  /// nothing itself; the pages inside rebuild from the shared singletons.
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

/// Route factory for the left pane's [Navigator]: every route it is asked for
/// is the customer [MenuPage] (the cart is pushed from inside that page).
Route _customerRoute(RouteSettings settings) =>
    MaterialPageRoute(builder: (_) => const MenuPage());
