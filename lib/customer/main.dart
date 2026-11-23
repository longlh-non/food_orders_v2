import 'package:flutter/material.dart';

import '../shared/api/order_repository.dart';
import '../shared/l10n.dart';
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
  // Restore the saved language first, so the first frame is already in it.
  LocaleController.instance.init();
  OrderRepository.instance.init();
  // Fire-and-forget like init(): the menu page shows a spinner until it
  // arrives, or an error with Retry if the backend is down.
  MenuState.instance.load();
  runApp(const CustomerApp());
}

/// The root widget of the customer app: a `MaterialApp` with the customer
/// theme whose home screen is the menu page.
class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  /// Builds the `MaterialApp`. It watches only the chosen language; each page watches its own state.
  @override
  Widget build(BuildContext context) {
    // Rebuilds the MaterialApp when the user picks another language.
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) => MaterialApp(
        title: 'Đặt Món',
        theme: customerTheme(),
        locale: LocaleController.instance.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MenuPage(),
      ),
    );
  }
}
