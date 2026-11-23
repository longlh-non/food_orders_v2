import 'package:flutter/material.dart';

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

/// What the "Loại báo cáo" dropdown offers: the label, the file name and the
/// MIME type for each [ExportReport].
extension on ExportReport {
  String get label => switch (this) {
    ExportReport.summary => 'Báo cáo tổng hợp theo ngày (Excel)',
    ExportReport.detail => 'Chi tiết từng đơn trong tháng (Excel)',
    ExportReport.lines => 'Danh sách dòng món (CSV)',
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
  String? _error;

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
      setState(
        () => _error = 'Chỉ dùng chữ không dấu, số và ký hiệu thông thường',
      );
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
            _error = 'Sai mã nhân viên hoặc mật khẩu';
          case ExportFailure.disabled:
            _error = 'Chức năng xuất dữ liệu đang tắt trên máy chủ';
          case ExportFailure.tooManyTries:
            final wait = e.retryAfterSeconds;
            _error = wait == null
                ? 'Thử sai quá nhiều lần. Vui lòng thử lại sau.'
                : 'Thử sai quá nhiều lần. Thử lại sau $wait giây.';
          case ExportFailure.notConfigured:
            _error = 'Chưa cài đặt thông tin quán trên máy chủ';
          case ExportFailure.other:
            _error = 'Không thể xuất dữ liệu. Thử lại.';
        }
      });
    } on Object {
      // Anything else (e.g. the browser refusing the download): the dialog
      // must not stay stuck "busy" with both buttons disabled.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Không thể xuất dữ liệu. Thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDownload =
        !_busy &&
        _id.text.trim().isNotEmpty &&
        _password.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Xuất đơn hàng theo tháng'),
      // Scrolls at large text; the buttons stay visible.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _month,
            decoration: const InputDecoration(labelText: 'Tháng'),
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
            decoration: const InputDecoration(labelText: 'Loại báo cáo'),
            items: [
              for (final r in [
                ExportReport.summary,
                ExportReport.detail,
                ExportReport.lines,
              ])
                DropdownMenuItem(value: r, child: Text(r.label)),
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
            decoration: const InputDecoration(labelText: 'Mã nhân viên'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [],
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(labelText: 'Mật khẩu nhân viên'),
            onSubmitted: (_) {
              if (canDownload) _download();
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
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: canDownload ? _download : null,
          child: const Text('Tải xuống'),
        ),
      ],
    );
  }
}
