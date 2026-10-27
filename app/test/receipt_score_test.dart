import 'package:elutung/data/receipt.dart';
import 'package:elutung/data/receipt_score.dart';
import 'package:flutter_test/flutter_test.dart';

/// Skor pemilihan varian & quality gate: murni, tanpa perangkat.
void main() {
  ReceiptDraft draft({
    int? nominal,
    SumberNominal sumber = SumberNominal.tebakanAngka,
    bool tanggal = false,
    bool merchant = false,
  }) => ReceiptDraft(
    nominal: nominal,
    sumber: sumber,
    tanggal: tanggal ? DateTime(2026, 5, 1) : null,
    merchant: merchant ? 'Toko' : null,
  );

  group('skorDraft', () {
    test('urutan bukti: verifikasi > label > tebakan', () {
      expect(
        skorDraft(draft(nominal: 10000, sumber: SumberNominal.labelTotal)),
        greaterThan(skorDraft(draft(nominal: 10000))),
      );
      expect(
        skorDraft(
          draft(nominal: 10000, sumber: SumberNominal.pembayaranTerverifikasi),
        ),
        greaterThan(
          skorDraft(draft(nominal: 10000, sumber: SumberNominal.labelTotal)),
        ),
      );
    });

    test('draft kosong skornya nol', () {
      expect(skorDraft(const ReceiptDraft()), 0);
    });

    test('field terisi menambah skor dalam sumber yang sama', () {
      final polos = skorDraft(draft(nominal: 10000));
      final lengkap = skorDraft(
        draft(nominal: 10000, tanggal: true, merchant: true),
      );
      expect(lengkap, greaterThan(polos));
    });
  });

  group('indeksTerbaik', () {
    test('seri dimenangkan indeks terkecil (varian asli)', () {
      final daftar = [
        draft(nominal: 10000, sumber: SumberNominal.labelTotal),
        draft(nominal: 10000, sumber: SumberNominal.labelTotal),
      ];
      expect(indeksTerbaik(daftar), 0);
    });

    test('skor tertinggi menang walau bukan yang pertama', () {
      final daftar = [
        draft(nominal: 10000),
        draft(nominal: 10000, sumber: SumberNominal.labelTotal),
      ];
      expect(indeksTerbaik(daftar), 1);
    });
  });

  group('nilaiKualitasOcr', () {
    test('teks kosong → kosong', () {
      final r = nilaiKualitasOcr('   \n  ');
      expect(r.tingkat, KualitasOcr.kosong);
    });

    test('tanpa angka sama sekali → kosong', () {
      final r = nilaiKualitasOcr('TOKO MAJU\nJALAN MERDEKA\nTERIMA KASIH');
      expect(r.tingkat, KualitasOcr.kosong);
    });

    test('terlalu sedikit baris/angka → meragukan', () {
      final r = nilaiKualitasOcr('TOTAL\n110.000');
      expect(r.tingkat, KualitasOcr.meragukan);
      expect(r.alasan, isNotEmpty);
    });

    test('struk wajar → baik', () {
      final r = nilaiKualitasOcr(
        'TOKO MAJU\nJL MERDEKA 10\nINDOMIE 5000\nTEH 3000\n'
        'TOTAL 8000\nTUNAI 10000\nKEMBALI 2000\nTERIMA KASIH',
      );
      expect(r.tingkat, KualitasOcr.baik);
    });
  });
}
