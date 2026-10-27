import 'package:elutung/data/receipt_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pemasangan label ↔ nominal dua kolom: murni, tanpa Flutter/ML Kit.
void main() {
  BarisOcr baris(String teks, double kiri, double atas, double kanan, double bawah) =>
      BarisOcr(teks: teks, kiri: kiri, atas: atas, kanan: kanan, bawah: bawah);

  group('barisLabelTanpaAngka / barisAngkaBerdiriSendiri', () {
    test('label tanpa angka dikenali', () {
      expect(barisLabelTanpaAngka('TOTAL : Rp.'), isTrue);
      expect(barisLabelTanpaAngka('TOTAL 110.000'), isFalse);
      expect(barisLabelTanpaAngka('110.000'), isFalse);
    });

    test('angka berdiri sendiri dikenali', () {
      expect(barisAngkaBerdiriSendiri('110.000'), isTrue);
      expect(barisAngkaBerdiriSendiri('Rp 110.000'), isTrue);
      expect(barisAngkaBerdiriSendiri('TUNAI 100000'), isFalse);
    });
  });

  group('pasangLabelDuaKolom', () {
    test('label segaris dengan angka di kanan terpasangkan', () {
      final garis = [
        baris('TOTAL : Rp.', 10, 100, 200, 130),
        baris('110.000', 300, 102, 450, 128),
      ];
      expect(pasangLabelDuaKolom(garis), {0: 1});
    });

    test('angka di kiri label tidak dipasang', () {
      final garis = [
        baris('110.000', 10, 100, 150, 130),
        baris('TOTAL : Rp.', 300, 102, 450, 128),
      ];
      expect(pasangLabelDuaKolom(garis), isEmpty);
    });

    test('angka jauh secara vertikal tidak dipasang', () {
      final garis = [
        baris('TOTAL : Rp.', 10, 100, 200, 130),
        baris('110.000', 300, 500, 450, 530),
      ];
      expect(pasangLabelDuaKolom(garis), isEmpty);
    });

    test('tiap angka hanya dipakai sekali', () {
      final garis = [
        baris('TOTAL : Rp.', 10, 100, 200, 130),
        baris('TUNAI : Rp.', 10, 140, 200, 170),
        baris('110.000', 300, 102, 450, 128),
      ];
      final pasang = pasangLabelDuaKolom(garis);
      expect(pasang.length, 1);
    });
  });

  group('gabungDuaKolom', () {
    test('label tanpa angka digabung dengan pasangannya', () {
      const teks = 'TOKO MAJU\nTOTAL : Rp.\n110.000';
      final garis = [
        baris('TOKO MAJU', 10, 10, 200, 40),
        baris('TOTAL : Rp.', 10, 100, 200, 130),
        baris('110.000', 300, 102, 450, 128),
      ];
      final gabung = gabungDuaKolom(teks, garis);
      expect(gabung, contains('TOTAL : Rp. 110.000'));
    });

    test('jumlah baris beda → teks dikembalikan apa adanya', () {
      const teks = 'TOTAL : Rp.';
      final garis = [
        baris('TOTAL : Rp.', 10, 100, 200, 130),
        baris('110.000', 300, 102, 450, 128),
      ];
      expect(gabungDuaKolom(teks, garis), teks);
    });

    test('tanpa pasangan → teks tidak berubah', () {
      const teks = 'TOTAL 8000\nTUNAI 10000';
      final garis = [
        baris('TOTAL 8000', 10, 100, 200, 130),
        baris('TUNAI 10000', 10, 140, 200, 170),
      ];
      expect(gabungDuaKolom(teks, garis), teks);
    });
  });
}
