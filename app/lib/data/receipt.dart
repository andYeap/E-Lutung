import 'dart:math' as math;

/// Dari mana angka nominal datang — dipakai layar review untuk memberi tahu
/// pengguna seberapa perlu nilai itu diperiksa.
enum SumberNominal {
  /// Baris berlabel total/jumlah bayar yang nominalnya terbaca.
  labelTotal,

  /// Angka terbesar pada baris yang bukan telepon/nomor dokumen.
  tebakanAngka,
}

/// Hasil pembacaan struk. Semua field opsional: nilai yang tak terbaca menjadi
/// null dan dibiarkan diisi pengguna di form review.
class ReceiptDraft {
  const ReceiptDraft({
    this.nominal,
    this.tanggal,
    this.merchant,
    this.sumber = SumberNominal.tebakanAngka,
  });

  final int? nominal;
  final DateTime? tanggal;
  final String? merchant;
  final SumberNominal sumber;

  /// true bila nominal diambil dari baris berlabel total, bukan dari tebakan
  /// "angka terbesar". Dipakai layar review untuk memperingatkan pengguna.
  bool get yakin => nominal != null && sumber == SumberNominal.labelTotal;

  bool get kosong => nominal == null && tanggal == null && merchant == null;
}

/// Kata kunci prioritas tinggi: hampir pasti baris total/jumlah akhir.
const List<String> _kataKunciTotalKuat = [
  'grand total',
  'total bayar',
  'jumlah bayar',
  'total akhir',
  'harus dibayar',
  'total tagihan',
  'total pembayaran',
];

/// Kata kunci prioritas lebih rendah (bisa juga judul item).
const List<String> _kataKunciTotalLemah = [
  'total harga',
  'total belanja',
  'subtotal akhir',
  'tagihan',
  'jumlah',
  'netto',
  'total',
];

/// Kata kunci yang membuat sebuah baris diabaikan sebagai calon total.
///
/// Dua kelompok: komponen/pengurang (subtotal, pajak, diskon) dan **uang yang
/// diterima toko** (tunai, kartu, QRIS, saldo awal). Golongan kedua penting
/// karena nilainya bisa lebih besar dari total — memakainya sebagai nominal
/// akan mencatat nominal yang keliru tanpa pengguna sadar. Bila label totalnya
/// sendiri tidak terbaca, lebih baik nominalnya kosong dan form review meminta
/// pengguna mengetik, daripada menebak salah.
const List<String> _abaikanTotal = [
  'subtotal',
  'sub total',
  'kembali',
  'kembalian',
  'tunai',
  'cash',
  'ppn',
  'pajak',
  'tax',
  'service',
  'servis',
  'diskon',
  'discount',
  'potongan',
  'voucher',
  'kupon',
  'promo',
  'poin',
  'refund',
  'retur',
  'reversal',
  'chargeback',
  'saldo',
  'sisa',
  'kurang',
  'qris',
  'gopay',
  'shopeepay',
  'linkaja',
  'ovo',
  'transfer',
  'debit',
  'kredit',
  'kartu',
  'setor',
  'tarik',
];

/// Metode pembayaran yang penandanya berupa singkatan pendek atau kata yang
/// lazim jadi bagian nama lain ("DANA" bisa muncul di dalam nama bank).
///
/// Dicek dengan batas kata pada baris **mentah**, bukan lewat [_untukCocok]
/// yang membuang spasi — kalau tidak, "DANA" di dalam "DANAMON" ikut terbaca
/// sebagai pembayaran.
const List<String> _pembayaranBatasKata = [
  'dana',
  'trf',
  'ovo',
  'qris',
  'va',
  'bca',
  'mandiri',
  'bni',
  'bri',
];

