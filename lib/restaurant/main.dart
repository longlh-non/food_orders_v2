import 'package:flutter/material.dart';

import '../shared/api/order_repository.dart';
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
  OrderRepository.instance.init();
  runApp(const RestaurantApp());
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Orders — Restaurant',
      theme: restaurantTheme(),
      home: const OrdersPage(),
    );
  }
}
