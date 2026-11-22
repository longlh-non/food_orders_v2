import 'package:food_orders_backend/shop_settings.dart';
import 'package:test/test.dart';

// Obviously fake test values; never real data.
Map<String, String?> goodEnv() => {
  'SHOP_NAME': 'HỘ KINH DOANH TEST',
  'SHOP_TAX_CODE': '0000000000-001',
  'SHOP_ADDRESS': '1 Đường Thử, Quận Giả, Thành phố Test',
  'SHOP_LOCATION': '2 Đường Thử Nghiệm',
  'SHOP_REPRESENTATIVE': 'Lê Văn Hưng',
  'BANK_BIN': '000000',
  'BANK_ACCOUNT': '1234567890',
  'BANK_ACCOUNT_NAME': 'LE VAN HUNG',
  'BANK_NAME': 'Ngân hàng Thử',
};

const shopVars = [
  'SHOP_NAME',
  'SHOP_TAX_CODE',
  'SHOP_ADDRESS',
  'SHOP_LOCATION',
  'SHOP_REPRESENTATIVE',
];
const bankVars = ['BANK_BIN', 'BANK_ACCOUNT', 'BANK_ACCOUNT_NAME', 'BANK_NAME'];

ShopSettings withEnv(Map<String, String?> changes) =>
    ShopSettings({...goodEnv(), ...changes});

