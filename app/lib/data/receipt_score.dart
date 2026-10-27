import 'receipt.dart';

/// Skor keyakinan hasil parse satu varian gambar (Fase 1).
///
/// Urutan mengikuti tingkat bukti yang sudah dipakai layar review:
/// `pembayaranTerverifikasi` (dua identitas aritmetika) > `labelTotal`
/// (baris berlabel) > `tebakanAngka`. Jumlah field terisi menjadi penentu
/// bila sumbernya sama; nominal diberi bobot lebih karena itulah yang
/// paling menentukan benar/salahnya pencatatan.
///
/// Murni supaya bisa diuji tanpa perangkat: pemenang dipilih dari skor,
/// bukan dari urutan kedatangan.
int skorDraft(ReceiptDraft d) {
  final dasar = switch (d.sumber) {
    SumberNominal.pembayaranTerverifikasi => 300,
    SumberNominal.labelTotal => 200,
    // Tebakan hanya dihitung bila ada nominalnya; draft kosong skornya 0.
    SumberNominal.tebakanAngka => d.nominal == null ? 0 : 100,
  };
  var tambahan = 0;
  if (d.nominal != null) tambahan += 20;
  if (d.tanggal != null) tambahan += 10;
  if (d.merchant != null) tambahan += 10;
  return dasar + tambahan;
}

/// Indeks draft terbaik dari [daftar]. Seri dimenangkan indeks terkecil —
/// pemanggil wajib menaruh varian gambar asli di indeks 0 supaya seri
/// selalu memilih gambar tanpa distorsi.
int indeksTerbaik(List<ReceiptDraft> daftar) {
  var terbaik = 0;
  var skorTerbaik = -1;
  for (var i = 0; i < daftar.length; i++) {
    final s = skorDraft(daftar[i]);
    if (s > skorTerbaik) {
      skorTerbaik = s;
      terbaik = i;
    }
  }
  return terbaik;
}

/// Mutu teks OCR untuk quality gate (Fase 3).
enum KualitasOcr {
  /// Cukup bahan untuk diparse; lanjut ke form review seperti biasa.
  baik,

  /// Terlalu sedikit bahan (terlalu sedikit baris/angka). Layar menampilkan
  /// anjuran foto ulang, bukan form kosong tanpa penjelasan.
  meragukan,

  /// Tidak ada teks sama sekali.
  kosong,
}

/// Hasil penilaian mutu: tingkat + alasan berbahasa Indonesia untuk banner.
({KualitasOcr tingkat, String alasan}) nilaiKualitasOcr(String teks) {
  if (teks.trim().isEmpty) {
    return (tingkat: KualitasOcr.kosong, alasan: 'tidak ada teks terbaca');
  }
  final baris = teks
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final angkaBesar =
      RegExp(r'\d[\d.,]*').allMatches(teks).where((m) {
        final digit = m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
        return digit.length >= 3;
      }).length;
  final adaDigit = RegExp(r'\d').hasMatch(teks);

  if (!adaDigit) {
    return (
      tingkat: KualitasOcr.kosong,
      alasan: 'tidak ada angka terbaca sama sekali',
    );
  }
  // Ambang dipilih dari bentuk struk nyata: struk belanja pendek pun punya
  // belasan baris dan beberapa angka ribuan. Di bawah ini hampir pasti
  // fotonya kepotong, buram, atau silau.
  if (baris.length < 4 || angkaBesar < 2) {
    return (
      tingkat: KualitasOcr.meragukan,
      alasan: 'hanya ${baris.length} baris dan $angkaBesar angka terbaca',
    );
  }
  return (tingkat: KualitasOcr.baik, alasan: '');
}
