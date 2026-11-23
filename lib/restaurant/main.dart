import 'package:flutter/material.dart';

import '../shared/api/order_repository.dart';
import '../shared/l10n.dart';
import '../shared/theme.dart';
import 'pages/orders_page.dart';

/// Entry point for the restaurant app.
///
/// Run with: `flutter run -t lib/restaurant/main.dart -d chrome --web-port=8081`
/// or press F5 in VS Code and pick "Restaurant app (Chrome)".
///
/// Mirrors `customer/main.dart`: fire-and-forget `init()` while the UI
/// comes up, then runApp. The restaurant view reads the same singleton
/// [OrderRepository] but only the OrdersPage uses the data.
void main() {
  // Restore the saved language first, so the first frame is already in it.
  LocaleController.instance.init();
  OrderRepository.instance.init();
  runApp(const RestaurantApp());
}

/// Root widget of the restaurant app: a [MaterialApp] with the restaurant
/// theme whose only screen is [OrdersPage]. It holds no state of its own.
class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  /// Builds the app shell (title, theme, language, home screen). It watches
  /// only [LocaleController]; [OrdersPage] listens to the orders itself.
  @override
  Widget build(BuildContext context) {
    // Rebuilds the MaterialApp when the user picks another language.
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) =>
            AppLocalizations.of(context)!.appTitleRestaurant,
        theme: restaurantTheme(),
        locale: LocaleController.instance.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OrdersPage(),
      ),
    );
  }
}