void main() {
  test('all values valid: both flags on, values read back unchanged', () {
    final s = ShopSettings(goodEnv());
    expect(s.reportEnabled, isTrue);
    expect(s.transferEnabled, isTrue);
    expect(s.representative, 'Lê Văn Hưng');
    expect(s.shopName, 'HỘ KINH DOANH TEST');
    expect(s.taxCode, '0000000000-001');
    expect(s.bankBin, '000000');
    expect(s.bankAccount, '1234567890');
    expect(s.bankName, 'Ngân hàng Thử');
    expect(
      s.describe(),
      'shop details for reports: enabled\nbank transfer: enabled',
    );
  });

  test('values are trimmed', () {
    final s = withEnv({'SHOP_NAME': '  Quán Test \n', 'BANK_BIN': ' 000000 '});
    expect(s.shopName, 'Quán Test');
    expect(s.bankBin, '000000');
    expect(s.reportEnabled && s.transferEnabled, isTrue);
  });

  test('nothing set: both off, every name listed, no crash', () {
    final s = ShopSettings({});
    expect(s.reportEnabled, isFalse);
    expect(s.transferEnabled, isFalse);
    for (final name in [...shopVars, ...bankVars]) {
      expect(s.describe(), contains(name));
    }
  });

  for (final name in shopVars) {
    for (final bad in <String?>[null, '', '   ']) {
      test(
        '$name = ${bad == null ? 'missing' : "'$bad'"}: only reports off',
        () {
          final s = withEnv({name: bad});
          expect(s.reportEnabled, isFalse);
          expect(s.transferEnabled, isTrue);
          expect(
            s.describe(),
            'shop details for reports: disabled (missing or invalid: $name)\n'
            'bank transfer: enabled',
          );
        },
      );
    }
  }

  for (final name in bankVars) {
    for (final bad in <String?>[null, '', '   ']) {
      test(
        '$name = ${bad == null ? 'missing' : "'$bad'"}: only transfer off',
        () {
          final s = withEnv({name: bad});
          expect(s.transferEnabled, isFalse);
          expect(s.reportEnabled, isTrue);
          expect(
            s.describe(),
            'shop details for reports: enabled\n'
            'bank transfer: disabled (missing or invalid: $name)',
          );
        },
      );
    }
  }

  group('invalid values', () {
    final cases = <String, Map<String, String?>>{
      'tax code with a letter': {'SHOP_TAX_CODE': '12345A'},
      'tax code over 20 characters': {'SHOP_TAX_CODE': '1' * 21},
      'BIN with 5 digits': {'BANK_BIN': '12345'},
      'BIN with 7 digits': {'BANK_BIN': '1234567'},
      'BIN with a letter': {'BANK_BIN': '12345a'},
      'account with 20 digits': {'BANK_ACCOUNT': '1' * 20},
      'account with a dash': {'BANK_ACCOUNT': '123-456'},
      'name with a newline inside': {'SHOP_NAME': 'Quán\nTest'},
      'name with a tab': {'SHOP_NAME': 'Quán\tTest'},
      'name with NUL': {'SHOP_NAME': 'Quán\u0000Test'},
      'name with DEL': {'SHOP_NAME': 'Quán\u007FTest'},
      'name with a C1 character (NEL)': {'SHOP_NAME': 'Quán\u0085Test'},
      'name with U+2028 line separator': {'SHOP_NAME': 'Quán\u2028Test'},
      'name with U+2029 paragraph separator': {'SHOP_NAME': 'Quán\u2029Test'},
      'name over 200 characters': {'SHOP_NAME': 'a' * 201},
      'address over 200 characters': {'SHOP_ADDRESS': 'a' * 201},
      'location over 200 characters': {'SHOP_LOCATION': 'a' * 201},
      'representative over 100 characters': {'SHOP_REPRESENTATIVE': 'a' * 101},
      'account name over 100 characters': {'BANK_ACCOUNT_NAME': 'a' * 101},
      'bank name over 100 characters': {'BANK_NAME': 'a' * 101},
    };
    cases.forEach((label, change) {
      test(label, () {
        final s = withEnv(change);
        final name = change.keys.single;
        expect(
          name.startsWith('SHOP_') ? s.reportEnabled : s.transferEnabled,
          isFalse,
        );
        expect(s.describe(), contains(name));
      });
    });

    test('values at the limits are valid', () {
      final s = withEnv({
        'SHOP_NAME': 'a' * 200,
        'SHOP_TAX_CODE': '1' * 20,
        'BANK_ACCOUNT': '1' * 19,
        'BANK_ACCOUNT_NAME': 'a' * 100,
        'SHOP_ADDRESS': 'a' * 200,
        'SHOP_LOCATION': 'a' * 200,
        'SHOP_REPRESENTATIVE': 'a' * 100,
        'BANK_NAME': 'a' * 100,
      });
      expect(s.reportEnabled && s.transferEnabled, isTrue);
    });

    test('values of 1 character are valid', () {
      final s = withEnv({
        for (final n in [
          'SHOP_NAME',
          'SHOP_ADDRESS',
          'SHOP_LOCATION',
          'SHOP_REPRESENTATIVE',
          'BANK_ACCOUNT_NAME',
          'BANK_NAME',
        ])
          n: 'a',
        'SHOP_TAX_CODE': '1',
        'BANK_ACCOUNT': '1',
      });
      expect(s.reportEnabled && s.transferEnabled, isTrue);
    });
  });

  test('describe() never contains a configured value', () {
    final env = {
      'SHOP_NAME': 'Distinctive-Shop-Zq1',
      'SHOP_TAX_CODE': '7654321-9',
      'SHOP_ADDRESS': 'Distinctive-Address-Zq2',
      'SHOP_LOCATION': 'Distinctive-Location-Zq3',
      'SHOP_REPRESENTATIVE': 'Distinctive-Person-Zq4',
      'BANK_BIN': '987654',
      'BANK_ACCOUNT': '55566677788',
      'BANK_ACCOUNT_NAME': 'Distinctive-Holder-Zq5',
      'BANK_NAME': 'Distinctive-Bank-Zq6',
    };
    // Valid, and also with one invalid value, which must not be echoed.
    for (final e in [
      env,
      {...env, 'SHOP_TAX_CODE': 'Zq7-bad-letters', 'BANK_BIN': '98765x'},
    ]) {
      final text = ShopSettings(e).describe();
      for (final v in e.values) {
        expect(text, isNot(contains(v)));
      }
      expect(text, isNot(contains('Zq')));
    }
  });
}
