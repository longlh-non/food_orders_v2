import 'package:food_orders_backend/menu_slug.dart';
import 'package:test/test.dart';

final idRule = RegExp(r'^[a-z0-9][a-z0-9-]*$');

void main() {
  group('menuSlug', () {
    final cases = {
      'Xoi thit': 'xoi-thit',
      'Xôi Thịt': 'xoi-thit',
      'Đậu hũ chiên giòn': 'dau-hu-chien-gion',
      'ĐƯỜNG Nước Ép': 'duong-nuoc-ep',
      'Trà   đá': 'tra-da',
      '  --Cà phê!!  ': 'ca-phe',
      'Coca-Cola 330ml': 'coca-cola-330ml',
      'Bánh mì (đặc biệt) & trứng': 'banh-mi-dac-biet-trung',
      'ăâêôơư ắằẳẵặ ếềểễệ ốồổỗộ ớờởỡợ ứừửữự ýỳỷỹỵ':
          'aaeoou-aaaaa-eeeee-ooooo-ooooo-uuuuu-yyyyy',
    };
    cases.forEach((name, slug) {
      test('"$name" -> $slug', () => expect(menuSlug(name), slug));
    });

    test('decomposed tone marks are stripped too', () {
      expect(menuSlug('Xôi Thịt'), 'xoi-thit');
    });

    test('nothing usable left -> item', () {
      for (final name in ['!!!', '---', '   ', '🍜', 'ຂ້າວ', '🍜🍜 !!', '']) {
        expect(menuSlug(name), 'item', reason: name);
      }
    });

    test('very long name is cut to 48 and has no trailing dash', () {
      final long = menuSlug('a' * 200);
      expect(long, 'a' * 48);
      // The cut falls right after a dash: the dash is trimmed again.
      final name = '${'a' * 47} bbbb';
      expect(menuSlug(name), 'a' * 47);
      expect(menuSlug('xoi ${'b' * 100}').length, lessThanOrEqualTo(48));
    });

    test('every output matches the id rule', () {
      for (final name in [
        'Xôi',
        '!x',
        '-',
        '_a_',
        '9 lives',
        '🍜 phở',
        'Phở/Bò\n"x"',
        '../../etc/passwd',
        "'); DROP TABLE menu_items;--",
        'a' * 500,
        '%2e%2e',
        'ＡＢＣ',
      ]) {
        final slug = menuSlug(name);
        expect(idRule.hasMatch(slug), isTrue, reason: '$name -> $slug');
        expect(slug.length, lessThanOrEqualTo(48));
      }
    });
  });

  group('foldMenuText', () {
    test('case and accents are folded, other characters kept', () {
      expect(foldMenuText('Xôi THỊT'), 'xoi thit');
      expect(foldMenuText('đ'), 'd');
      expect(foldMenuText('A-b 1'), 'a-b 1');
    });
  });
}
