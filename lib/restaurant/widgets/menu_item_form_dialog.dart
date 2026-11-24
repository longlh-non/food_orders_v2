import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/l10n.dart';
import '../../shared/models/menu_item.dart';
import '../api/menu_admin_client.dart';
import '../state/menu_admin_state.dart';

/// Asks staff for the details of a new menu item. Returns the item to send,
/// or null when staff cancel.
///
/// [initial] prefills the fields (used to reopen the form after the server
/// said no, so nothing typed is lost). [errorText] is shown above the fields,
/// e.g. "an item with this name already exists". The form checks the input
/// with [validateNewItem] and shows the problem under the field; nothing is
/// returned while something is wrong. The form never sees the staff ID or
/// password.
Future<NewMenuItem?> showMenuItemFormDialog(
  BuildContext context, {
  NewMenuItem? initial,
  String? errorText,
}) => showDialog<NewMenuItem>(
  context: context,
  builder: (_) => MenuItemFormDialog(initial: initial, errorText: errorText),
);

/// The add-item form (see [showMenuItemFormDialog]).
class MenuItemFormDialog extends StatefulWidget {
  const MenuItemFormDialog({super.key, this.initial, this.errorText});

  final NewMenuItem? initial;
  final String? errorText;

  /// Creates the state that holds the fields and their errors.
  @override
  State<MenuItemFormDialog> createState() => _MenuItemFormDialogState();
}

class _MenuItemFormDialogState extends State<MenuItemFormDialog> {
  /// The longest picture name the server accepts (see `menuImageName`).
  /// Hand-copied: 1 + 63 characters plus `.jpeg` (the rule in CLAUDE.md,
  /// `GET /menu`).
  static const _maxImageLength = 69;

  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.initial?.price.toString() ?? '',
  );
  late final _image = TextEditingController(text: widget.initial?.image ?? '');
  late MenuCategory? _category = widget.initial?.category;
  late bool _allowToppings = widget.initial?.allowToppings ?? false;

  String? _nameError;
  String? _descriptionError;
  String? _priceError;
  String? _categoryError;
  String? _imageError;

  /// Frees the four text controllers.
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _image.dispose();
    super.dispose();
  }

  /// The label of [category], the same words as the customer's menu tabs.
  String _categoryLabel(AppLocalizations l10n, MenuCategory category) =>
      switch (category) {
        MenuCategory.food => l10n.customerCategoryFood,
        MenuCategory.snack => l10n.customerCategorySnack,
        MenuCategory.drink => l10n.customerCategoryDrink,
        MenuCategory.nibble => l10n.customerCategoryNibble,
      };

  /// Checks the fields; shows what is wrong under each, or closes with the
  /// new item. The name is trimmed and a blank picture name becomes null.
  void _confirm() {
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    final description = _description.text;
    final imageText = _image.text.trim();
    final image = imageText.isEmpty ? null : imageText;
    final category = _category;
    final allowToppings = category == MenuCategory.food && _allowToppings;

    // validateNewItem reports only the first problem, so each field is
    // checked on its own (the others filled with fine values) to show every
    // wrong field at once.
    NewItemProblem? check({
      String name = 'x',
      String description = '',
      String priceText = '0',
      String? image,
    }) => validateNewItem(
      name: name,
      description: description,
      priceText: priceText,
      category: MenuCategory.snack,
      allowToppings: false,
      image: image,
    );
    final nameError = check(name: name) != null ? l10n.menuAddNameError : null;
    final descriptionError = check(description: description) != null
        ? l10n.menuAddDescriptionError
        : null;
    final priceError = check(priceText: _price.text) != null
        ? l10n.menuPriceRangeError
        : null;
    final imageError = check(image: image) != null
        ? l10n.menuAddImageError
        : null;
    final categoryError = category == null
        ? l10n.menuAddCategoryRequired
        : null;
    final problem = nameError ?? descriptionError ?? priceError ?? imageError;

    if (problem != null || category == null) {
      setState(() {
        _nameError = nameError;
        _descriptionError = descriptionError;
        _priceError = priceError;
        _imageError = imageError;
        _categoryError = categoryError;
      });
      return;
    }
    // Last look at the real values together (e.g. toppings need Food).
    final overall = validateNewItem(
      name: name,
      description: description,
      priceText: _price.text,
      category: category,
      allowToppings: allowToppings,
      image: image,
    );
    if (overall != null) return;
    Navigator.of(context).pop(
      NewMenuItem(
        name: name,
        description: description,
        price: parseMenuPrice(_price.text)!,
        category: category,
        allowToppings: allowToppings,
        image: image,
      ),
    );
  }

  /// A scrollable dialog (fits large text and a narrow screen).
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.menuAddTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.errorText case final error?) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: maxMenuNameUnits,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.menuAddNameLabel,
              errorText: _nameError,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          TextField(
            controller: _description,
            maxLength: maxMenuDescriptionUnits,
            maxLines: 3,
            minLines: 1,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: l10n.menuAddDescriptionLabel,
              errorText: _descriptionError,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_descriptionError != null) {
                setState(() => _descriptionError = null);
              }
            },
          ),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: InputDecoration(
              labelText: l10n.menuPriceLabel,
              errorText: _priceError,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_priceError != null) setState(() => _priceError = null);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MenuCategory>(
            initialValue: _category,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.menuAddCategoryLabel,
              errorText: _categoryError,
              errorMaxLines: 3,
            ),
            items: [
              for (final category in MenuCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(
                    _categoryLabel(l10n, category),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              _category = value;
              _categoryError = null;
              // Only a food can take toppings; changing category resets it.
              _allowToppings = false;
            }),
          ),
          if (_category == MenuCategory.food)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.menuAddAllowToppingsLabel),
              value: _allowToppings,
              onChanged: (value) => setState(() => _allowToppings = value),
            ),
          const SizedBox(height: 4),
          TextField(
            controller: _image,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              LengthLimitingTextInputFormatter(_maxImageLength),
            ],
            decoration: InputDecoration(
              labelText: l10n.menuAddImageLabel,
              helperText: l10n.menuAddImageHelp,
              helperMaxLines: 4,
              errorText: _imageError,
              errorMaxLines: 4,
            ),
            onChanged: (_) {
              if (_imageError != null) setState(() => _imageError = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _confirm, child: Text(l10n.menuAddAction)),
      ],
    );
  }
}
