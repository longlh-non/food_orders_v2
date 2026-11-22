import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/customer/main.dart';
import 'package:food_orders/restaurant/main.dart';

void main() {
  // Builds the app without any network. The menu body stays on its spinner
  // here (nothing calls MenuState.instance.load()); the page's states and the
  // grid are tested in menu_page_test.dart with an injected MenuState.
  testWidgets('Customer app renders menu page', (tester) async {
    await tester.pumpWidget(const CustomerApp());
    expect(find.text('Menu'), findsOneWidget);
  });

  testWidgets('Restaurant app renders orders page', (tester) async {
    await tester.pumpWidget(const RestaurantApp());
    expect(find.text('Incoming Orders'), findsOneWidget);
  });
}
