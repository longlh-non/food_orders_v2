import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/locale_controller.dart';

/// Reads one ARB file as plain JSON (no generated code involved).
Map<String, dynamic> _read(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

/// The message keys of an ARB map: everything except `@key` metadata and
/// `@@locale`.
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  final files =
      Directory('lib/shared/l10n')
          .listSync()
          .whereType<File>()
          .where((f) => RegExp(r'app_[a-z]+\.arb$').hasMatch(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('there is one ARB file for each supported locale', () {
    final codes = files
        .map((f) => RegExp(r'app_([a-z]+)\.arb$').firstMatch(f.path)!.group(1))
        .toSet();
    expect(codes, {for (final l in LocaleController.supported) l.languageCode});
    expect(codes, hasLength(10));
  });

  test('all ARB files have exactly the same message keys', () {
    final template = _messageKeys(
      _read(files.firstWhere((f) => f.path.endsWith('app_vi.arb'))),
    );
    expect(template, isNotEmpty);
    for (final file in files) {
      final arb = _read(file);
      expect(_messageKeys(arb), template, reason: file.path);
      final code = RegExp(r'app_([a-z]+)\.arb$')
          .firstMatch(file.path)!
          .group(1);
      expect(arb['@@locale'], code, reason: file.path);
    }
  });

  test('no translation is empty and every one keeps its placeholders', () {
    final vi = _read(files.firstWhere((f) => f.path.endsWith('app_vi.arb')));
    final holders = RegExp(r'\{(\w+)[,}]');
    for (final file in files) {
      final arb = _read(file);
      for (final key in _messageKeys(vi)) {
        final text = arb[key] as String;
        expect(text.trim(), isNotEmpty, reason: '${file.path} $key');
        final expected = holders.allMatches(vi[key] as String).map((m) => m[1]);
        for (final name in expected.toSet()) {
          expect(text, contains('{$name'), reason: '${file.path} $key');
        }
      }
    }
  });
}
