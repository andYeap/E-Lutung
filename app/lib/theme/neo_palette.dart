import 'package:flutter/material.dart';

import '../util/color.dart';

/// Warna semantik — **terkunci**, tidak boleh diubah pengguna (Bagian 6c).
/// Nilainya satu-satunya sumber di aplikasi; `Neo` hanya merujuk ke sini.
const Color kIncomeColor = Color(0xFF2E7D5B); // hijau sage
const Color kExpenseColor = Color(0xFFB85C5C); // merah bata lembut
const Color kTransferColor = Color(0xFF5B6BB5); // indigo lembut

const List<Color> kSemanticColors = [kIncomeColor, kExpenseColor, kTransferColor];

String semanticName(Color c) {
  if (c == kIncomeColor) return 'warna pemasukan';
  if (c == kExpenseColor) return 'warna pengeluaran';
  if (c == kTransferColor) return 'warna transfer';
  return 'warna semantik';
}

/// Token warna yang boleh disetel pengguna (Bagian 6c).
enum NeoToken { bg, surface, ink, appBar, accent }

String neoTokenLabel(NeoToken t) => switch (t) {
  NeoToken.bg => 'Latar belakang',
  NeoToken.surface => 'Kartu & panel',
  NeoToken.ink => 'Border & teks',
  NeoToken.appBar => 'Bilah atas',
  NeoToken.accent => 'Aksen',
};

Color neoTokenValue(NeoPalette p, NeoToken t) => switch (t) {
  NeoToken.bg => p.bg,
  NeoToken.surface => p.surface,
  NeoToken.ink => p.ink,
  NeoToken.appBar => p.appBar,
  NeoToken.accent => p.accent,
};

NeoPalette neoTokenWith(NeoPalette p, NeoToken t, Color c) => switch (t) {
  NeoToken.bg => p.copyWith(bg: c),
  NeoToken.surface => p.copyWith(surface: c),
  NeoToken.ink => p.copyWith(ink: c),
  NeoToken.appBar => p.copyWith(appBar: c),
  NeoToken.accent => p.copyWith(accent: c),
};

/// Satu set warna untuk satu mode tampilan.
class NeoPalette {
  const NeoPalette({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.appBar,
    required this.accent,
  });

  final Color bg;
  final Color surface;
  final Color ink;
  final Color appBar;
  final Color accent;

  NeoPalette copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? appBar,
    Color? accent,
  }) => NeoPalette(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    ink: ink ?? this.ink,
    appBar: appBar ?? this.appBar,
    accent: accent ?? this.accent,
  );

  Map<String, String> toJson() => {
    'bg': hexColor(bg),
    'surface': hexColor(surface),
    'ink': hexColor(ink),
    'appBar': hexColor(appBar),
    'accent': hexColor(accent),
  };

  /// Membaca palet tersimpan; field yang hilang atau rusak jatuh ke [fallback].
  factory NeoPalette.fromJson(Map<dynamic, dynamic> json, NeoPalette fallback) {
    Color baca(String key, Color def) {
      final v = json[key];
      return tryParseHexColor(v is String ? v : null) ?? def;
    }
    return NeoPalette(
      bg: baca('bg', fallback.bg),
      surface: baca('surface', fallback.surface),
      ink: baca('ink', fallback.ink),
      appBar: baca('appBar', fallback.appBar),
      accent: baca('accent', fallback.accent),
    );
  }
}

/// Palet bawaan: titik awal yang bisa disetel pengguna.
class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
  });

  final String id;
  final String name;
  final NeoPalette light;
  final NeoPalette dark;
}

