import 'dart:math' as math;

/// Hasil pembacaan struk. Semua field opsional: nilai yang tak terbaca menjadi
/// null dan dibiarkan diisi pengguna di form review.
class ReceiptDraft {
  const ReceiptDraft({
    this.nominal,
    this.tanggal,
    this.merchant,
    this.yakin = false,
  });

  final int? nominal;
  final DateTime? tanggal;
  final String? merchant;

  /// true bila nominal diambil dari baris berlabel total, bukan dari tebakan
  /// "angka terbesar". Dipakai layar review untuk memperingatkan pengguna.
  final bool yakin;

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
  'poin',
];

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
    yakin: total.kataKunci && total.nilai != null,
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

/// Cek apakah [teks] (sudah dinormalisasi) memuat salah satu [kata]. Frasa
/// kunci juga dibuang spasinya supaya "grand total" cocok dengan "grandtotal".
bool _mengandung(String teks, List<String> kata) =>
    kata.any((k) => teks.contains(k.replaceAll(' ', '')));

/// Rapikan huruf yang sering tertukar dengan angka oleh OCR, khusus untuk
/// pencocokan kata kunci: "T0TAL" -> "total", "TOTA1" -> "total".
String _normalisasiHuruf(String teks) =>
    teks.replaceAll('0', 'o').replaceAll('1', 'l');

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

({int? nilai, bool kataKunci}) _cariTotal(List<String> lines) {
  // Kumpulkan kandidat menurut prioritas kata kunci. Baris berlabel yang
  // angkanya ada di baris berikutnya (karena OCR memisah) ikut diperiksa.
  int? terkuat;
  int? terlemah;
  for (var i = 0; i < lines.length; i++) {
    final low = _untukCocok(lines[i]);
    if (_mengandung(low, _abaikanTotal)) continue;

    final kuat = _mengandung(low, _kataKunciTotalKuat);
    final lemah = !kuat && _mengandung(low, _kataKunciTotalLemah);
    if (!kuat && !lemah) continue;

    var n = _angkaTerbesar(lines[i]);
    // Nominal kadang tercetak di baris berikutnya (label terpisah). Jangan
    // sampai mencuri angka dari baris tunai/kembali di bawahnya.
    if (n == null) {
      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        if (_mengandung(_untukCocok(lines[j]), _abaikanTotal)) break;
        final cand = _angkaTerbesar(lines[j]);
        if (cand != null) {
          n = cand;
          break;
        }
      }
    }
    if (n == null) continue;

    if (kuat) {
      terkuat = terkuat == null ? n : math.max(terkuat, n);
    } else {
      terlemah = terlemah == null ? n : math.max(terlemah, n);
    }
  }
  if (terkuat != null) return (nilai: terkuat, kataKunci: true);
  if (terlemah != null) return (nilai: terlemah, kataKunci: true);

  // Cadangan: angka terbesar pada baris yang bukan nomor telepon/dokumen.
  final semua = <int>[];
  for (final line in lines) {
    final low = _untukCocok(line);
    if (_mengandung(low, _abaikanTotal)) continue;
    if (_mengandung(low, _abaikanUmum)) continue;
    final n = _angkaTerbesar(line);
    if (n != null) semua.add(n);
  }
  return (
    nilai: semua.isEmpty ? null : semua.reduce(math.max),
    kataKunci: false,
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
    if (RegExp(r'^\d{1,4}[/\-.]\d{1,2}[/\-.]\d{2,4}$').hasMatch(raw)) {
      continue; // tanggal, bukan nominal
    }
    final n = _keInt(raw);
    if (n == null) continue;
    if (terbesar == null || n > terbesar) terbesar = n;
  }
  return terbesar;
}

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

DateTime? _cariTanggal(List<String> lines) {
  final teks = lines.join(' ');

  // yyyy-mm-dd (ISO)
  final iso = RegExp(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})').firstMatch(teks);
  if (iso != null) {
    final y = int.parse(iso.group(1)!);
    final mo = int.parse(iso.group(2)!);
    final d = int.parse(iso.group(3)!);
    if (_valid(d, mo, y)) return DateTime(y, mo, d);
  }

  // dd/mm/yyyy, dd-mm-yy, dd.mm.yyyy
  final m = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(teks);
  if (m != null) {
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    if (_valid(d, mo, y)) return DateTime(y, mo, d);
    // Cadangan untuk format bulan di depan (mm/dd/yyyy).
    if (_valid(mo, d, y)) return DateTime(y, d, mo);
  }

  // dd <nama bulan> yyyy
  final m2 = RegExp(r'(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{2,4})').firstMatch(teks);
  if (m2 != null) {
    final d = int.parse(m2.group(1)!);
    final mo = _bulanDari(m2.group(2)!);
    var y = int.parse(m2.group(3)!);
    if (y < 100) y += 2000;
    if (mo != null && _valid(d, mo, y)) return DateTime(y, mo, d);
  }
  return null;
}

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

String? _cariMerchant(List<String> lines) {
  for (final line in lines) {
    final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length >= 3) {
      return line.length > 60 ? line.substring(0, 60) : line;
    }
  }
  return null;
}
