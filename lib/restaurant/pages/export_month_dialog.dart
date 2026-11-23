import 'package:flutter/material.dart';

import '../../shared/l10n.dart';
import '../api/export_client.dart';
import '../download/save_file.dart' as download;
import '../state/staff_credentials.dart';

/// Saves downloaded bytes as a file. The real one uses the browser; tests
/// pass a fake so no browser API runs.
typedef SaveFile = void Function(
  List<int> bytes,
  String fileName,
  String mimeType,
);

/// The last 12 months as `YYYY-MM`, newest first, starting with [now]'s.
List<String> recentMonths(DateTime now) => [
  for (var i = 0; i < 12; i++)
    () {
      final d = DateTime(now.year, now.month - i);
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}';
    }(),
];

/// What the report dropdown offers: the label (in the language of an
/// [AppLocalizations]), the file name and the MIME type for each
/// [ExportReport]. File names stay as the server and the owner know them.
extension on ExportReport {
  String label(AppLocalizations l10n) => switch (this) {
    ExportReport.summary => l10n.exportSummaryOption,
    ExportReport.detail => l10n.exportDetailOption,
    ExportReport.lines => l10n.exportLinesOption,
  };

  String fileName(String month) => switch (this) {
    ExportReport.summary => 'bao-cao-tong-hop-$month.xlsx',
    ExportReport.detail => 'chi-tiet-$month.xlsx',
    ExportReport.lines => 'orders-$month.csv',
  };

  String get mimeType => switch (this) {
    ExportReport.lines => 'text/csv;charset=utf-8',
    _ => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };
}

/// Opens the "Export month" dialog: pick a month, type the staff ID and
/// password, choose a report (two Excel reports or the CSV), download it.
///
/// The staff ID and password are kept only in memory
/// ([StaffCredentialsHolder]) so staff type them once per visit; wrong ones
/// clear both. Errors show short fixed texts.
Future<void> showExportMonthDialog(
  BuildContext context, {
  ExportClient? client,
  SaveFile? saveFile,
  DateTime? now,
}) {
  // Our own client is closed once the dialog is gone; an injected one
  // belongs to the caller.
  final own = client == null ? ExportClient() : null;
  return showDialog<void>(
    context: context,
    builder: (_) => _ExportMonthDialog(
      client: client ?? own!,
      saveFile: saveFile ?? download.saveFile,
      months: recentMonths(now ?? DateTime.now()),
    ),
  ).whenComplete(() => own?.close());
}

class _ExportMonthDialog extends StatefulWidget {
  const _ExportMonthDialog({
    required this.client,
    required this.saveFile,
    required this.months,
  });

  final ExportClient client;
  final SaveFile saveFile;
  final List<String> months;

  @override
  State<_ExportMonthDialog> createState() => _ExportMonthDialogState();
}

class _ExportMonthDialogState extends State<_ExportMonthDialog> {
  late String _month = widget.months.first;
  late final _id = TextEditingController(
    text: StaffCredentialsHolder.instance.value?.id ?? '',
  );
  late final _password = TextEditingController(
    text: StaffCredentialsHolder.instance.value?.password ?? '',
  );
  var _report = ExportReport.summary;
  var _busy = false;
  _ExportError? _error;

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

  StaffCredentials get _credentials =>
      StaffCredentials(id: _id.text.trim(), password: _password.text.trim());

  Future<void> _download() async {
    final credentials = _credentials;
    if (!credentials.isSendable) {
      // Checked here: a browser would refuse such a header and it would
      // look like a network failure.
      setState(() => _error = const _ExportError(_ExportErrorKind.plainChars));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await widget.client.fetchMonth(
        _month,
        report: _report,
        credentials: credentials,
      );
      StaffCredentialsHolder.instance.value = credentials;
      widget.saveFile(bytes, _report.fileName(_month), _report.mimeType);
      if (mounted) Navigator.of(context).pop();
    } on ExportException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (e.failure) {
          case ExportFailure.wrongCredentials:
            // Forget both, so wrong ones aren't sent again next time. One
            // message: the server doesn't say which half was wrong.
            StaffCredentialsHolder.instance.clear();
            _id.clear();
            _password.clear();
            _error = const _ExportError(_ExportErrorKind.wrongCredentials);
          case ExportFailure.disabled:
            _error = const _ExportError(_ExportErrorKind.disabled);
          case ExportFailure.tooManyTries:
            _error = _ExportError(
              _ExportErrorKind.tooManyTries,
              waitSeconds: e.retryAfterSeconds,
            );
          case ExportFailure.notConfigured:
            _error = const _ExportError(_ExportErrorKind.notConfigured);
          case ExportFailure.other:
            _error = const _ExportError(_ExportErrorKind.other);
        }
      });
    } on Object {
      // Anything else (e.g. the browser refusing the download): the dialog
      // must not stay stuck "busy" with both buttons disabled.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = const _ExportError(_ExportErrorKind.other);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canDownload =
        !_busy &&
        _id.text.trim().isNotEmpty &&
        _password.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(l10n.exportTitle),
      // Scrolls at large text; the buttons stay visible.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _month,
            decoration: InputDecoration(labelText: l10n.exportMonthLabel),
            items: [
              for (final m in widget.months)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: _busy
                ? null
                : (m) => setState(() => _month = m ?? _month),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ExportReport>(
            initialValue: _report,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.exportReportLabel),
            items: [
              for (final r in [
                ExportReport.summary,
                ExportReport.detail,
                ExportReport.lines,
              ])
                DropdownMenuItem(value: r, child: Text(r.label(l10n))),
            ],
            onChanged: _busy
                ? null
                : (r) => setState(() => _report = r ?? _report),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _id,
            enableSuggestions: false,
            autocorrect: false,
            // No autofill for either field: the shared password is meant to
            // live in memory only, not in every device's password manager.
            autofillHints: const [],
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(labelText: l10n.staffIdLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [],
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(labelText: l10n.staffPasswordLabel),
            onSubmitted: (_) {
              if (canDownload) _download();
            },
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                error.text(l10n),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: canDownload ? _download : null,
          child: Text(l10n.commonDownload),
        ),
      ],
    );
  }
}

/// Which error the dialog shows. Kept as data (not text) so a language switch
/// while it is on screen re-translates it.
enum _ExportErrorKind {
  plainChars,
  wrongCredentials,
  disabled,
  tooManyTries,
  notConfigured,
  other,
}

class _ExportError {
  const _ExportError(this.kind, {this.waitSeconds});

  final _ExportErrorKind kind;

  /// Seconds to wait, for [_ExportErrorKind.tooManyTries] when the server said.
  final int? waitSeconds;

  /// The message in the language of [l10n].
  String text(AppLocalizations l10n) => switch (kind) {
    _ExportErrorKind.plainChars => l10n.staffPlainCharsError,
    _ExportErrorKind.wrongCredentials => l10n.staffWrongCredentials,
    _ExportErrorKind.disabled => l10n.exportDisabled,
    _ExportErrorKind.tooManyTries =>
      waitSeconds == null
          ? l10n.tooManyTriesLater
          : l10n.tooManyTriesWait(waitSeconds!),
    _ExportErrorKind.notConfigured => l10n.exportNotConfigured,
    _ExportErrorKind.other => l10n.exportFailed,
  };
}
