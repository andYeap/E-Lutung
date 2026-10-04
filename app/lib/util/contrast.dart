import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/neo_palette.dart';

/// Pemeriksaan keterbacaan dan kemiripan makna warna (Bagian 6c PRD).
///
/// Murni supaya bisa diuji: tidak menyentuh state maupun basis data.

/// Rasio kontras WCAG 2.1 antara dua warna, dari 1 (sama) sampai 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final terang = math.max(la, lb);
  final gelap = math.min(la, lb);
  return (terang + 0.05) / (gelap + 0.05);
}

/// Ambang WCAG AA: 4.5 untuk teks biasa, 3.0 untuk teks besar/tebal.
bool meetsWcagAA(Color fg, Color bg, {bool largeText = false}) =>
    contrastRatio(fg, bg) >= (largeText ? 3.0 : 4.5);

/// Warna teks/ikon yang paling terbaca di atas [background]: hitam lembut atau
/// putih lembut, mana yang rasionya lebih tinggi.
///
/// Dipakai aplikasi untuk memasangkan teks dengan aksen dan bilah atas, supaya
/// pasangan itu **dijamin** aman dan tidak perlu diperingatkan. Titik silang
/// kedua pilihan ada di luminance 0.179; rasio terburuknya sekitar 4:1, masih
/// di atas ambang teks tebal.
Color readableOn(Color background) => background.computeLuminance() > 0.179
    ? const Color(0xFF1A1A1A)
    : const Color(0xFFF7F7F5);

/// Apakah [c] bisa tertukar dengan [target] dari segi makna.
///
/// Dibandingkan **rona** dan kecerahan, bukan jarak RGB. Jarak RGB mentah
/// menyesatkan: arang gelap seperti `#3A3934` akan dianggap "dekat" dengan
/// hampir semua warna bertona sedang. Abu-abu juga tidak pernah dianggap
/// menyerupai warna bertona, karena warnanya memang netral.
bool miripWarnaSemantik(
  Color c,
  Color target, {
  double maxHueGap = 15,
  double maxLightnessGap = 0.20,
  double minSaturation = 0.30,
}) {
  final a = HSLColor.fromColor(c);
  final b = HSLColor.fromColor(target);
  if (a.saturation < minSaturation || b.saturation < minSaturation) return false;

  var gap = (a.hue - b.hue).abs();
  if (gap > 180) gap = 360 - gap;

  return gap <= maxHueGap &&
      (a.lightness - b.lightness).abs() <= maxLightnessGap;
}

/// Peringatan untuk palet yang sedang disusun pengguna.
///
/// Sifatnya saran, bukan larangan: layar tetap menyimpan pilihan pengguna
/// walau daftar ini tidak kosong (Bagian 6c butir 3).
List<String> paletteWarnings(NeoPalette p) {
  final pesan = <String>[];

  void cekKontras(String label, Color fg, Color bg, {bool tebal = false}) {
    if (meetsWcagAA(fg, bg, largeText: tebal)) return;
    final rasio = contrastRatio(fg, bg).toStringAsFixed(1);
    pesan.add(
      '$label hanya berkontras $rasio:1 (disarankan minimal '
      '${tebal ? '3.0' : '4.5'}:1).',
    );
  }

  // Hanya pasangan yang benar-benar ditentukan pengguna. Teks di atas aksen dan
  // bilah atas tidak masuk sini karena aplikasi memilih kontrasnya sendiri
  // lewat [readableOn], jadi sudah terjamin.
  cekKontras('Teks utama terhadap latar', p.ink, p.bg);
  cekKontras('Teks utama terhadap kartu', p.ink, p.surface);

  for (final semantik in kSemanticColors) {
    if (miripWarnaSemantik(p.accent, semantik)) {
      pesan.add(
        'Aksen terlalu mirip ${semanticName(semantik)}, '
        'sehingga bisa tertukar dengan maknanya.',
      );
    }
    if (miripWarnaSemantik(p.ink, semantik)) {
      pesan.add(
        'Border & teks terlalu mirip ${semanticName(semantik)}, '
        'sehingga mudah tertukar dengan maknanya.',
      );
    }
  }

  return pesan;
}