/// Preset bawaan.
///
/// Aksennya sengaja dijauhkan dari hijau pemasukan dan merah pengeluaran
/// supaya aturan Bagian 6b tetap terasa pada pilihan bawaan.
///
/// **Varian gelap.** Latarnya sengaja bukan hitam pekat dan teksnya bukan putih
/// murni: pasangan hitam-putih menghasilkan kontras di atas 13:1, dan dalam
/// pemakaian lama itu melelahkan mata. Angka di sini dijaga sekitar 8-10:1 —
/// masih di atas ambang WCAG AAA (7:1) tetapi jauh lebih nyaman. Aksennya juga
/// dijinakkan (kejenuhan dan kecerahannya diturunkan) supaya tidak menyala di
/// atas latar gelap. Semuanya dikunci `test/contrast_test.dart`.
const List<ThemePreset> kThemePresets = [
  ThemePreset(
    id: 'krem',
    name: 'Krem',
    light: NeoPalette(
      bg: Color(0xFFF6F5F1),
      surface: Color(0xFFFCFCFA),
      ink: Color(0xFF3A3934),
      appBar: Color(0xFFF2CE6B),
      accent: Color(0xFFF2CE6B),
    ),
    dark: NeoPalette(
      bg: Color(0xFF26231E),
      surface: Color(0xFF302C26),
      ink: Color(0xFFCFC8BA),
      appBar: Color(0xFF302C26),
      accent: Color(0xFFD9BC72),
    ),
  ),
  ThemePreset(
    id: 'biru',
    name: 'Biru Langit',
    light: NeoPalette(
      bg: Color(0xFFEEF3F8),
      surface: Color(0xFFFBFDFF),
      ink: Color(0xFF2C3A47),
      // Sedikit ke arah cyan agar ronanya tidak berdekatan dengan indigo
      // milik warna transfer (Bagian 6c butir 2).
      appBar: Color(0xFF7FC4D6),
      accent: Color(0xFF7FC4D6),
    ),
    dark: NeoPalette(
      bg: Color(0xFF1E242A),
      surface: Color(0xFF28313A),
      ink: Color(0xFFC3CED9),
      appBar: Color(0xFF28313A),
      accent: Color(0xFF7FA3B5),
    ),
  ),
  ThemePreset(
    id: 'ungu',
    name: 'Ungu Lembut',
    light: NeoPalette(
      bg: Color(0xFFF4F1F8),
      surface: Color(0xFFFDFCFF),
      ink: Color(0xFF3B3446),
      appBar: Color(0xFFB9A5D9),
      accent: Color(0xFFB9A5D9),
    ),
    dark: NeoPalette(
      bg: Color(0xFF24202B),
      surface: Color(0xFF2E2937),
      ink: Color(0xFFCDC6D9),
      appBar: Color(0xFF2E2937),
      accent: Color(0xFFA08CC0),
    ),
  ),
  ThemePreset(
    id: 'teal',
    name: 'Teal Tenang',
    light: NeoPalette(
      bg: Color(0xFFEDF5F4),
      surface: Color(0xFFFBFDFC),
      ink: Color(0xFF2F3E3C),
      appBar: Color(0xFF8FC7C0),
      accent: Color(0xFF8FC7C0),
    ),
    dark: NeoPalette(
      bg: Color(0xFF1F2927),
      surface: Color(0xFF293432),
      ink: Color(0xFFC5D1CE),
      appBar: Color(0xFF293432),
      accent: Color(0xFF7FAAA3),
    ),
  ),
  ThemePreset(
    id: 'netral',
    name: 'Abu Netral',
    light: NeoPalette(
      bg: Color(0xFFF5F5F4),
      surface: Color(0xFFFCFCFC),
      ink: Color(0xFF35353A),
      appBar: Color(0xFFC9C9CE),
      accent: Color(0xFFC9C9CE),
    ),
    dark: NeoPalette(
      bg: Color(0xFF242427),
      surface: Color(0xFF2E2E32),
      ink: Color(0xFFCDCDD2),
      appBar: Color(0xFF2E2E32),
      accent: Color(0xFFA6A6AE),
    ),
  ),
  ThemePreset(
    id: 'malam-hangat',
    name: 'Malam Hangat',
    light: NeoPalette(
      bg: Color(0xFFFAF4EE),
      surface: Color(0xFFFFFCF8),
      ink: Color(0xFF3C322A),
      appBar: Color(0xFFC9A87C),
      accent: Color(0xFFC9A87C),
    ),
    dark: NeoPalette(
      bg: Color(0xFF262220),
      surface: Color(0xFF302B27),
      ink: Color(0xFFCFC6BE),
      appBar: Color(0xFF302B27),
      accent: Color(0xFFB99C74),
    ),
  ),
  ThemePreset(
    id: 'grafit-sejuk',
    name: 'Grafit Sejuk',
    light: NeoPalette(
      bg: Color(0xFFF1F4F6),
      surface: Color(0xFFFCFDFE),
      ink: Color(0xFF2F383E),
      appBar: Color(0xFF93A7B2),
      accent: Color(0xFF93A7B2),
    ),
    dark: NeoPalette(
      bg: Color(0xFF22262A),
      surface: Color(0xFF2C3237),
      ink: Color(0xFFC7CFD5),
      appBar: Color(0xFF2C3237),
      accent: Color(0xFF8199A6),
    ),
  ),
  ThemePreset(
    id: 'tinta-lembut',
    name: 'Tinta Lembut',
    light: NeoPalette(
      bg: Color(0xFFF2F4F7),
      surface: Color(0xFFFCFDFF),
      ink: Color(0xFF343B44),
      appBar: Color(0xFFA8B2C0),
      accent: Color(0xFFA8B2C0),
    ),
    dark: NeoPalette(
      bg: Color(0xFF212429),
      surface: Color(0xFF2B2F35),
      ink: Color(0xFFC6CCD3),
      appBar: Color(0xFF2B2F35),
      accent: Color(0xFF8C97A8),
    ),
  ),
];

ThemePreset presetById(String? id) => kThemePresets.firstWhere(
  (p) => p.id == id,
  orElse: () => kThemePresets.first,
);
