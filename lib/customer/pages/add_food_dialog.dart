import 'package:flutter/material.dart';

import '../../shared/models/menu_item.dart';
import '../../shared/models/topping.dart';
import '../../shared/money.dart';

/// What the customer chose in [showAddFoodDialog]: the toppings for the dish
/// (in menu order, maybe none) and an optional drink to add as its own line.
class AddFoodChoice {
  const AddFoodChoice({this.toppings = const [], this.drink});

  /// The ticked toppings, in menu order; empty for none.
  final List<Topping> toppings;

  /// The drink to add as its own cart line, or null for no drink.
  final MenuItem? drink;
}

/// Whether adding [dish] asks anything at all: true when it can take
/// [toppings] or there is at least one *available* drink to offer (a list of
/// only sold-out drinks offers nothing). When false, add it directly.
bool addFoodAsks(
  MenuItem dish,
  List<Topping> toppings,
  List<MenuItem> drinks,
) => _offersToppings(dish, toppings) || _offersDrinks(drinks);

/// Whether any of [drinks] can be picked, i.e. is not sold out.
bool _offersDrinks(List<MenuItem> drinks) => drinks.any((d) => d.available);

/// Whether [dish] can take toppings and there are any toppings to pick from.
bool _offersToppings(MenuItem dish, List<Topping> toppings) =>
    dish.allowToppings && toppings.isNotEmpty;

/// Asks "Thêm {dish name}" with the checkboxes "Thêm topping" and "Thêm đồ
/// uống" for [dish], then shows a toppings step and/or a drink step for
/// whatever was ticked (toppings first).
///
/// Returns the choice, or null when the customer cancels or dismisses at any
/// step: then nothing must be added. The caller changes the cart, once.
///
/// One dialog whose content changes per step, so "Quay lại" (back) keeps
/// every tick and a dismiss always ends the whole flow.
Future<AddFoodChoice?> showAddFoodDialog(
  BuildContext context, {
  required MenuItem dish,
  required List<Topping> toppings,
  required List<MenuItem> drinks,
}) {
  return showDialog<AddFoodChoice>(
    context: context,
    builder: (_) => _AddFoodDialog(
      dish: dish,
      toppings: _offersToppings(dish, toppings) ? toppings : const [],
      drinks: drinks,
    ),
  );
}

/// The screens of the add dialog: the tick-boxes, the toppings, the drinks.
enum _Step { ask, toppings, drink }

/// The dialog shown by [showAddFoodDialog]. Stateful because it remembers the
/// current step and what has been ticked while the customer moves through it.
class _AddFoodDialog extends StatefulWidget {
  const _AddFoodDialog({
    required this.dish,
    required this.toppings,
    required this.drinks,
  });

  final MenuItem dish;

  /// Empty when this dish takes no toppings: the row is then hidden.
  final List<Topping> toppings;

  /// The drinks listed in the drink step. Sold-out ones are shown but cannot
  /// be picked. The drink row is hidden when none of them is available.
  final List<MenuItem> drinks;

  @override
  State<_AddFoodDialog> createState() => _AddFoodDialogState();
}

/// State for [_AddFoodDialog]: the current step, the two tick-boxes, the
/// chosen topping ids and the chosen drink id.
class _AddFoodDialogState extends State<_AddFoodDialog> {
  var _step = _Step.ask;
  var _wantToppings = false;
  var _wantDrink = false;
  final _toppingIds = <String>{};
  String? _drinkId;

  List<Topping> get _chosenToppings => [
    for (final t in widget.toppings)
      if (_toppingIds.contains(t.id)) t,
  ];

  /// The step after [from] for what was ticked, or null when done.
  _Step? _next(_Step from) => switch (from) {
    _Step.ask when _wantToppings => _Step.toppings,
    _Step.ask || _Step.toppings when _wantDrink => _Step.drink,
    _ => null,
  };

  /// The step "Quay lại" goes back to: from the drink step, the toppings step
  /// if toppings were ticked; otherwise the first step. Ticks are kept.
  _Step _previous(_Step from) =>
      from == _Step.drink && _wantToppings ? _Step.toppings : _Step.ask;

  /// Moves to the next step, or on the last step closes the dialog and
  /// returns the [AddFoodChoice].
  void _forward() {
    final next = _next(_step);
    if (next != null) {
      setState(() => _step = next);
      return;
    }
    Navigator.of(context).pop(
      AddFoodChoice(
        toppings: _wantToppings ? _chosenToppings : const [],
        drink: _wantDrink
            ? widget.drinks.firstWhere((d) => d.id == _drinkId)
            : null,
      ),
    );
  }

  /// An `AlertDialog` whose title, content and buttons depend on the current
  /// step. It redraws through `setState` when the step or a tick changes.
  @override
  Widget build(BuildContext context) {
    final isLast = _next(_step) == null;
    // A ticked drink step needs a drink before it can finish.
    final canGo = _step != _Step.drink || _drinkId != null;
    return AlertDialog(
      title: Text(switch (_step) {
        _Step.ask => 'Thêm ${widget.dish.name}',
        _Step.toppings => 'Thêm topping',
        _Step.drink => 'Chọn đồ uống',
      }),
      // Scrolls when tall (big text, long lists); the buttons stay visible.
      scrollable: true,
      content: switch (_step) {
        _Step.ask => _askContent(),
        _Step.toppings => _toppingsContent(),
        _Step.drink => _drinkContent(),
      },
      actions: [
        if (_step == _Step.ask)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          )
        else
          TextButton(
            onPressed: () => setState(() => _step = _previous(_step)),
            child: const Text('Quay lại'),
          ),
        FilledButton(
          onPressed: canGo ? _forward : null,
          child: Text(isLast ? 'Thêm' : 'Tiếp'),
        ),
      ],
    );
  }

  /// First step: tick-boxes for adding toppings and a drink, each shown only
  /// when there is something to offer.
  Widget _askContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (widget.toppings.isNotEmpty)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Thêm topping'),
          value: _wantToppings,
          onChanged: (v) => setState(() => _wantToppings = v ?? false),
        ),
      if (_offersDrinks(widget.drinks))
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Thêm đồ uống'),
          value: _wantDrink,
          onChanged: (v) => setState(() => _wantDrink = v ?? false),
        ),
    ],
  );

  /// Toppings step: one tick-box per topping with its price, and the dish's
  /// price for one unit with the ticked toppings added.
  Widget _toppingsContent() {
    final unit = _chosenToppings.fold(
      widget.dish.price,
      (sum, t) => sum + t.price,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in widget.toppings)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(t.name),
            subtitle: Text('+${formatVnd(t.price)}'),
            value: _toppingIds.contains(t.id),
            onChanged: (v) => setState(
              () =>
                  v == true ? _toppingIds.add(t.id) : _toppingIds.remove(t.id),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          '${widget.dish.name}: ${formatVnd(unit)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }

  /// Drink step: radio buttons, so exactly one drink can be picked. A sold-out
  /// drink stays in the list (same order) but is disabled and marked
  /// "Hết hàng" instead of showing its price.
  Widget _drinkContent() => RadioGroup<String>(
    groupValue: _drinkId,
    onChanged: (id) => setState(() => _drinkId = id),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final d in widget.drinks)
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: d.id,
            enabled: d.available,
            title: Text(d.name),
            subtitle: Text(d.available ? formatVnd(d.price) : 'Hết hàng'),
          ),
      ],
    ),
  );
}
