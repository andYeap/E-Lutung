import 'package:elutung/data/receipt.dart';
import 'package:flutter_test/flutter_test.dart';

/// Struk nyata dari perangkat: "NOTA PEMBELIAN" (Nanga Bulik).
///
/// Total 660.000 dan tunai 660.000 (bayar pas). Baris item memakai pola
/// "Nx harga total" — kalau parser salah, angka terbesar item (320.000) atau
/// salah satu harga bisa terambil.
void main() {
  const nota = '''
NOTA PEMBELIAN
Nanga Bulik
Kab. Lamandau
5 Okt 2026 09:31 #27
Visual Phone 2
SP BY.U 3GB
 5x 32.000 160.000
SP Simpati 3GB
 10x 32.000 320.000
Vcr 5GB 5hari
 3x 14.500 43.500
Vcr 9GB 1hari
 3x 29.000 87.000
Vcr 7GB 5hari
 3x 16.500 49.500
Total Rp660.000
Tunai Rp660.000
Terima kasih
''';

  test('mengambil Total 660.000, bukan angka item', () {
    final draft = parseReceipt(nota);
    expect(draft.nominal, 660000);
    expect(draft.yakin, isTrue);
  });

  test('membaca tanggal 5 Okt 2026', () {
    expect(parseReceipt(nota).tanggal, DateTime(2026, 10, 5));
  });

  test('tanpa label Total, bayar pas tidak ditebak', () {
    // Bila label Total hilang sementara Tunai tetap ada dan nilainya sama,
    // jangan menebak dari angka item.
    final tanpaTotal = nota.replaceFirst('Total Rp660.000\n', '');
    final draft = parseReceipt(tanpaTotal);
    expect(draft.nominal, isNot(320000));
  });

  // ---- Rayn's Meat & Frozenfood ------------------------------------------
  // Punya Subtotal, Total, Pay (Cash), dan Return sekaligus. Yang benar adalah
  // baris "Total" (127.000); Subtotal tidak boleh menang, dan Pay (Cash)
  // 150.000 / Return 23.000 tidak boleh dipakai.
  const rayns = '''
Rayn's
Rayn's Meat & Frozenfood
RF96+XH7, Nanga Bulik, Kec.
Bulik, Kabupaten Lamandau,
Kalimantan Tengah 74151,
Indonesia
14341782026062417554
No.228090-48085
2026-06-24  Cashier : Kasir T
17:15:54
Sarana Mix Belly 500gr
 1 X Rp 58,000        Rp 58,000
Central Roti Maryam 500gr
 1 X Rp 25,000        Rp 25,000
Mister Max Sobar Ayam 14
 1 X Rp 33,000        Rp 33,000
Delmonte BBQ 250gr
 1 X Rp 11,000        Rp 11,000
Total QTY : 4
Subtotal             Rp 127,000
Total                Rp 127,000
Pay (Cash)           Rp 150,000
Return               Rp 23,000
Teliti sebelum membeli.
''';

  test("Rayn's: ambil Total 127.000, bukan Subtotal/Pay/Return", () {
    final draft = parseReceipt(rayns);
    expect(draft.nominal, 127000);
    expect(draft.nominal, isNot(150000));
    expect(draft.nominal, isNot(23000));
    expect(draft.yakin, isTrue);
  });

  test("Rayn's: tanggal 2026-06-24", () {
    expect(parseReceipt(rayns).tanggal, DateTime(2026, 6, 24));
  });

  test("Rayn's: merchant bukan alamat", () {
    final merchant = parseReceipt(rayns).merchant;
    expect(merchant, isNotNull);
    expect(merchant!.toLowerCase(), isNot(contains('rf96')));
    expect(merchant.toLowerCase(), isNot(contains('kalimantan')));
  });

  // ---- Rayn's (kedua): Total == Pay (Cash) = 160.000 ---------------------
  const rayns2 = '''
Rayn's
Rayn's Meat & Frozenfood
RF96+XH7, Nanga Bulik, Kec.
Bulik, Kabupaten Lamandau,
Kalimantan Tengah 74151,
Indonesia
143417820250502213348
No.228080-42148
2026-05-02  Cashier : Kasir I
21:33:48
Sarana Premium Slice 500gr
 1 X Rp 80,000        Rp 80,000
Central Totila Besar Ori
 1 X Rp 35,000        Rp 35,000
Central Roti Maryam 500gr
 1 X Rp 25,000        Rp 25,000
Mayumi Mayo Hot 100gr
 1 X Rp 8,000         Rp 8,000
Saori Lada Hitam 133ml
 1 X Rp 12,000        Rp 12,000
Total QTY : 5
Subtotal             Rp 160,000
Total                Rp 160,000
Pay (Cash)           Rp 160,000
Teliti sebelum membeli.
IG. rayns.frozenfood
telp/WA. 085186869774
''';

  test("Rayn's kedua: Total 160.000, bukan harga item", () {
    final draft = parseReceipt(rayns2);
    expect(draft.nominal, 160000);
    expect(draft.nominal, isNot(80000));
    expect(draft.yakin, isTrue);
  });

  test("Rayn's kedua: tanggal 2026-05-02", () {
    expect(parseReceipt(rayns2).tanggal, DateTime(2026, 5, 2));
  });

  // ---- Borneo Supermaket (kedua): Total 130.800 --------------------------
  const borneo2 = '''
BORNEO SUPERMAKET
Jl. Batu Batanggui
Nanga Bulik, Lamandau
Telp. 082189785649
---------24-05-26 21:36 POS-01--------
B004-901-GRMOGBMHEPM CAD 1
--------------------------------------
RELAXA GRAPE MINT 125GR;PCS        6,400
ROSE BRAND GULA HIJAU 1KG;        21,200
YAMATO SARDEN 155GR;PCS            8,400
FORVITA MARGARIN 250;PCS          10,800
BERAS MANGGA MANIS 5KG;SAK        84,000
--------------------------------------
        TOTAL : Rp.    130,800
        T U N A I : Rp. 150,000
--------------------------------------
KEMBALIAN : Rp.         19,200
Item:5 , Qty:5
''';

  test('Borneo kedua: Total 130.800, bukan 150.000 tunai', () {
    final draft = parseReceipt(borneo2);
    expect(draft.nominal, 130800);
    expect(draft.yakin, isTrue);
  });

  test('Borneo kedua: tanggal 2026-05-24', () {
    expect(parseReceipt(borneo2).tanggal, DateTime(2026, 5, 24));
  });

  // ---- ANYA FROZEN FOOD: GRAND TOTAL 194.000 -----------------------------
  const anya = '''
ANYA FROZEN FOOD
081250896564
Jln. Batu Batanggui Rt 04 Nanga
Bulik
Kabupaten Lamandau KAL TENG
TGL : 06:56, 24/04/2026
KASIR : MASTER        NO PJL240426-185050
PEL : -               PEMB : TUNAI
BEEF SLICE LOW FAT 500GR
 1 Bks    x   62,000  =      62.000
AYAM SLICE 500GR
 1 Bks    x   40,000  =      40.000
KANZLER GARLIC FRANKFURTER 300GR
 1 Bks    x   45,000  =      45.000
MAKE BAKSO
 1 Bks    x   35,000  =      35.000
DELMONTE BARBEQUE SAUS 250GR
 1 Bks    x   12,000  =      12.000
TOT. ITEM            DISKON            Rp 0
5                    GRAND TOTAL :  Rp 194.000
                     TUNAI         :  Rp 200.000
                     KEMBALI       :  Rp 6.000
Terimakasih telah berbelanja
''';

  test('Anya: GRAND TOTAL 194.000, bukan tunai/kembali/diskon', () {
    final draft = parseReceipt(anya);
    expect(draft.nominal, 194000);
    expect(draft.yakin, isTrue);
  });

  test('Anya: tanggal 24/04/2026', () {
    expect(parseReceipt(anya).tanggal, DateTime(2026, 4, 24));
  });

  test('Anya: merchant bukan alamat/telepon', () {
    final merchant = parseReceipt(anya).merchant;
    expect(merchant, isNotNull);
    expect(merchant!.toLowerCase(), contains('anya'));
  });

  // ---- ANYA FROZEN FOOD kedua: GRAND TOTAL 194.000 -----------------------
  const anya2 = '''
ANYA FROZEN FOOD
081250896564
Jln Batu Batanggui Rt 04 Nanga
Bulik
Kabupaten Lamandau KALTENG
TGL : 07:42, 03/04/2026
KASIR : MASTER        NO PJL030426-192817
PEL : -               PEMB : TUNAI
BEEF SLICE WAGYU MELTIQUE 500G
 1 Bks    x   78,000  =   78.000
AYAM SLICE 500GR
 1 Bks    x   38,000  =   38.000
YONA SOSIS BAKAR MINI
 1 Bks    x   40,000  =   40.000
DELMONTE BARBEQUE SAUS 250GR
 1 Bks    x   12,000  =   12.000
KANZLER SINGLES BAKSO KEJU
 2 Bks    x   9,000  =   18.000
MARGARIN FORVITA 200GR
 1 Bks    x   8,000  =   8.000
TOT. ITEM    DISKON                Rp 0
7            GRAND TOTAL     :  Rp 194.000
             TUNAI           :  Rp 204.000
             KEMBALI         :  Rp 10.000
Terimakasih telah berbelanja
''';

  test('Anya kedua: GRAND TOTAL 194.000, bukan tunai 204.000', () {
    final draft = parseReceipt(anya2);
    expect(draft.nominal, 194000);
    expect(draft.yakin, isTrue);
  });

  test('Anya kedua: tanggal 03/04/2026', () {
    expect(parseReceipt(anya2).tanggal, DateTime(2026, 4, 3));
  });

  // ---- Dapur Jess Pusat: Total 104.000, Bayar 200.000 --------------------
  const dapurJess = '''
Dapur Jess
Pusat
Jl Trans Kalimantan KM3
Waktu        02 Jul 2026, 14:56
Bayar        Tunai
### LUNAS ###
Gromboloni
 35.000 x 1        35.000
Pisang Hijau
 15.000 x 1        15.000
Pisol maya/mentai
 6.000 x 1         6.000
Dadar Gulung psc
 4.000 x 1         4.000
Dimsum goreng
 10.000 x 1        10.000
Klapet Tart
 20.000 x 1        20.000
Bingka am bon
 14.000 x 1        14.000
Subtotal          104.000
Total (7)         104.000
Bayar             200.000
Kembali           96.000
''';

  test('Dapur Jess: Total 104.000, bukan Bayar 200.000', () {
    final draft = parseReceipt(dapurJess);
    expect(draft.nominal, 104000);
    expect(draft.yakin, isTrue);
  });

  test('Dapur Jess: tanggal 2 Jul 2026', () {
    expect(parseReceipt(dapurJess).tanggal, DateTime(2026, 7, 2));
  });

  test('Dapur Jess: tanpa label Total jangan ambil Bayar 200.000', () {
    final tanpaTotal = dapurJess.replaceFirst('Total (7)         104.000\n', '');
    final draft = parseReceipt(tanpaTotal);
    expect(draft.nominal, isNot(200000));
  });
}