/// Angka yang **tidak sama dengan** total: uang yang diterima toko dan
/// kembalian, plus pengurang yang bukan belanja.
///
/// Berbeda dengan [_abaikanTotal], daftar ini hanya dipakai saat label total
/// sudah dipastikan ada tetapi nominalnya tercetak di baris berikutnya. Di
/// situ nominal metode pembayaran memang boleh dipakai: yang ditagih kartu atau
/// e-wallet sama dengan total belanja. Yang tetap ditolak adalah uang yang
/// diterima toko dan kembalian, karena keduanya berbeda dari total.
const List<String> _tidakSamadenganTotal = [
  'tunai',
  'cash',
  'kembali',
  'kembalian',
  'change',
  'saldo',
  'sisa',
  'kurang',
  'refund',
  'retur',
  'reversal',
  'chargeback',
  'setor',
  'tarik',
  'poin',
  'voucher',
  'kupon',
];

/// Baris yang berbau dokumen resmi, bukan nama tempat: NPWP, NIK, faktur pajak.
/// Berbeda dari [_awalanBarisBukanMerchant], daftar ini dicek di seluruh baris
/// karena NPWP sering tercetak tanpa label di baris terpisah.
const List<String> _dokumenResmi = ['npwp', 'nik', 'skpn', 'invoice', 'faktur'];

/// Baris yang angkanya bukan nominal (telepon, nomor dokumen, tanggal).
const List<String> _abaikanUmum = [
  'telp',
  'tel.',
  'tel:',
  'telepon',
  'phone',
  'whatsapp',
  'wa:',
  'hp',
  'npwp',
  'nik',
  'invoice',
  'nota',
  'struk',
  'tanggal',
  'date',
  'jam',
];

/// Baris yang jelas bukan nama tempat: alamat, dokumen, keranjang, dan
/// kalimat penutup struk. Tanpa ini, merchant bisa jadi "JL. MERDEKA NO. 10".
const List<String> _bukanMerchant = [
  'jalan',
  'alamat',
  'npwp',
  'nik',
  'nomor',
  'nota',
  'faktur',
  'invoice',
  'struk',
  'bukti',
  'resi',
  'kasir',
  'operator',
  'meja',
  'table',
  'trx',
  'faktur',
  'telp',
  'telepon',
  'tel',
  'hp',
  'whatsapp',
  'email',
  'www',
  'web',
  'terima',
  'kasih',
  'sampai',
  'jumpa',
  'silakan',
  'ditunggu',
  'barang',
  'item',
  'qty',
  'jumlah',
  'harga',
  'satuan',
  'total',
  'tunai',
  'kembali',
  'kembalian',
  'diskon',
  'promo',
  'voucher',
  'kupon',
  'poin',
  'pajak',
  'ppn',
  'servis',
  'service',
  'biaya',
  'admin',
  'bayar',
  'pembayaran',
  'terbayar',
  'kurang',
  'sisa',
  'harga satuan',
];

/// Sama seperti [_bukanMerchant], tetapi dicocokkan sebagai **awalan baris**
/// dengan batas kata, bukan sebagai substring di teks tanpa spasi.
///
/// Dipakai untuk singkatan yang hanya bermakna di awal baris: "JL. MERDEKA"
/// dan "NO. 10" adalah alamat, sedangkan "Jalan" di tengah nama toko tidak
/// masalah. Token pendek seperti "jl", "no", dan "rt" tidak boleh dicocokkan
/// sebagai substring — "Mart" mengandung "rt" dan "Nova" mengandung "no", sehingga
/// pencocokan substring akan membuang nama toko yang sah.
const List<String> _awalanBarisBukanMerchant = [
  'jl',
  'jln',
  'jl.',
  'jalan',
  'alamat',
  'no',
  'no.',
  'nomor',
  'npwp',
  'nik',
  'rt',
  'rw',
  'kel',
  'kec',
  'kota',
  'kab',
  'telp',
  'tel',
  'hp',
  'wa',
  'email',
  'www',
  'kasir',
  'operator',
  'meja',
  'table',
  'nota',
  'faktur',
  'invoice',
  'struk',
  'bukti',
  'trx',
  'ref',
  'resi',
  'order',
  'queue',
  'antrian',
  'pos',
];

