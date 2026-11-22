import 'package:flutter/material.dart';

import '../state/staff_credentials.dart';

/// Asks staff for the shared staff ID and password, pre-filled from
/// [StaffCredentialsHolder] when it already has them. Returns the typed
/// [StaffCredentials] on "Xác nhận", or null if staff cancel.
///
/// This dialog only gathers and checks the two values (same fields and
/// rules as the export dialog: no autofill, obscured password, a plain-
/// characters check via [StaffCredentials.isSendable]); it does not send
/// any request. The caller sends the request, decides what the server's
/// answer means, and updates or clears [StaffCredentialsHolder] itself.
///
/// [initialError] shows once, e.g. right after a 401 cleared the remembered
/// values and the caller is asking again.
Future<StaffCredentials?> showStaffLoginDialog(
  BuildContext context, {
  String title = 'Staff login',
  String? initialError,
}) => showDialog<StaffCredentials>(
  context: context,
  builder: (_) => _StaffLoginDialog(title: title, initialError: initialError),
);

class _StaffLoginDialog extends StatefulWidget {
  const _StaffLoginDialog({required this.title, this.initialError});

  final String title;
  final String? initialError;

  @override
  State<_StaffLoginDialog> createState() => _StaffLoginDialogState();
}

class _StaffLoginDialogState extends State<_StaffLoginDialog> {
  late final _id = TextEditingController(
    text: StaffCredentialsHolder.instance.value?.id ?? '',
  );
  late final _password = TextEditingController(
    text: StaffCredentialsHolder.instance.value?.password ?? '',
  );
  late String? _error = widget.initialError;

  @override
  void initState() {
    super.initState();
    _id.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  void _confirm() {
    final credentials = StaffCredentials(
      id: _id.text.trim(),
      password: _password.text.trim(),
    );
    if (!credentials.isSendable) {
      // Checked here: a browser would refuse such a header and it would
      // look like a network failure.
      setState(
        () => _error = 'Use plain letters, digits and symbols, no accents',
      );
      return;
    }
    Navigator.of(context).pop(credentials);
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm =
        _id.text.trim().isNotEmpty && _password.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      // Scrolls at large text; the buttons stay visible.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _id,
            enableSuggestions: false,
            autocorrect: false,
            // No autofill for either field: the shared password is meant to
            // live in memory only, not in every device's password manager.
            autofillHints: const [],
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(labelText: 'Staff ID'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [],
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(labelText: 'Staff password'),
            onSubmitted: (_) {
              if (canConfirm) _confirm();
            },
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canConfirm ? _confirm : null,
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
