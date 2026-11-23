import 'package:flutter/material.dart';

import '../../shared/api/order_api_client.dart';
import '../../shared/models/menu_item.dart';
import '../../shared/money.dart';
import '../api/menu_admin_client.dart';
import '../state/menu_admin_state.dart';
import '../state/staff_credentials.dart';
import '../widgets/staff_login_dialog.dart';

/// Staff screen for changing the menu: each item's price and its sold-out
/// switch. Opened from the AppBar of `OrdersPage` with a plain `Navigator.push`.
///
/// Loads the menu on open (spinner, error with a Retry button, or an empty
/// message). Staff type the shared staff ID and password in a dialog before
/// the first save; they stay in memory only ([StaffCredentialsHolder]).
/// Pass [state] in tests; the app lets the page build and own its own.
class MenuEditPage extends StatefulWidget {
  const MenuEditPage({super.key, this.state});

  /// A ready-made state (tests). When null the page creates and disposes one.
  final MenuAdminState? state;

  /// Creates the state object that owns the menu state and the dialogs.
  @override
  State<MenuEditPage> createState() => _MenuEditPageState();
}

class _MenuEditPageState extends State<MenuEditPage> {
  late final MenuAdminState _state =
      widget.state ??
      MenuAdminState(api: OrderApiClient(), admin: MenuAdminClient());

  /// Starts loading the menu once when the page opens.
  @override
  void initState() {
    super.initState();
    _state.load();
  }

  /// Releases the state only when this page made it; a state passed in
  /// belongs to the caller.
  @override
  void dispose() {
    if (widget.state == null) _state.dispose();
    super.dispose();
  }

  /// Makes sure credentials are in memory, asking staff when they are not,
  /// then runs [save]. When the server says the credentials are wrong the
  /// holder is cleared and staff are asked again (with that message) until
  /// they succeed, fail otherwise, or cancel (then nothing is saved).
  Future<void> _withCredentials(Future<MenuSaveResult> Function() save) async {
    _state.clearSaveError();
    String? initialError;
    while (true) {
      if (StaffCredentialsHolder.instance.value == null) {
        final typed = await showStaffLoginDialog(
          context,
          initialError: initialError,
        );
        if (typed == null || !mounted) return;
        StaffCredentialsHolder.instance.value = typed;
      }
      final result = await save();
      if (result != MenuSaveResult.needsCredentials || !mounted) return;
      // 401: the state already cleared the holder. The same text shows in
      // the dialog, so hide the banner copy.
      initialError = _state.saveError;
      _state.clearSaveError();
    }
  }

  /// Asks for a new price for [item], then saves it.
  Future<void> _editPrice(MenuItem item) async {
    final price = await showDialog<int>(
      context: context,
      builder: (_) => _PriceDialog(item: item),
    );
    if (price == null || !mounted) return;
    await _withCredentials(() => _state.setPrice(item.id, price));
  }

  /// Rows rebuild from [_state]: a spinner while loading, an error with
  /// Retry, an empty message, or the list with an error banner on top.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa thực đơn')),
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          if (!_state.hasLoaded) {
            if (_state.loadFailed) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Không tải được thực đơn.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _state.load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          if (_state.items.isEmpty) {
            return const Center(child: Text('Thực đơn đang trống.'));
          }
          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              if (_state.saveError case final error?)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              for (final item in _state.items)
                _MenuRow(
                  item: item,
                  saving: _state.isSaving(item.id),
                  onEditPrice: () => _editPrice(item),
                  onAvailable: (value) => _withCredentials(
                    () => _state.setAvailable(item.id, value),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One menu item: name, price and stock text, an "edit price" button and the
/// availability switch (on = in stock). Both controls are disabled while the
/// row is [saving], which shows a small spinner instead of the button.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.saving,
    required this.onEditPrice,
    required this.onAvailable,
  });

  final MenuItem item;
  final bool saving;
  final VoidCallback onEditPrice;
  final ValueChanged<bool> onAvailable;

  /// A list tile whose trailing side holds the two controls.
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.name),
      subtitle: Text(
        '${formatVnd(item.price)} · ${item.available ? 'Còn hàng' : 'Hết hàng'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saving)
            const SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Sửa giá ${item.name}',
              icon: const Icon(Icons.edit),
              onPressed: onEditPrice,
            ),
          Semantics(
            label: 'Còn hàng: ${item.name}',
            child: Switch(
              value: item.available,
              onChanged: saving ? null : onAvailable,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog asking for a new price of [item]. Returns the price in VND when
/// staff confirm a valid one (whole number 0 to 1.000.000), or null on
/// cancel. Invalid input shows a message and sends nothing.
class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.item});

  final MenuItem item;

  /// Creates the state that holds the text field and its error.
  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  late final _controller = TextEditingController(
    text: widget.item.price.round().toString(),
  );
  String? _error;

  /// Frees the text controller.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Closes with the price when valid, otherwise shows the error.
  void _confirm() {
    final price = parseMenuPrice(_controller.text);
    if (price == null) {
      setState(() => _error = 'Nhập số nguyên từ 0 đến 1.000.000');
      return;
    }
    Navigator.of(context).pop(price);
  }

  /// A scrollable dialog (fits large text) with one numeric field.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sửa giá ${widget.item.name}'),
      scrollable: true,
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Giá (VNĐ)', errorText: _error),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Lưu')),
      ],
    );
  }
}