/// Mengurai teks hasil OCR struk menjadi nominal, tanggal, dan merchant.
///
/// Murni dan tanpa basis data supaya bisa diuji dengan contoh teks.
ReceiptDraft parseReceipt(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final total = _cariTotal(lines);
  return ReceiptDraft(
    nominal: total.nilai,
    sumber: total.sumber,
    tanggal: _cariTanggal(lines),
    merchant: _cariMerchant(lines),
  );
}

/// Bentuk baris untuk pencocokan kata kunci: huruf kecil, tanpa spasi/pemisah,
/// dan huruf/angka yang sering tertukar OCR (0->o, 1->l). Tanpa ini, kata
/// berjarak seperti "T U N A I", "T.U.N.A.I", atau "T-U-N-A-I" tidak akan cocok.
String _untukCocok(String line) => _normalisasiHuruf(
  line.toLowerCase().replaceAll(RegExp(r'[\s.,:_\-/|]+'), ''),
);

/// Varian kedua yang dipakai **hanya untuk mencari kata kunci total**, bukan
/// untuk daftar abaikan.
///
/// ditambah huruf yang lain sering tertukar (5->s, 8->b, i->l) dan `!` dibuang,
/// supaya "TOTA!", "TOTAI", dan "TOTA5" tetap dikenali sebagai "total".
///
/// Kenapa tidak dipakai untuk daftar abaikan: normalisasi i->l mengubah
/// "invoice" jadi "lnvolce", sehingga kata abaikan yang berisi huruf `i`
/// ikut hilang. Dengan membatasinya pada pencarian positif, hanya ada tambahan
/// kecocokan — tidak ada kecocokan yang hilang.
String _untukCocokLenting(String line) => _normalisasiHurufLenting(
  line.toLowerCase().replaceAll(RegExp(r'[\s.,:_\-/|!\[\]()]+'), ''),
);

/// Akar kata label: nominal dan mata uang di ekor dibuang, lalu satu huruf
/// terakhir dibuang.
///
/// Satu huruf terakhir dibuang karena di situlah kesalahan baca paling sering
/// terjadi pada label — "TOTAL" bisa jadi "TOTA!", "TOTA5", atau "TOTA". Akar
/// "tota" tetap sama untuk semua bentuk itu, sehingga cocok dengan akar kata
/// kunci "total" yang juga "tota".
///
/// Nominal ikut dibuang lebih dulu, karena "TOTA! : Rp. 110.000" akan
/// menghasilkan akar "totarplloooo" — tidak ada lagi "tota" di dalamnya.
String _akarKata(String line) {
  final tanpaNominal = line.replaceFirst(
    RegExp(r'(?:rp\.?|idr)?\s*\d[\d.,]*\s*$', caseSensitive: false),
    '',
  );
  final dasar = _untukCocokLenting(tanpaNominal);
  if (dasar.length < 5) return dasar;
  return dasar.substring(0, dasar.length - 1);
}

/// Akar sebuah kata kunci, dengan aturan yang sama seperti [_akarKata].
///
/// [_lipatHuruf] dipakai supaya perlakuan kata kunci identik dengan perlakuan
/// teks baris; tanpa itu, akar "invoice" ("invoic") tidak akan sama dengan akar
/// baris yang sudah terlipat ("lnvolc").
String _akarDariKata(String kata) {
  final dasar = _lipatHuruf(kata.replaceAll(' ', ''));
  if (dasar.length < 5) return dasar;
  return dasar.substring(0, dasar.length - 1);
}

