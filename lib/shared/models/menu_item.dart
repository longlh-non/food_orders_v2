import 'display_text.dart';

/// Which tab an item belongs to. The server sends these exact names.
///
/// The order here is not the tab order; the menu page decides that.
enum MenuCategory {
  /// "Đồ ăn": dishes. The only category that can take toppings.
  food,

  /// "Ăn nhẹ": light snacks.
  snack,

  /// "Đồ uống": drinks.
  drink,

  /// "Ăn vặt": nibbles.
  nibble,
}

/// The rule for picture file names, the same as the backend's
/// (`backend/lib/menu_image.dart`): lowercase letters, digits and `-`, one
/// of four extensions. A name that passes can't contain `/`, `..`, `%`,
/// spaces or a scheme like `http:`, so it is safe to put in a URL path.
final menuImageName = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}\.(jpg|jpeg|png|webp)$');

/// A single entry in the restaurant's menu. Immutable value object.
///
/// The menu comes from the backend (`GET /api/menu`, stored in the
/// database). Two items are equal when their [id]s match, so the same dish
/// fetched twice is still one entry in the cart.
///
/// [image] is optional: a picture file name such as `xoi-thit.webp`, or
/// null for "no picture" (the grid then shows a placeholder). Turn it into
/// an address with `OrderApiClient.imageUrlFor`.
class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final MenuCategory category;

  /// Whether the customer may add toppings. [fromJson] makes this false for
  /// anything that isn't [MenuCategory.food], whatever the server says.
  final bool allowToppings;

  /// The picture's file name, or null. Never a URL.
  final String? image;

  /// False when the item is sold out. Older backends don't send it, which
  /// means available.
  final bool available;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.category = MenuCategory.food,
    this.allowToppings = true,
    this.image,
    this.available = true,
  });

  /// Parses one item of `GET /menu`.
  ///
  /// Menu rows can be edited by hand in the database, so nothing is assumed:
  /// any missing field or wrong type throws a [FormatException] naming the
  /// field, instead of failing later somewhere in the UI.
  factory MenuItem.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('menu item must be a JSON object');
    }
    final id = json['id'];
    final name = json['name'];
    final description = json['description'];
    final price = json['price'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('menu item id must be a non-empty string');
    }
    if (name is! String) {
      throw const FormatException('menu item name must be a string');
    }
    if (description is! String) {
      throw const FormatException('menu item description must be a string');
    }
    if (price is! num || !price.isFinite || price < 0) {
      throw const FormatException(
        'menu item price must be a finite number of at least 0',
      );
    }
    final displayName = displayText(name);
    if (displayName.isEmpty) {
      throw const FormatException('menu item name must have visible text');
    }
    // Strict on purpose (owner decision TAB4): an unknown category fails the
    // whole menu load with the usual error, instead of putting a mystery item
    // into the wrong tab. A *missing* key means an older backend: food.
    final MenuCategory category;
    if (!json.containsKey('category')) {
      category = MenuCategory.food;
    } else {
      final raw = json['category'];
      final match = MenuCategory.values.where((c) => c.name == raw);
      if (raw is! String || match.isEmpty) {
        throw const FormatException(
          'menu item category must be food, snack, drink or nibble',
        );
      }
      category = match.single;
    }
    final bool allowToppings;
    if (!json.containsKey('allowToppings')) {
      allowToppings = category == MenuCategory.food;
    } else {
      final raw = json['allowToppings'];
      if (raw is! bool) {
        throw const FormatException(
          'menu item allowToppings must be true or false',
        );
      }
      // Defence in depth: the server already sends true only for food, but
      // a drink or snack must never offer toppings even if a reply says so.
      allowToppings = raw && category == MenuCategory.food;
    }
    // Missing (older backend) or null (no picture) both mean none. Anything
    // else must be a valid name, or the whole menu load fails like any other
    // bad field (owner point IMG3b, recommended answer).
    final raw = json['image'];
    if (raw != null && (raw is! String || !menuImageName.hasMatch(raw))) {
      throw const FormatException(
        'menu item image must be null or a picture file name',
      );
    }
    // Missing (older backend) means available. Present, it must be a real
    // true/false, like the other fields.
    final bool available;
    if (!json.containsKey('available')) {
      available = true;
    } else {
      final rawAvailable = json['available'];
      if (rawAvailable is! bool) {
        throw const FormatException(
          'menu item available must be true or false',
        );
      }
      available = rawAvailable;
    }
    return MenuItem(
      id: id,
      name: displayName,
      description: displayText(description),
      price: price.toDouble(),
      category: category,
      allowToppings: allowToppings,
      image: raw as String?,
      available: available,
    );
  }

  // Equal by id: `Cart` uses MenuItem as a Map key, and items parsed from
  // the server are new objects on every fetch.
  @override
  bool operator ==(Object other) => other is MenuItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
