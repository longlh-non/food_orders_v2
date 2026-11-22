import 'package:flutter/material.dart';

import '../../shared/models/menu_item.dart';
import '../../shared/models/topping.dart';
import '../../shared/money.dart';

/// What the customer chose in [showAddFoodDialog]: the toppings for the dish
/// (in menu order, maybe none) and an optional drink to add as its own line.
class AddFoodChoice {
  const AddFoodChoice({this.toppings = const [], this.drink});

  final List<Topping> toppings;
  final MenuItem? drink;
}

/// Whether adding [dish] asks anything at all: true when it can take
/// [toppings] or there are [drinks] to offer. When false, add it directly.
bool addFoodAsks(
  MenuItem dish,
  List<Topping> toppings,
  List<MenuItem> drinks,
) => _offersToppings(dish, toppings) || drinks.isNotEmpty;

bool _offersToppings(MenuItem dish, List<Topping> toppings) =>
    dish.allowToppings && toppings.isNotEmpty;

/// Asks "Extra toppings? A drink?" for [dish], then shows a toppings step
/// and/or a drink step for whatever was ticked (toppings first).
///
/// Returns the choice, or null when the customer cancels or dismisses at any
/// step: then nothing must be added. The caller changes the cart, once.
///
/// One dialog whose content changes per step, so "Back" keeps every tick and
/// a dismiss always ends the whole flow.
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

enum _Step { ask, toppings, drink }

class _AddFoodDialog extends StatefulWidget {
  const _AddFoodDialog({
    required this.dish,
    required this.toppings,
    required this.drinks,
  });

  final MenuItem dish;

  /// Empty when this dish takes no toppings: the row is then hidden.
  final List<Topping> toppings;
  final List<MenuItem> drinks;

  @override
  State<_AddFoodDialog> createState() => _AddFoodDialogState();
}

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

  _Step _previous(_Step from) =>
      from == _Step.drink && _wantToppings ? _Step.toppings : _Step.ask;

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

  @override
  Widget build(BuildContext context) {
    final isLast = _next(_step) == null;
    // A ticked drink step needs a drink before it can finish.
    final canGo = _step != _Step.drink || _drinkId != null;
    return AlertDialog(
      title: Text(switch (_step) {
        _Step.ask => 'Add ${widget.dish.name}',
        _Step.toppings => 'Extra toppings',
        _Step.drink => 'A drink',
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
            child: const Text('Cancel'),
          )
        else
          TextButton(
            onPressed: () => setState(() => _step = _previous(_step)),
            child: const Text('Back'),
          ),
        FilledButton(
          onPressed: canGo ? _forward : null,
          child: Text(isLast ? 'Add' : 'Next'),
        ),
      ],
    );
  }

  Widget _askContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (widget.toppings.isNotEmpty)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Extra toppings'),
          value: _wantToppings,
          onChanged: (v) => setState(() => _wantToppings = v ?? false),
        ),
      if (widget.drinks.isNotEmpty)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Add drinks'),
          value: _wantDrink,
          onChanged: (v) => setState(() => _wantDrink = v ?? false),
        ),
    ],
  );

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
            title: Text(d.name),
            subtitle: Text(formatVnd(d.price)),
          ),
      ],
    ),
  );
}