/// Cocokkan kata kunci lewat akar kata, bukan seluruh kata utuh.
///
/// Dipakai sebagai jaring pengaman terakhir setelah [_mengandungKataKunci]
/// gagal, supaya label yang huruf ekornya rusak masih dikenali. Akar baris dan
/// akar kata kunci sama-sama dipotong satu huruf, dan panjang minimum 4
/// mencegah akar terlalu pendek ikut cocok.
bool _mengandungAkar(String akarBaris, List<String> kata) {
  if (akarBaris.length < 4) return false;
  return kata.any((k) {
    final akar = _akarDariKata(k);
    return akar.length >= 4 && akarBaris.contains(akar);
  });
}

/// Lipat huruf yang saling tertukar oleh OCR ke satu huruf kanonik.
///
/// Dipakai pada **kedua** sisi pencocokan: teks baris maupun kata kuncinya.
/// Itu penting dan ditemukan lewat pengujian di perangkat: kalau hanya teks
/// baris yang dilipat, pencocokan jadi asimetris. "TUNAI" yang salah terbaca
/// jadi "TUNAI" dengan huruf terakhir `1` akan terlipat menjadi "tunal",
/// sedangkan kata kunci "tunai" tetap "tunai" — sehingga baris uang diterima
/// lolos dari daftar abaikan dan nilainya (150.000) dipakai sebagai nominal.
///
/// Menormalisasi kedua sisi membuat bentuk yang tertukar tetap saling cocok:
/// "tunal" vs "tunal", "kemball" vs "kemball", "lnvolce" vs "lnvolce".
String _lipatHuruf(String teks) => teks
    .replaceAll('0', 'o')
    .replaceAll('1', 'l')
    .replaceAll('i', 'l')
    .replaceAll('5', 's')
    .replaceAll('8', 'b');

/// Cek apakah [teks] memuat salah satu [kata]. Frasa kunci juga dibuang
/// spasinya supaya "grand total" cocok dengan "grandtotal".
///
/// Kedua sisi dilipat [_lipatHuruf], jadi huruf `i`, `l`, dan `1` dianggap
/// sama oleh kedua belah pihak.
bool _mengandung(String teks, List<String> kata) {
  final t = _lipatHuruf(teks);
  return kata.any((k) => t.contains(_lipatHuruf(k.replaceAll(' ', ''))));
}

/// Pencocokan kata kunci yang Versions gracefully: coba bentuk ketat dulu,
/// lalu bentuk lenting. Bentuk ketat selalu lebih dulu supaya daftar abaikan
/// tetap berperilaku lama.
bool _mengandungKataKunci(String teks, String teksLenting, List<String> kata) =>
    _mengandung(teks, kata) || _mengandung(teksLenting, kata);

/// Rapikan huruf yang sering tertukar dengan angka oleh OCR, khusus untuk
/// pencocokan kata kunci: "T0TAL" -> "total", "TOTA1" -> "total".
String _normalisasiHuruf(String teks) =>
    teks.replaceAll('0', 'o').replaceAll('1', 'l');

/// Bentuk lenting untuk yangeksema kata kunci saja.
String _normalisasiHurufLenting(String teks) => teks
    .replaceAll('0', 'o')
    .replaceAll('1', 'l')
    .replaceAll('5', 's')
    .replaceAll('8', 'b')
    .replaceAll('i', 'l');

/// Perbaiki huruf yang tertukar angka **di dalam token nominal**.
///
/// OCR sering menulis "11O.OOO" untuk "110.000" dan "lO.OOO" untuk "10.000".
/// Tanpa perintah ini, parser hanya melihat digit yang tersisa lalu melaporkan
/// nominal yang jauh lebih kecil — atau nol sama sekali. Karena itu pemanggil
/// harus yakin baris itu memang baris nominal (baris berlabel total).
String _normalisasiDigit(String teks) => teks
    .replaceAll('O', '0')
    .replaceAll('o', '0')
    .replaceAll('I', '1')
    .replaceAll('l', '1')
    .replaceAll('|', '1')
    .replaceAll('S', '5')
    .replaceAll('s', '5')
    .replaceAll('B', '8')
    .replaceAll('b', '8')
    .replaceAll('Z', '2')
    .replaceAll('z', '2');

