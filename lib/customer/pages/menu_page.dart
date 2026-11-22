import 'package:flutter/material.dart';

import '../../shared/api/order_api_client.dart';
import '../../shared/api/order_repository.dart';
import '../../shared/models/menu_item.dart';
import '../../shared/models/order.dart';
import '../../shared/money.dart';
import '../state/cart.dart';
import '../state/menu_state.dart';
import '../state/my_orders.dart';
import 'add_food_dialog.dart';
import 'cart_page.dart';
import 'payment_qr_page.dart';

/// Home screen for the customer app.
///
/// Three jobs:
///   1. Show the menu (loaded from the backend by [MenuState]) as a grid and
///      let the user add items to [Cart].
///   2. Show a "Your orders" banner at the top for any orders this session
///      has placed (via [MyOrders]) that aren't yet terminal.
///   3. Fire a snackbar when the status of one of this session's orders
///      changes (customer sees "Your order is being prepared" live).
///
/// Stateful because it keeps a diff of statuses across repo notifications
/// so it can detect transitions rather than just showing the current state.
class MenuPage extends StatefulWidget {
  /// [state] is for tests; the app uses [MenuState.instance].
  const MenuPage({super.key, this.state});

  final MenuState? state;

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  /// Last-seen status per tracked order id. Used to detect transitions.
  final _lastStatuses = <String, OrderStatus>{};

  late final MenuState _menu = widget.state ?? MenuState.instance;

  /// The menu list we last synced the cart against.
  List<MenuItem>? _syncedMenu;

  @override
  void initState() {
    super.initState();
    OrderRepository.instance.addListener(_onRepoChanged);
    MyOrders.instance.addListener(_onRepoChanged);
    _menu.addListener(_onMenuChanged);
    // Seed the status map without firing snackbars for the initial state.
    _syncStatuses(initial: true);
    _syncedMenu = _menu.items;
  }

  @override
  void dispose() {
    OrderRepository.instance.removeListener(_onRepoChanged);
    MyOrders.instance.removeListener(_onRepoChanged);
    _menu.removeListener(_onMenuChanged);
    super.dispose();
  }

  /// After a (re)load, swap cart items for the fresh ones so the cart shows
  /// current prices, and tell the customer if something left the menu.
  void _onMenuChanged() {
    if (!mounted || !_menu.hasLoaded) return;
    if (identical(_menu.items, _syncedMenu)) return;
    _syncedMenu = _menu.items;
    final (:removed, :repriced) = Cart.instance.refreshItems(
      _menu.items,
      _menu.toppings,
    );
    final notes = [
      if (repriced == 1) 'The price of 1 item in your cart changed',
      if (repriced > 1) 'Prices of $repriced items in your cart changed',
      if (removed == 1) '1 item is no longer on the menu and was removed',
      if (removed > 1)
        '$removed items are no longer on the menu and were removed',
    ];
    if (notes.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${notes.join('. ')}.')));
    }
  }

  void _onRepoChanged() {
    if (!mounted) return;
    _syncStatuses();
    setState(() {});
  }

