import 'package:elutung/util/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThousandsInputFormatter (FR-2.6)', () {
    const f = ThousandsInputFormatter();

    TextEditingValue apply(String text) =>
        f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

    test('menambahkan pemisah ribuan gaya Indonesia', () {
      expect(apply('25000').text, '25.000');
      expect(apply('1000000').text, '1.000.000');
    });

    test('membuang karakter non-digit', () {
      expect(apply('1a2b3').text, '123');
      expect(apply('Rp 50.000').text, '50.000');
    });

    test('kosong tetap kosong', () {
      expect(apply('').text, '');
    });
  });

  test('parseRupiah membaca kembali nilai berformat', () {
    expect(parseRupiah('25.000'), 25000);
    expect(parseRupiah('Rp 1.250.000'), 1250000);
    expect(parseRupiah(''), 0);
  });
}