/// Rapatkan ribuan yang dipisah spasi oleh OCR: "110 000" -> "110000".
/// Hanya menggabung tepat tiga digit, jadi nomor telepon 4-digit aman.
String _rapatkanRibuan(String teks) {
  var hasil = teks;
  for (var i = 0; i < 5; i++) {
    final baru = hasil.replaceAllMapped(
      RegExp(r'(\d)\s+(\d{3})(?!\d)'),
      (m) => '${m[1]}${m[2]}',
    );
    if (baru == hasil) break;
    hasil = baru;
  }
  return hasil;
}

/// Apakah baris ini bukan calon total: contains salah satu [_abaikanTotal]
/// pada bentuk dinormalisasi, atau salah satu [_pembayaranBatasKata] /
/// [_dokumenResmi] dengan batas kata pada baris mentah.
///
/// Bentuk kedua wajib memakai baris mentah karena teks sudah kehilangan spasi,
/// sehingga "DANAMON" tidak boleh ikut terbaca sebagai "DANA".
bool _abaikan(String line, String low) =>
    _mengandung(low, _abaikanTotal) ||
    _mengandung(low, _dokumenResmi) ||
    _diawaliKata(line, _pembayaranBatasKata) ||
    _diawaliKata(line, _dokumenResmi);

/// Apakah baris berisi angka yang jelas bukan total belanja — uang diterima,
/// kembalian, atau pengurang.
bool _tidakSamaDenganTotal(String line) =>
    _mengandung(_untukCocok(line), _tidakSamadenganTotal);

({int? nilai, SumberNominal sumber}) _cariTotal(List<String> lines) {
  // Kumpulkan kandidat menurut prioritas kata kunci. Baris berlabel yang
  // angkanya ada di baris berikutnya (karena OCR memisah) ikut diperiksa.
  int? terkuat;
  int? terlemah;
  for (var i = 0; i < lines.length; i++) {
    final low = _untukCocok(lines[i]);
    final lowLenting = _untukCocokLenting(lines[i]);
    final akar = _akarKata(lines[i]);
    if (_abaikan(lines[i], low)) continue;

    final kuat = _mengandungKataKunci(
      low,
      lowLenting,
      _kataKunciTotalKuat,
    ) ||
        _mengandungAkar(akar, _kataKunciTotalKuat);
    final lemah = !kuat &&
        (_mengandungKataKunci(low, lowLenting, _kataKunciTotalLemah) ||
            _mengandungAkar(akar, _kataKunciTotalLemah));
    if (!kuat && !lemah) continue;

    // Sudah dipastikan baris nominal, jadi huruf tertukar angka boleh
    // diperbaiki tanpa risiko kode barang ikut terbaca.
    var n = _angkaDariLabel(lines[i]);
    // Nominal kadang tercetak di baris berikutnya (label terpisah). Di sini
    // metode pembayaran boleh dipakai — yang ditagih kartu/e-wallet sama dengan
    // total — tapi uang diterima dan kembalian tetap ditolak.
    if (n == null) {
      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        if (_tidakSamaDenganTotal(lines[j])) break;
        final cand = _angkaTerbesar(lines[j]);
        if (cand != null && cand > 0) {
          n = cand;
          break;
        }
      }
    }
    if (n == null || n <= 0) continue;

    if (kuat) {
      terkuat = terkuat == null ? n : math.max(terkuat, n);
    } else {
      terlemah = terlemah == null ? n : math.max(terlemah, n);
    }
  }
  if (terkuat != null) {
    return (nilai: terkuat, sumber: SumberNominal.labelTotal);
  }
  if (terlemah != null) {
    return (nilai: terlemah, sumber: SumberNominal.labelTotal);
  }

  // Cadangan: angka terbesar pada baris yang bukan nomor telepon/dokumen.
  // Mode tidak agresif di sini supaya kode barang dan nomor seri tidak ikut
  // dibaca sebagai nominal.
  final semua = <int>[];
  for (final line in lines) {
    final low = _untukCocok(line);
    if (_abaikan(line, low)) continue;
    if (_mengandung(low, _abaikanUmum)) continue;
    final n = _angkaTerbesar(line);
    if (n != null) semua.add(n);
  }
  return (
    nilai: semua.isEmpty ? null : semua.reduce(math.max),
    sumber: SumberNominal.tebakanAngka,
  );
}