  /// Walks the current orders, compares statuses with [_lastStatuses], and
  /// fires a snackbar when a status flipped. `initial: true` suppresses the
  /// snackbar on the first pass so page loads don't spam notifications.
  void _syncStatuses({bool initial = false}) {
    final myIds = MyOrders.instance.ids;
    for (final order in OrderRepository.instance.orders) {
      if (!myIds.contains(order.id)) continue;
      final prev = _lastStatuses[order.id];
      _lastStatuses[order.id] = order.status;
      if (!initial && prev != null && prev != order.status) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                order.expiredUnpaid
                    ? 'Đơn #${_shortId(order.id)}: hết hạn thanh toán'
                    : 'Order #${_shortId(order.id)}: ${order.status.label}',
              ),
            ),
          );
      }
    }
  }

  /// Orders placed in this session that haven't reached a terminal state,
  /// plus those cancelled by the payment expiry that can still be renewed or
  /// switched to cash (15 minutes, by the phone's clock).
  List<Order> get _myActiveOrders {
    final myIds = MyOrders.instance.ids;
    final now = DateTime.now();
    return OrderRepository.instance.orders.where((o) {
      if (!myIds.contains(o.id)) return false;
      if (o.expiredUnpaid) {
        final until = safeRenewableUntil(o);
        return until != null && !now.isAfter(until);
      }
      return o.status != OrderStatus.delivered &&
          o.status != OrderStatus.cancelled;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final myActive = _myActiveOrders;
    // The controller lives in this page's state, so the chosen tab is kept
    // while the customer visits the cart and comes back.
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(title: const Text('Menu')),
        // One cart button, round and red, docked in the middle of a slim
        // bar at the bottom (decision NAV1). The cart opens as its own page
        // on top (NAV2), so the chosen category is still there on return.
        floatingActionButton: const _CartButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: const BottomAppBar(
          shape: CircularNotchedRectangle(),
          notchMargin: 6,
          height: 56,
          color: Colors.white,
        ),
        body: Column(
          children: [
            const _CategoryBar(),
            Expanded(
              child: ListenableBuilder(
                listenable: _menu,
                builder: (context, _) =>
                    _menuStatus() ??
                    TabBarView(
                      children: [
                        for (final (category, _, _) in _tabs)
                          _TabContent(
                            // Keeps each tab's scroll position when switching
                            // tabs and coming back (owner, 2026-11-12).
                            key: PageStorageKey('menu-tab-${category.name}'),
                            items: [
                              for (final item in _menu.items)
                                if (item.category == category) item,
                            ],
                            myActive: myActive,
                            menu: _menu,
                          ),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The error or loading view, which replaces all tabs; null once the menu
  /// has loaded. An error wins over stale items so a failed Retry is visible.
  Widget? _menuStatus() {
    if (_menu.error != null) {
      return _MenuMessage(
        // Generic on purpose: never show the raw error to customers.
        text: "Couldn't load the menu",
        action: FilledButton(
          onPressed: _menu.isLoading ? null : _menu.load,
          child: const Text('Retry'),
        ),
      );
    }
    if (!_menu.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return null;
  }
}

/// The round red cart button with a live count of items in the cart.
/// Opens the cart page; the badge is hidden while the cart is empty.
class _CartButton extends StatelessWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context) {
    final cart = Cart.instance;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) => FloatingActionButton(
        tooltip: 'Cart',
        shape: const CircleBorder(),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CartPage())),
        child: Badge(
          label: cart.isEmpty ? null : Text('${cart.itemCount}'),
          isLabelVisible: !cart.isEmpty,
          child: const Icon(Icons.shopping_cart),
        ),
      ),
    );
  }
}

/// The tabs, in the owner's order, with the owner's labels and icons.
const _tabs = <(MenuCategory, String, IconData)>[
  (MenuCategory.food, 'Đồ ăn', Icons.rice_bowl),
  (MenuCategory.drink, 'Đồ uống', Icons.local_drink),
  (MenuCategory.snack, 'Ăn nhẹ', Icons.bakery_dining),
  (MenuCategory.nibble, 'Ăn vặt', Icons.cookie),
];

/// The row of category tiles under the app bar, on the cream page.
///
/// Still a `TabBar` (decision TABS1), so tapping, swiping the menu, keeping
/// the chosen tab while visiting the cart and each tab's scroll position all
/// work as before; only the look changes. Scrollable, so a tile grows with
/// its label and nothing is cut off on a small phone or with large text.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar();

  @override
  Widget build(BuildContext context) {
    // Room for the icon and one line of label at the user's text size,
    // plus the tile's padding and a little space for its shadow.
    final height = MediaQuery.textScalerOf(context).scale(16) + 64;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        dividerColor: Colors.transparent,
        // The tiles draw the selection themselves, and the highlight moving
        // is the tap feedback: a ripple would be hidden under the opaque
        // tiles anyway.
        indicator: const BoxDecoration(),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tabs: [
          for (final (index, (_, label, icon)) in _tabs.indexed)
            Tab(
              height: height,
              child: _CategoryTile(index: index, label: label, icon: icon),
            ),
        ],
      ),
    );
  }
}

