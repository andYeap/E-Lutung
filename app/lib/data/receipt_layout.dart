/// Pemasangan label ↔ nominal lewat geometri baris OCR (Fase 2).
///
/// Latar: ML Kit sering mengembalikan struk dua kolom sebagai dua blok
/// terpisah — seluruh label ("TOTAL : Rp.") di satu blok, seluruh nominal
/// ("110.000") di blok lain, belasan baris di bawahnya. Parser berbasis
/// baris (`data/receipt.dart`) tidak bisa memasangkan keduanya, sehingga
/// label tercatat "tanpa nominal" dan nominal jatuh ke `labelTanpaNominal`
/// alias kosong. Identitas aritmetika (`tunai - kembalian = total`) menutup
/// sebagian kasus, tetapi hanya untuk struk tunai berlabel pembayaran.
///
/// Fungsi di sini murni (koordinat sebagai double, tanpa Flutter) supaya
/// bisa diuji dengan fixture buatan: label tanpa angka dipasangkan dengan
/// angka berdiri sendiri yang segaris vertikal di sebelah kanannya.
///
/// Catatan duplikasi yang disengaja: deteksi "baris label" dan "baris angka"
/// ditulis ulang minimalis di sini, bukan memakai fungsi privat `receipt.dart`.
/// Alasannya gotcha 23/25 — fungsi privat itu terikat normalisasi kata kunci
/// dan tidak bisa dipakai untuk geometri tanpa membocorkan invarian parser.
library;

/// Satu baris OCR beserta kotak pembatasnya, dalam satuan apa pun asal
/// konsisten (piksel ML Kit). Murni: tidak memakai `dart:ui`/`flutter`.
class BarisOcr {
  const BarisOcr({
    required this.teks,
    required this.kiri,
    required this.atas,
    required this.kanan,
    required this.bawah,
  });

  final String teks;
  final double kiri;
  final double atas;
  final double kanan;
  final double bawah;

  double get tengahY => (atas + bawah) / 2;
  double get tengahX => (kiri + kanan) / 2;
  double get tinggi => (bawah - atas).abs();
}

/// Apakah baris ini label tanpa angka besar menempel — mis. "TOTAL : Rp."
/// atau "TOTAL". Syarat: memuat huruf, dan tidak memuat angka ≥ 3 digit
/// (angka tahun/tanggal kecil seperti "2026" ditoleransi? tidak: baris
/// tanggal bukan label total, tetapi tanggal tidak segaris dengan angka
/// kolom sehingga tidak akan terpasangkan juga).
bool barisLabelTanpaAngka(String baris) {
  if (!RegExp(r'[A-Za-z]').hasMatch(baris)) return false;
  final besar = RegExp(r'\d[\d.,]*').allMatches(baris).any((m) {
    final digit = m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
    return digit.length >= 3;
  });
  return !besar;
}

/// Apakah baris ini angka berdiri sendiri — angka besar dengan huruf
/// nyaris tidak ada (toleransi "Rp"/"IDR"/simbol, sama seperti parser).
bool barisAngkaBerdiriSendiri(String baris) {
  final sisa = baris
      .toLowerCase()
      .replaceAll(RegExp(r'\b(?:rp|idr)\b\.?'), ' ')
      .replaceAll(RegExp(r'[^0-9a-z.,:*]+'), '');
  if (RegExp(r'[a-wyz]').hasMatch(sisa)) return false;
  final besar = RegExp(r'\d[\d.,]*').allMatches(sisa).any((m) {
    final digit = m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
    return digit.length >= 3;
  });
  return besar && RegExp(r'\d').hasMatch(sisa);
}

/// Pasangan label ↔ angka: indeks baris angka untuk tiap indeks baris label.
///
/// Syarat pasangan: angka segaris vertikal (|selisih tengahY| ≤ toleransi
/// dari tinggi baris tertinggi) DAN berada di kanan (tengahX angka >
/// tengahX label). Tiap angka hanya dipakai sekali; label yang tidak
/// menemukan pasangan tidak masuk peta.
Map<int, int> pasangLabelDuaKolom(List<BarisOcr> garis) {
  final hasil = <int, int>{};
  final angkaDipakai = <int>{};
  for (var i = 0; i < garis.length; i++) {
    if (!barisLabelTanpaAngka(garis[i].teks)) continue;
    var calon = -1;
    var jarakTerdekat = double.infinity;
    for (var j = 0; j < garis.length; j++) {
      if (j == i || angkaDipakai.contains(j)) continue;
      if (!barisAngkaBerdiriSendiri(garis[j].teks)) continue;
      final dy = (garis[j].tengahY - garis[i].tengahY).abs();
      final toleransi =
          (garis[i].tinggi > garis[j].tinggi ? garis[i].tinggi : garis[j].tinggi) *
              0.8 +
          2;
      if (dy > toleransi) continue;
      if (garis[j].tengahX <= garis[i].tengahX) continue;
      final jarak = dy + (garis[j].tengahX - garis[i].tengahX).abs() / 10;
      if (jarak < jarakTerdekat) {
        jarakTerdekat = jarak;
        calon = j;
      }
    }
    if (calon >= 0) {
      hasil[i] = calon;
      angkaDipakai.add(calon);
    }
  }
  return hasil;
}

/// Gabungkan teks datar dengan pasangan geometri: tiap label tanpa angka
/// diganti "LABEL angka-pasangan", sehingga parser baris lama langsung bisa
/// membaca nominalnya tanpa perubahan parser.
///
/// Baris angka yang sudah terpasangkan TIDAK dihapus (parser mengabaikan
/// angka ganda yang sama nilainya lewat prioritas label; menghapus justru
/// merusak identitas aritmetika yang memakai kolom angka).
String gabungDuaKolom(String teks, List<BarisOcr> garis) {
  if (garis.isEmpty) return teks;
  final pasangan = pasangLabelDuaKolom(garis);
  if (pasangan.isEmpty) return teks;
  final baris = teks.split('\n');
  // Samakan baris teks dengan urutan geometri: ML Kit mengembalikan teks
  // datar dengan urutan baca yang sama dengan urutan `lines`, jadi indeks
  // ke-i teks datar ≈ garis ke-i bila jumlahnya sama. Bila tidak sama
  // (teks ditempel dari sumber lain), kembalikan teks apa adanya daripada
  // memasang silang.
  if (baris.length != garis.length) return teks;
  final keluar = List<String>.from(baris);
  pasangan.forEach((labelIdx, angkaIdx) {
    final angka = garis[angkaIdx].teks.trim();
    if (angka.isEmpty) return;
    keluar[labelIdx] = '${baris[labelIdx].trim()} $angka';
  });
  return keluar.join('\n');
}