/// Angka terbesar pada satu baris.
///
/// Token seperti tanggal ("12.05.2026") dilewati karena bukan nominal, dan
/// desimal di belakang ("33.000,00") dibuang agar nominal rupiah tidak
/// berlipat seratus kali.
int? _angkaTerbesar(String line) {
  final rapat = _rapatkanRibuan(line);
  int? terbesar;
  for (final m in RegExp(r'\d[\d.,]*').allMatches(rapat)) {
    final raw = m.group(0)!;
    if (_sepertiTanggal(raw)) continue;
    final n = _keInt(raw);
    if (n == null) continue;
    if (terbesar == null || n > terbesar) terbesar = n;
  }
  return terbesar;
}

/// Angka nominal pada **baris berlabel** seperti "TOTAL : Rp. 110.000".
///
/// Berbeda dengan [_angkaTerbesar], baris label boleh dibaca lebih bebas karena
/// pemanggil sudah memastikan baris itu bukan daftar barang. Dua perbaikan yang
/// dimungkinkan justru di sini:
///
/// - OCR sering menulis "11O.OOO" untuk "110.000"; tanpa [_normalisasiDigit]
///   parser hanya melihat digit yang tersisa dan melaporkan nominal jauh lebih
///   kecil — bahkan nol.
/// - Nominal boleh tercetak tanpa satu pun digit yang terbaca ("Rp. lO.OOO"),
///   asal posisinya jelas di ekor baris setelah mata uang.
int? _angkaDariLabel(String line) {
  // Normalisasi lenient hanya untuk label yang sudah dipastikan; kode barang
  // tidak pernah sampai ke sini.
  final normal = _rapatkanRibuan(_normalisasiDigit(line));
  final dariDigit = _angkaTerbesar(normal);
  if (dariDigit != null && dariDigit > 0) return dariDigit;

  // Cadangan: ambil potongan paling kanan yang hanya berisi angka, pemisah, dan
  // huruf yang bisa jadi digit. "TOTAL : Rp. lO.OOO" -> "lO.OOO" -> 10000.
  final potongan = RegExp(
    r'([0-9OoIlISsBbZz][0-9OoIlISsBbZz.,]*)\s*$',
  ).firstMatch(line);
  if (potongan == null) return null;
  final kandidat = _rapatkanRibuan(_normalisasiDigit(potongan.group(1)!));
  // Kalau potongan itu kata biasa ("BAYAR", "HARGA"), normalisasinya menghasilkan
  // angka palsu. Kata dengan huruf yang tidak bisa jadi digit itu tidak mungkin
  // nominal, jadi tolak kalau terlalu banyak huruf yang tak terselesaikan.
  final hurufAsli = potongan.group(1)!.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
  final hurufTersisa = kandidat.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (hurufAsli - hurufTersisa > 1) return null;
  return _angkaTerbesar(kandidat);
}

/// Token angka yang sebenarnya pola tanggal, bukan nominal.
bool _sepertiTanggal(String raw) =>
    RegExp(r'^\d{1,4}[/\-.]\d{1,2}[/\-.]\d{2,4}$').hasMatch(raw);

