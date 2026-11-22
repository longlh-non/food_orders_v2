import 'display_text.dart';

/// An extra a food can take ("Thêm chả" …), from `GET /api/toppings`.
///
/// Only foods with `MenuItem.allowToppings` offer toppings. Two toppings are
/// equal when their [id]s match.
class Topping {
  final String id;
  final String name;
  final double price;

  const Topping({required this.id, required this.name, required this.price});

  /// Parses one item of `GET /toppings`. Like menu items, toppings are
  /// edited by hand in the database, so every field is checked: anything
  /// wrong throws a [FormatException] naming the field.
  factory Topping.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('topping must be a JSON object');
    }
    final id = json['id'];
    final name = json['name'];
    final price = json['price'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('topping id must be a non-empty string');
    }
    if (name is! String) {
      throw const FormatException('topping name must be a string');
    }
    if (price is! num || !price.isFinite || price < 0) {
      throw const FormatException(
        'topping price must be a finite number of at least 0',
      );
    }
    final shown = displayText(name);
    if (shown.isEmpty) {
      throw const FormatException('topping name must have visible text');
    }
    return Topping(id: id, name: shown, price: price.toDouble());
  }

  @override
  bool operator ==(Object other) => other is Topping && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
