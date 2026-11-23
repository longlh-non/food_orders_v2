import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/locale_controller.dart';

void main() {
  test('defaults to Vietnamese when nothing is stored', () {
    final controller = LocaleController(readCode: () => null, writeCode: (_) {})
      ..init();
    expect(controller.locale, const Locale('vi'));
  });

  test('init restores a stored supported language and notifies', () {
    final controller = LocaleController(
      readCode: () => 'ja',
      writeCode: (_) {},
    );
    var calls = 0;
    controller.addListener(() => calls++);
    controller.init();
    expect(controller.locale, const Locale('ja'));
    expect(calls, 1);
  });

  test('init ignores a stored value that is not supported', () {
    final controller = LocaleController(readCode: () => 'xx', writeCode: (_) {})
      ..init();
    expect(controller.locale, const Locale('vi'));
  });

  test('setLocale updates locale, notifies and persists every call', () {
    final saved = <String>[];
    final controller = LocaleController(
      readCode: () => null,
      writeCode: saved.add,
    );
    var calls = 0;
    controller.addListener(() => calls++);

    controller.setLocale(const Locale('en'));
    expect(controller.locale, const Locale('en'));
    expect(calls, 1);
    expect(saved, ['en']);

    // Same language again: no rebuild needed, but the save is still attempted.
    controller.setLocale(const Locale('en'));
    expect(calls, 1);
    expect(saved, ['en', 'en']);
  });

  test('setLocale ignores an unsupported language', () {
    final saved = <String>[];
    final controller = LocaleController(
      readCode: () => null,
      writeCode: saved.add,
    );
    controller.setLocale(const Locale('xx'));
    expect(controller.locale, const Locale('vi'));
    expect(saved, isEmpty);
  });

  test('supported lists 10 languages, Vietnamese then English first', () {
    final codes = LocaleController.supported
        .map((l) => l.languageCode)
        .toList();
    expect(codes.take(2), ['vi', 'en']);
    expect(codes.toSet(), {
      'vi', 'en', 'zh', 'lo', 'es', 'fr', 'ru', 'de', 'ko', 'ja', //
    });
    expect(codes, hasLength(10));
  });

  test('the default controller works on the VM through the stub storage', () {
    // The stub stores nothing; this only proves it links and does not throw.
    LocaleController().init();
  });
}