/// Ubah token angka menjadi int rupiah.
int? _keInt(String raw) {
  var s = raw;
  // Buang dua digit desimal di belakang: "33.000,00" -> "33.000".
  final desimal = RegExp(r'^(.*?)[.,](\d{2})$').firstMatch(s);
  if (desimal != null && desimal.group(1)!.isNotEmpty) {
    s = desimal.group(1)!;
  }
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// Kandidat tanggal yang masuk akal: struk dicetak saat transaksi terjadi,
/// jadi tanggalnya tidak mungkin di masa depan dan tidak sebelum 2000.
bool _wajar(DateTime d, DateTime now) {
  if (d.year < 2000) return false;
  return !d.isAfter(DateTime(now.year, now.month, now.day + 1));
}

DateTime? _cariTanggal(List<String> lines) {
  final now = DateTime.now();
  final teks = lines.join(' ');
  DateTime? sekarang;
  void coba(DateTime? d) {
    if (d != null && sekarang == null && _wajar(d, now)) sekarang = d;
  }

  // yyyy-mm-dd (ISO)
  final iso = RegExp(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})').firstMatch(teks);
  if (iso != null) {
    coba(_tanggal(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    ));
  }

  // dd/mm/yyyy, dd-mm-yy, dd.mm.yyyy
  final m = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(teks);
  if (m != null) {
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    coba(_tanggal(y, mo, d));
    // Cadangan untuk format bulan di depan (mm/dd/yyyy).
    if (sekarang == null) coba(_tanggal(y, d, mo));
  }

  // Delapan digit tanpa pemisah: 20260512 atau 12052026. Baris yang memuat
  // mata uang dilewati karena eight digit tanpa pemisah lebih mungkin nominal
  // besar bila dicetak dekat "Rp"/"IDR".
  for (final line in lines) {
    final low = line.toLowerCase();
    if (low.contains('rp') || low.contains('idr')) continue;
    final c = RegExp(r'(?<!\d)(\d{8})(?!\d)').firstMatch(line);
    if (c == null) continue;
    final angka = c.group(1)!;
    final a = int.parse(angka.substring(0, 4));
    final b = int.parse(angka.substring(4, 6));
    final c2 = int.parse(angka.substring(6, 8));
    coba(_tanggal(a, b, c2));
    if (sekarang == null) coba(_tanggal(c2, b, a));
  }

  // dd <nama bulan> yyyy
  final m2 = RegExp(r'(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{2,4})').firstMatch(teks);
  if (m2 != null) {
    final d = int.parse(m2.group(1)!);
    final mo = _bulanDari(m2.group(2)!);
    var y = int.parse(m2.group(3)!);
    if (y < 100) y += 2000;
    if (mo != null) coba(_tanggal(y, mo, d));
  }
  return sekarang;
}

DateTime? _tanggal(int year, int month, int day) =>
    _valid(day, month, year) ? DateTime(year, month, day) : null;

bool _valid(int day, int month, int year) {
  if (month < 1 || month > 12) return false;
  if (year < 2000 || year > 2100) return false;
  if (day < 1) return false;
  final maxDay = DateTime(year, month + 1, 0).day;
  return day <= maxDay;
}

int? _bulanDari(String kata) {
  final k = kata.toLowerCase();
  const map = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'mei': 5, 'may': 5,
    'jun': 6, 'jul': 7, 'agu': 8, 'aug': 8, 'sep': 9, 'okt': 10,
    'oct': 10, 'nov': 11, 'des': 12, 'dec': 12,
  };
  for (final e in map.entries) {
    if (k.startsWith(e.key)) return e.value;
  }
  return null;
}

/// Garis pemisah struk ("---------", "=====", "......").
bool _garisPemisah(String line) =>
    RegExp(r'([=\-_*~.)\]])\1{2,}').hasMatch(line);

/// Apakah baris diawali salah satu [kata], dengan batas kata.
///
/// Berbeda dari [_mengandung] yang cocok di dalam teks tanpa spasi, di sini
/// "NO." hanya menolak baris yang benar-benar diawali "NO." — nama seperti
/// "Nova Mart" tetap aman.
bool _diawaliKata(String line, List<String> kata) {
  final low = line.toLowerCase();
  for (final k in kata) {
    final re = RegExp('(^|[^a-z0-9])${RegExp.escape(k)}(?![a-z0-9])');
    if (re.hasMatch(low)) return true;
  }
  return false;
}