/// One category tile: an icon over its label. The selected tile is tinted
/// with a red icon and a bold red label; the others are white with a soft
/// shadow and a grey icon.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.index,
    required this.label,
    required this.icon,
  });

  final int index;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Follows a swipe: the highlight moves as soon as a page is mostly in
    // view. After a tap it jumps straight to the tapped tile, instead of
    // stepping through the tiles in between.
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, _) {
        final current = controller.indexIsChanging
            ? controller.index
            : controller.animation!.value.round();
        final selected = current == index;
        final colour = selected ? scheme.primary : scheme.onSurfaceVariant;
        return Container(
          constraints: const BoxConstraints(minWidth: 76),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decoration only: the label is what screen readers say.
              ExcludeSemantics(child: Icon(icon, color: colour, size: 26)),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: text.labelMedium?.copyWith(
                  color: colour,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One tab: the "Your orders" banner (scrolls away with the grid), then the
/// tab's items, or a short message when the category has none yet.
class _TabContent extends StatelessWidget {
  const _TabContent({
    super.key,
    required this.items,
    required this.myActive,
    required this.menu,
  });

  final List<MenuItem> items;
  final List<Order> myActive;

  /// For the add dialog's toppings and drinks.
  final MenuState menu;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (myActive.isNotEmpty)
          SliverToBoxAdapter(child: _MyOrdersBanner(orders: myActive)),
        if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _MenuMessage(text: 'Chưa có món nào trong mục này'),
          )
        else
          SliverPadding(
            // Extra room at the bottom: the cart button sticks up above the
            // bottom bar, and the last row must scroll fully clear of it.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + 56),
            sliver: SliverGrid(
              // Columns follow the width: tiles are at most 220 px wide, so a
              // 360 px phone gets 2 columns and a laptop gets 4-6. The fixed
              // height fits a 2-line name and a long price at 2x text size;
              // the 360 px fit tests in test/menu_page_test.dart check it.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 250,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _MenuTile(item: items[index], menu: menu),
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }
}

/// Centered text with an optional button, for the error and empty states.
class _MenuMessage extends StatelessWidget {
  const _MenuMessage({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

/// Shows the last 4 chars of an order id — matches what the restaurant UI
/// shows, so both sides can refer to orders by the same short identifier.
String _shortId(String id) => id.substring(id.length - 4);

/// A banner at the top of the menu listing this session's active orders.
/// Rendered only when there's at least one; hidden otherwise.
class _MyOrdersBanner extends StatelessWidget {
  final List<Order> orders;
  const _MyOrdersBanner({required this.orders});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Your orders',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...orders.map(
              (o) => _BannerRow(
                order: o,
                child: Row(
                  children: [
                    Text(
                      '#${_shortId(o.id)}',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        o.expiredUnpaid ? 'Hết hạn thanh toán' : o.status.label,
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ),
                    Text(
                      formatVnd(o.total),
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One banner line. A transfer order that is waiting for payment, or expired
/// and still renewable, opens the payment page when tapped.
class _BannerRow extends StatelessWidget {
  const _BannerRow({required this.order, required this.child});

  final Order order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final opensPayment =
        order.paymentMethod == PaymentMethod.bank_transfer &&
        (order.status == OrderStatus.awaiting_payment || order.expiredUnpaid);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: child,
    );
    if (!opensPayment) return row;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentQrPage(orderId: order.id),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(alignment: Alignment.centerLeft, child: row),
      ),
    );
  }
}

/// One menu item in the grid: picture, name, price and a round "+".
class _MenuTile extends StatelessWidget {
  final MenuItem item;
  final MenuState menu;
  const _MenuTile({required this.item, required this.menu});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // White rounded card with a soft shadow (from the customer theme's
    // cardTheme): picture on top, then the name, then price and a round "+".
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TileImage(item: item, height: 96),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // The description isn't shown (owner decision TILE1); the
                  // space pushes the price row to the bottom of the card.
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        // One line always; shrinks instead of wrapping.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatVnd(item.price),
                            style: text.titleSmall,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      AddItemButton(
                        tooltip: 'Add ${item.name}',
                        onPressed: () => _add(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Drinks, snacks and Ăn vặt items go straight into the cart. A food asks
  /// "Extra toppings? A drink?" first (when there is anything to offer), and
  /// the cart changes only once the customer confirms; a cancel adds nothing.
  Future<void> _add(BuildContext context) async {
    final drinks = [
      for (final i in menu.items)
        if (i.category == MenuCategory.drink) i,
    ];
    AddFoodChoice choice = const AddFoodChoice();
    if (item.category == MenuCategory.food &&
        addFoodAsks(item, menu.toppings, drinks)) {
      final picked = await showAddFoodDialog(
        context,
        dish: item,
        toppings: menu.toppings,
        drinks: drinks,
      );
      if (picked == null) return;
      choice = picked;
    }
    // The customer confirmed, so the cart changes even if this tile was
    // rebuilt away meanwhile (menu reload); only the SnackBar needs it.
    Cart.instance.add(item, toppings: choice.toppings);
    if (choice.drink case final drink?) Cart.instance.add(drink);
    if (!context.mounted) return;
    final added = [item.name, ?choice.drink?.name].join(' + ');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Added $added'),
          duration: const Duration(milliseconds: 800),
        ),
      );
  }
}

/// The item's picture from `/api/images/<name>`, cropped to fill a block
/// of [height]. With no picture, while it loads, or when it fails (missing
/// file, offline), the placeholder shows instead, so the tile always looks
/// complete and keeps the same size.
class _TileImage extends StatelessWidget {
  const _TileImage({required this.item, required this.height});

  final MenuItem item;
  final double height;

  /// Tiles are at most 220 px wide (about 170 px on a phone); decoding at
  /// 480 px keeps photos sharp on phone screens up to 3x pixel density,
  /// without decoding a big photo at full size.
  static const _decodeWidth = 480;

  @override
  Widget build(BuildContext context) {
    final url = OrderApiClient.imageUrlFor(item);
    if (url == null) return _TileImagePlaceholder(height: height);
    final placeholder = _TileImagePlaceholder(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: _decodeWidth,
        semanticLabel: item.name,
        // The placeholder until the first frame is ready (a cached picture
        // arrives synchronously and shows at once), so a tile is never blank.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            wasSynchronouslyLoaded || frame != null ? child : placeholder,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

/// Coloured block with an icon, shown when there is no picture to show.
class _TileImagePlaceholder extends StatelessWidget {
  const _TileImagePlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: ColoredBox(
        color: scheme.secondaryContainer,
        child: Icon(
          Icons.restaurant,
          size: 40,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// The small round dark-red "+" on a menu tile. The circle is 36 px, but the
/// tap area stays at least 48 x 48 so it is easy to hit with a thumb. With
/// [onPressed] null it shows Flutter's disabled (greyed) colours and keeps
/// its tooltip; a sold-out item will use that.
@visibleForTesting
class AddItemButton extends StatelessWidget {
  const AddItemButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  /// Also the screen reader label, e.g. "Add Xôi thịt".
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 20,
      icon: const Icon(Icons.add),
      style: IconButton.styleFrom(
        fixedSize: const Size(36, 36),
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
