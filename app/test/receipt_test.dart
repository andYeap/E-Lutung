import 'package:elutung/data/receipt.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pengurai teks struk (murni).
void main() {
  test('mengambil total, bukan tunai/kembali/subtotal', () {
    final draft = parseReceipt('''
TOKO SEGAR
Jl. Merdeka No. 10
Subtotal 100.000
PPN 10.000
TOTAL 110.000
TUNAI 150.000
KEMBALI 40.000
''');
    expect(draft.nominal, 110000);
  });

  test('mendukung "Grand Total" dengan prefix Rp dan pemisah titik', () {
    final draft = parseReceipt('Grand Total Rp 98.500');
    expect(draft.nominal, 98500);
  });

  test('membaca tanggal numerik dd/mm/yyyy', () {
    final draft = parseReceipt('12/05/2026\nTotal 25.000');
    expect(draft.tanggal, DateTime(2026, 5, 12));
  });

  test('membaca tanggal dengan nama bulan Indonesia', () {
    final draft = parseReceipt('Warung Bu Tini\n12 Mei 2026\nJumlah Bayar 18.000');
    expect(draft.tanggal, DateTime(2026, 5, 12));
    expect(draft.nominal, 18000);
  });

  test('merchant diambil dari baris berhuruf pertama', () {
    final draft = parseReceipt('   \nKOPI KENANGAN\nTotal 20.000');
    expect(draft.merchant, 'KOPI KENANGAN');
  });

  test('cadangan: ambil angka terbesar bila tak ada kata kunci total', () {
    final draft = parseReceipt('Toko A\nBarang 15.000\nBarang 25.000');
    expect(draft.nominal, 25000);
  });

  test('mengabaikan nomor telepon saat memilih angka terbesar', () {
    final draft = parseReceipt('Toko A\nTelp 081234567890\nBelanja 30.000');
    expect(draft.nominal, 30000);
  });

  test('tanpa angka yang masuk akal menghasilkan nominal null', () {
    final draft = parseReceipt('Terima kasih\nSampai jumpa');
    expect(draft.nominal, isNull);
  });

  test('nominal di baris berikutnya setelah kata kunci', () {
    final draft = parseReceipt('Warung\nTOTAL\n110.000\nTUNAI 150.000');
    expect(draft.nominal, 110000);
  });

  test('grand total menang atas total biasa, tunai diabaikan', () {
    final draft = parseReceipt('''
TOTAL 100.000
GRAND TOTAL 110.000
TUNAI 150.000
''');
    expect(draft.nominal, 110000);
  });

  test('mendukung tanggal ISO yyyy-mm-dd', () {
    final draft = parseReceipt('2026-05-12\nTotal 30.000');
    expect(draft.tanggal, DateTime(2026, 5, 12));
  });

  test('membuang desimal di belakang (,00) tanpa membesarkan nominal', () {
    expect(parseReceipt('Total Rp 33.000,00').nominal, 33000);
    expect(parseReceipt('Grand Total 1.234.567,89').nominal, 1234567);
  });

  test('ribuan dengan koma tetap dibaca benar', () {
    expect(parseReceipt('Total Rp 125,500').nominal, 125500);
  });

  test('label total terpisah beberapa baris', () {
    expect(parseReceipt('TOTAL\nBAYAR\n33.000').nominal, 33000);
  });

  test('tanggal tidak pernah dipilih sebagai nominal', () {
    final draft = parseReceipt('12.05.2026\nKopi 18.000\nRoti 22.000');
    expect(draft.nominal, 22000);
  });

  test('struk minimarket lengkap', () {
    final draft = parseReceipt('''
INDOMARET
JL SUDIRMAN 12
TELP 021-5551234
12/05/2026 14:30
Indomie 3.500
Air 4.000
TOTAL 7.500
TUNAI 10.000
KEMBALI 2.500
''');
    expect(draft.nominal, 7500);
    expect(draft.merchant, 'INDOMARET');
    expect(draft.tanggal, DateTime(2026, 5, 12));
  });

  test('struk restoran dengan pajak', () {
    final draft = parseReceipt('''
RM PADANG
Nasi 25.000
Ayam 15.000
Subtotal 40.000
PB1 4.000
Total 44.000
''');
    expect(draft.nominal, 44000);
  });

  test('struk minimarket nyata (Borneo Supermaket)', () {
    final draft = parseReceipt('''
BORNEO SUPERMAKET
Jl. Batu Batanggui
Nanga Bulik, Lamandau
Telp. 082189785649
---------05-04-26 18:10 POS-SM--------
B004-900-GRMBMDMMEEP CAD 0
--------------------------------------
BIMOLI KLASIK RF 2L;PCS        43,800
LARISSA KR.SGKG 250G;PCS        6,300
SUPERPELL PINK RF 770 ML;PC    13,400
SEDAAP KCP MANIS SPC RF 220     8,200
MAMASUKA SAUS BULGOGI 160 M     7,700
FOXS BERRIES OVAL 125GR;PCS     6,500
HACHIKO CABEBRK 5*25;PCS       10,300
C1   2 x   5,300.00            10,600
NUTRIJELL COKLAT 20GR;PCS       3,200
--------------------------------------
        TOTAL : Rp.    110,000
        T U N A I : Rp. 150,000
--------------------------------------
KEMBALIAN : Rp.         40,000
Item:9 , Qty:10
--------------------------------------
Terimakasih atas kunjungan anda
''');
    expect(draft.nominal, 110000);
    expect(draft.merchant, 'BORNEO SUPERMAKET');
    expect(draft.tanggal, DateTime(2026, 4, 5));
  });

  test('kata "TOTAL" yang salah baca OCR tetap dikenali', () {
    expect(parseReceipt('T0TAL : Rp. 110.000').nominal, 110000);
    expect(parseReceipt('TOTA1 : Rp. 45.500').nominal, 45500);
  });

  test('ribuan yang dipisah spasi oleh OCR', () {
    expect(parseReceipt('TOTAL   110 000').nominal, 110000);
    expect(parseReceipt('TOTAL 1 250 000').nominal, 1250000);
  });

  test('kata berjarak huruf (T O T A L / T U N A I) tetap dikenali', () {
    final draft = parseReceipt('''
T O T A L : Rp. 110,000
T U N A I : Rp. 150,000
K E M B A L I A N : Rp. 40,000
''');
    expect(draft.nominal, 110000);
  });

  test('baris T U N A I berjarak diabaikan walau tanpa kata total', () {
    final draft = parseReceipt('''
Bimoli 43,800
Nutrijell 3,200
T U N A I : Rp. 150,000
''');
    expect(draft.nominal, 43800);
  });

  test('tidak mencuri angka tunai saat total kosong', () {
    // Bila nominal total hilang, jangan ambil dari baris tunai di bawahnya.
    final draft = parseReceipt('''
TOTAL : Rp.
T U N A I : Rp. 150,000
''');
    expect(draft.nominal, isNull);
  });

  test('kata berjarak dengan titik atau strip tetap dikenali', () {
    expect(
      parseReceipt('Bimoli 43,800\nT.U.N.A.I : Rp. 150,000').nominal,
      43800,
    );
    expect(
      parseReceipt('T-O-T-A-L : Rp. 110,000\nT-U-N-A-I : Rp. 150,000').nominal,
      110000,
    );
  });

  test('penanda keyakinan: dari baris total vs tebakan', () {
    expect(parseReceipt('TOTAL : Rp. 110,000').yakin, isTrue);
    expect(parseReceipt('Bimoli 43,800\nNutrijell 3,200').yakin, isFalse);
  });
}