/// Baris yang hanya berisi angka, mata uang, dan tanda baca — bukan nama.
bool _tanpaHuruf(String line) =>
    line.replaceAll(RegExp(r'[^A-Za-z]'), '').trim().isEmpty;

/// Baris berlabel transaksi: teks di awal, lalu nominal di ekor.
///
/// "TOTAL : Rp. 110.000", "TOTA! : Rp. 110.000", dan "T0TA! : Rp. 110.000"
/// sama-sama bentuk ini, dan ketiganya bukan nama toko. Bentuk ini tidak bisa
/// ditangkap daftar kata, karena huruf label bisa saja disisipi digit atau salah
/// baca ("T0TA!") sehingga kata "total" tidak muncul utuh setelah normalisasi.
///
/// Syaratnya: bagian sebelum nominal mengandung sekurang-kurangnya tiga huruf,
/// dan ada pemisah (spasi, titik, atau titik dua) sebelum nominal — itu yang
/// membedakan label dari nama toko yang mengandung angka seperti "TOKO 12".
bool _berlabelDenganNominal(String line) {
  final low = line.toLowerCase();
  // Buang nama mata uang supaya "Rp" tidak ikut terhitung sebagai huruf label.
  final tanpaMataUang = low.replaceAll(RegExp(r'\b(?:rp|idr)\b\.?'), ' ');
  final re = RegExp(
    r'^([A-Za-z][A-Za-z]*\d*[A-Za-z]*)\s*[:=]?\s*(\d[\d.,]*)\s*$',
  ).firstMatch(tanpaMataUang);
  if (re == null) return false;
  final depan = re.group(1)!;
  // Sisa angka di dalam label ("TOTA5") ditoleransi karena itu salah baca
  // huruf 'L', dan baris seperti itu tetap bukan nama toko.
  return depan.replaceAll(RegExp(r'\d'), '').replaceAll(
        RegExp(r'[^A-Za-z]'),
        '',
      ).length >= 3;
}

/// Nama tempat: baris pertama yang benar-benar nama, bukan alamat, dokumen,
/// kalimat penutup, garis pemisah, atau label transaksi.
///
/// Tanpa penyaringan ini merchant bisa jadi "TOTAL : Rp. 110.000" — label
/// total sendiri, yang jelas bukan nama toko.
String? _cariMerchant(List<String> lines) {
  for (final line in lines) {
    if (_garisPemisah(line)) continue;
    if (_tanpaHuruf(line)) continue;
    if (_berlabelDenganNominal(line)) continue;
    if (_diawaliKata(line, _awalanBarisBukanMerchant)) continue;

    final low = _untukCocok(line);
    if (_abaikan(line, low)) continue;
    // Ketiga bentuk dipakai di sini supaya baris berlabel yang salah baca
    // ("TOTA! : Rp. 110.000") tidak lolos menjadi merchant: bentuk ketat,
    // bentuk lenting, lalu akar kata untuk huruf yang hilang di ekor label.
    final lowLenting = _untukCocokLenting(line);
    final akar = _akarKata(line);
    if (_mengandung(low, _bukanMerchant)) continue;
    if (_mengandung(lowLenting, _bukanMerchant)) continue;
    if (_mengandungAkar(akar, _bukanMerchant)) continue;

    final huruf = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (huruf.length < 3) continue;

    // Buang sisa angka di ekor, misalnya nama bercampur nomor: "TOKO 12".
    final bersih = line
        .replaceAll(RegExp(r'^[^A-Za-z]+'), '')
        .replaceAll(RegExp(r'\d+[^A-Za-z]*$'), '')
        .replaceAll(RegExp(r'[^A-Za-z]+$'), '')
        .trim();
    if (bersih.length < 3) continue;
    return bersih.length > 60 ? bersih.substring(0, 60).trim() : bersih;
  }
  return null;
}