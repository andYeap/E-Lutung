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

  test('sumber nominal menjelaskan asal angka', () {
    expect(
      parseReceipt('TOTAL : Rp. 110,000').sumber,
      SumberNominal.labelTotal,
    );
    expect(
      parseReceipt('Bimoli 43,800\nNutrijell 3,200').sumber,
      SumberNominal.tebakanAngka,
    );
  });

  // --- Huruf yang tertukar angka di dalam nominal ---

  test('huruf O di dalam nominal diperbaiki menjadi nol', () {
    // Tanpa ini parser hanya melihat digit "11" dan melaporkan 11.
    expect(parseReceipt('TOTAL : Rp. 11O.OOO').nominal, 110000);
  });

  test('huruf l di dalam nominal diperbaiki menjadi satu', () {
    // Tanpa ini tidak ada digit sama sekali, jadi nominalnya null.
    expect(parseReceipt('TOTAL : Rp. lO.OOO').nominal, 10000);
  });

  test('huruf S dan B di dalam nominal diperbaiki', () {
    expect(parseReceipt('TOTAL : Rp. 1l5.SOO').nominal, 115500);
    expect(parseReceipt('TOTAL : Rp. 4B.5OO').nominal, 48500);
  });

  test('perbaikan huruf tidak berlaku pada baris daftar barang', () {
    // Baris barang bukan baris nominal, jadi "B004" tidak boleh jadi 8004.
    expect(parseReceipt('Barang B004\nTOTAL 50.000').nominal, 50000);
  });

  // --- Label total yang huruf ekornya rusak ---

  test('label total dengan tanda baca tetap dikenali', () {
    final draft = parseReceipt('TOTA! : Rp. 110.000');
    expect(draft.nominal, 110000);
    expect(draft.yakin, isTrue);
  });

  test('label total dengan digit nyasar tetap dikenali', () {
    for (final label in ['TOTA5', 'T0TA!', 'TOTAl', 'T0TAL', 'TOTAI']) {
      expect(
        parseReceipt('$label : Rp. 110.000').nominal,
        110000,
        reason: 'label "$label" harusnya terbaca',
      );
    }
  });

  // --- Merchant ---

  test('merchant bukan label transaksi', () {
    // Label total pernah dipakai sebagai nama toko.
    for (final label in ['TOTAL', 'TOTA!', 'T0TA!', 'TOTA5']) {
      expect(
        parseReceipt('$label : Rp. 110.000').merchant,
        isNull,
        reason: 'baris berlabel "$label" bukan merchant',
      );
    }
  });

  test('merchant bukan alamat, dokumen, atau kalimat penutup', () {
    expect(
      parseReceipt('JL. MERDEKA NO. 10\nKASIR: BUDI\nTOTAL 50.000').merchant,
      isNull,
    );
    expect(
      parseReceipt('TERIMA KASIH TELAH BERKUNJUNGAN\nTOKO A\nTOTAL 50.000')
          .merchant,
      'TOKO A',
    );
    expect(
      parseReceipt('NPWP 01.234.567.8-901.000\nTOKO A\nTOTAL 50.000').merchant,
      'TOKO A',
    );
  });

  test('merchant tetap terbaca pada nama yang memuat singkatan pendek', () {
    // "Nova Mart" mengandung "no" dan "rt"; hanya boleh ditolak bila awalannya.
    expect(parseReceipt('NOVA MART\nTOTAL 50.000').merchant, 'NOVA MART');
    expect(parseReceipt('HYPERMARKET XYZ\nTOTAL 50.000').merchant, 'HYPERMARKET XYZ');
    expect(parseReceipt('INDOMARET\nTOTAL 7.500').merchant, 'INDOMARET');
  });

  test('merchant bukan garis pemisah struk', () {
    expect(
      parseReceipt('---------05-04-26 18:10 POS-SM--------\nTOTAL 110.000')
          .merchant,
      isNull,
    );
  });

  // --- Metode pembayaran ---

  test('nominal metode pembayaran tidak dipakai saat label total hilang', () {
    // Nilai yang ditagih kartu sama dengan total, jadi di sini masih dipakai.
    expect(parseReceipt('TOKO A\nTOTAL\nKARTU DEBIT 110.000').nominal, 110000);
  });

  test('QRIS tanpa label total tidak dipakai sebagai nominal', () {
    // 150.000 adalah uang yang diterima, bukan belanja — lebih baik kosong
    // daripada mencatat nominal keliru tanpa pengguna sadar.
    final draft = parseReceipt('WARUNG A\nQRIS 150.000\nKEMBALI 100.000');
    expect(draft.nominal, isNull);
    expect(draft.yakin, isFalse);
  });

  test('dana pada baris pembayaran tidak mengaburkan nama bank', () {
    expect(parseReceipt('TOKO A\nTOTAL 50.000\nDANA 50.000').nominal, 50000);
  });

  test('refund lebih besar tidak menimpa total', () {
    expect(parseReceipt('TOKO A\nREFUND 90.000\nTOTAL 40.000').nominal, 40000);
  });

  test('label total kosong tidak mencuri angka dari baris tunai', () {
    // Nol bukan nominal: baris "TOTAL : Rp." tidak boleh membuat parser melirik
    // ke bawah dan mengambil 150.000 dari baris tunai.
    final draft = parseReceipt('TOTAL : Rp.\nT U N A I : Rp. 150,000');
    expect(draft.nominal, isNull);
  });

  test('label terpisah beberapa baris tetap membaca nominalnya', () {
    expect(parseReceipt('TOTAL\nBAYAR\n33.000').nominal, 33000);
    expect(parseReceipt('TOTAL : Rp\n33.000').nominal, 33000);
  });

  test('baris tanpa digit asli tidak dihitung meski mirip kata', () {
    // "BAYAR" bisa jadi "8AYAR" setelah normalisasi huruf; itu bukan nominal.
    expect(parseReceipt('TOTAL\nBAYAR\n33.000').nominal, 33000);
  });

  // --- Tanggal ---

  test('tanggal di masa depan ditolak', () {
    // Struk dicetak saat transaksi terjadi, jadi tanggalnya tidak mungkin
    // belum terjadi.
    expect(parseReceipt('WARUNG\n31/12/2099\nTOTAL 50.000').tanggal, isNull);
  });

  test('delapan digit tanpa pemisah dibaca sebagai tanggal', () {
    expect(parseReceipt('TOKO\n20260512\nTOTAL 50.000').tanggal, DateTime(2026, 5, 12));
  });

  test('delapan digit baca rupiah tidak dianggap tanggal', () {
    // "12052026" dekat mata uang lebih mungkin nominal besar.
    expect(parseReceipt('TOKO\nTOTAL Rp 12052026').tanggal, isNull);
  });

  // --- Kasus nyata dari pengujian di perangkat ---------------------------
  //
  // Di HP, struk Borneo Supermaket terbaca "TOTAL : Rp. 110,000" tapi
  // aplikasi mengisi 150.000 — angka TUNAI — dan aplikasi menampilkan
  // peringatan "ditebak dari angka terbesar". Untuk tebakan sebesar itu,
  // baris TUNAI wajib tidak terbaca sebagai tunai.
  //
  // Penyebabnya asimetri: teks baris dilipat (1->l) tapi kata kunci tidak.
  // "TUNAI" yang huruf terakhirnya salah baca jadi "1" terlipat menjadi
  // "tunal", sedangkan kata kunci tetap "tunai" — jadi tidak cocok, dan baris
  // uang diterima lolos dari daftar abaikan.

  test('TUNAI dengan huruf terakhir salah baca tetap diabaikan', () {
    for (final tf in ['TUNAI', 'TUNA1', 'TUNAI', 'TUN A1', 'T U N A 1']) {
      final draft = parseReceipt('TOTAL : Rp. 110,000\n$tf : Rp. 150,000');
      expect(
        draft.nominal,
        110000,
        reason: '"$tf" adalah uang diterima, bukan total',
      );
    }
  });

  test('KEMBALI dengan huruf salah baca tetap diabaikan', () {
    for (final kb in ['KEMBALI', 'KEMBA11', 'KEMBAL1', 'KEMBA L I']) {
      expect(
        parseReceipt('TOTAL : Rp. 110,000\n$kb : Rp. 40,000').nominal,
        110000,
        reason: '"$kb" adalah kembalian, bukan total',
      );
    }
  });

  test('pencocokan kata abaikan tetap berlaku untuk huruf i dan l', () {
    // Lipatan simetris tidak boleh mematikan kata abaikan yang mengandung i:
    // "invoice" -> "lnvolce" di kedua sisi, jadi tetap cocok.
    expect(parseReceipt('WARUNG A\nINVOICE 12345\nTOTAL 50.000').nominal, 50000);
  });

  test('struk perangkat: total beats tunai dan kembalian', () {
    final draft = parseReceipt('''
BORNEO SUPERMAKET
Jl. Batu Batanggui
Nanga Bulik, Lamandau
Telp. 082189785649
---------05-04-26 18:10 POS-SM--------
B004-900-GRMBMDMMEEP CAD 0
BIMOLI KLASIK RF 2L;PCS 43,800
LARISSA KR.SGKG 250G;PCS 6,300
SUPERPELL PINK RF 770 ML;PC 13,400
SEDAAP KCP MANIS SPC RF 220 8,200
MAMASUKA SAUS BULGOGI 160 M 7,700
FOXS BERRIES OVAL 125GR;PCS 6,500
HACHIKO CABEBRK 5*25;PCS 10,300
DESAUK MANSIBHA TMPEKIN 6K15G;PCS 6,200
C1 2 x 5.300,00 10,600
NUTRIJELL COKLAT 20GR;PCS 3,200
TOTAL : Rp. 110,000
T U N A I : Rp. 150,000
KEMBALIAN : Rp. 40,000
Item:9 , Qty:10
''');
    expect(draft.nominal, 110000);
    expect(draft.yakin, isTrue);
    expect(draft.merchant, 'BORNEO SUPERMAKET');
  });

  // --- Teks OCR asli dari perangkat (dua kolom) ---------------------------
  //
  // ML Kit mengembalikan label dan nominal sebagai blok terpisah: "TOTAL : Rp."
  // tanpa angka, sementara 110.000 berdiri sendiri belasan baris di bawahnya.
  // Parser berbasis label tidak akan pernah menemukan pasangannya, dan tebakan
  // "angka terbesar" mengambil TUNAI 150.000 untuk belanja 110.000.
  //
  // Yang menyelamatkan struk ini adalah identitas aritmetika pembayaran tunai
  // yang bisa diuji: 150.000 - 40.000 = 110.000.
  const ocrDuaKolom = '''
-05-04-26 18:18 POS-SM--
BO04-900-GRMBMOMMEEP CAD 0
BORNEO SUPERMAKET
Jl, Batu Batanggui
Nanga Bulik, Lamandau
Telp. 082189785649
BIMOLI KLASIK RF 2L.;PCS
LARISSA KR.SGKG 250G;PCS
SUPERPELL PINK RF 770 ML;PC
SEDAAP KCP MANIS SPC RF 220
NAMASUKA SAUS BULGOGI 160 M
FOXS BERRIES OVAL 125GR;PCS
HACHIKO CABERBK 5825; PCS
DESAKU MRNSIBMB THPERIKN 6*15G;PCS
2 x 5,300.00
C1
NUTRIJELL COKLAT 20GR;PCS
Item:9
TOTAL : Rp.
TUNA I: Rp.
KEMBA LIAN : Rp.
1 @ty :10
43,800
6, 300
13,400
8,200
7,700
6,500
10,300
10,600
3,200
110,000
150,000
40,000
Terinakasih atas kunjungan anda
Belanja Hemat Pelay anan Bersahabat
INGAT BELANJA *. INGAT .. BORNEO
''';

  test('struk dua kolom: total dari identitas tunai - kembalian', () {
    final draft = parseReceipt(ocrDuaKolom);
    expect(draft.nominal, 110000);
    expect(draft.yakin, isTrue);
    expect(draft.sumber, SumberNominal.pembayaranTunai);
    expect(draft.merchant, 'BORNEO SUPERMAKET');
    expect(draft.tanggal, DateTime(2026, 4, 5));
  });

  test('struk dua kolom: bayar pas tanpa kembalian', () {
    // Bayar pas: uang diterima sama dengan total, jadi kembalian nol dan tidak
    // dicetak. Dua angka terakhir pada blok nominal sama besar.
    final draft = parseReceipt(
      ocrDuaKolom.replaceAll('150,000', '110,000').replaceAll('40,000\n', ''),
    );
    expect(draft.nominal, 110000);
    expect(draft.sumber, SumberNominal.pembayaranTunai);
  });

  test('struk dua kolom tanpa kembalian tidak menebak TUNAI', () {
    // Kembalian hilang, jadi identitas tidak bisa diuji. Angka terbesar di
    // blok nominal adalah uang yang diterima, jadi nominal dibiarkan kosong.
    final draft = parseReceipt(ocrDuaKolom.replaceAll('40,000\n', ''));
    expect(draft.nominal, isNull);
    expect(draft.yakin, isFalse);
  });

  test('kode transaksi tidak dianggap merchant', () {
    // "BO04-900-GRMBMOMMEEP CAD 0" tercetak sebelum nama toko dan hurufnya
    // melekat ke angka, cirinya kode bukan nama.
    expect(
      parseReceipt('BO04-900-GRMBMOMMEEP CAD 0\nBORNEO SUPERMAKET\nTOTAL 50.000')
          .merchant,
      'BORNEO SUPERMAKET',
    );
  });

  test('nama toko berangka tetap terbaca', () {
    // Angka yang terpisah spasi bukan kode, jadi "7 ELEVEN" tetap nama.
    expect(parseReceipt('7 ELEVEN\nTOTAL 50.000').merchant, 'ELEVEN');
  });
}
