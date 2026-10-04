import 'package:flutter/material.dart';

import '../util/contrast.dart';
import 'neo_palette.dart';

/// Token gaya neobrutalism (Bagian 6b dan 6c PRD).
///
/// Warna sekarang datang dari palet yang dipilih pengguna ([NeoPalette]) lewat
/// [apply]. Struktur (border, radius, spacing) tetap. Warna semantik **tidak**
/// ikut berubah — lihat [kSemanticColors].
///
/// Jangan memakai token di bawah di dalam ekspresi `const`: nilainya baru pasti
/// saat `build`, dan `const` akan ditolak pengompilasi.
class Neo {
  Neo._();

  /// Palet yang sedang berlaku. `ElutungApp` memanggil [apply] untuk mode yang
  /// aktif sebelum membangun `MaterialApp`.
  static NeoPalette _aktif = kThemePresets.first.light;

  static Color get bg => _aktif.bg;
  static Color get surface => _aktif.surface;
  static Color get ink => _aktif.ink;
  static Color get appBar => _aktif.appBar;
  static Color get accent => _aktif.accent;

  /// Teks sekunder **diturunkan** dari [ink] dan [bg], bukan token tersendiri,
  /// supaya selalu ikut menyesuaikan dan tidak bisa dibuat tak terbaca
  /// (Bagian 6c).
  static Color get muted => Color.alphaBlend(ink.withValues(alpha: 0.55), bg);

  // Warna semantik — terkunci, tidak dapat diubah pengguna (Bagian 6c).
  static const Color income = kIncomeColor;
  static const Color expense = kExpenseColor;
  static const Color transfer = kTransferColor;

  // ---- Struktur (konstan) ----
  static const double borderW = 2.0;
  static const double radius = 6.0;
  static const double space = 12.0;

  static void apply(NeoPalette palette) => _aktif = palette;

  /// Warna bayangan: mengikuti [ink] selama ink-nya gelap, dan memakai hitam
  /// saat ink-nya terang supaya bayangan tetap berupa bayangan, bukan pendar.
  static Color get _shadowBase =>
      ink.computeLuminance() > 0.5 ? Colors.black : ink;

  static List<BoxShadow> hardShadow([double offset = 3]) => [
    BoxShadow(
      color: _shadowBase.withValues(alpha: 0.35),
      offset: Offset(offset, offset),
      blurRadius: 2,
    ),
  ];

  static BoxDecoration box({
    Color? color,
    double r = radius,
    double border = borderW,
    double shadow = 4,
  }) => BoxDecoration(
    color: color ?? surface,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(color: ink, width: border),
    boxShadow: shadow <= 0 ? null : hardShadow(shadow),
  );
}

class AppTheme {
  AppTheme._();

  /// Tema dibangun dari palet yang diberikan, bukan dari palet global, supaya
  /// `theme` dan `darkTheme` bisa dibangun berdampingan pada `MaterialApp`.
  static ThemeData light(NeoPalette p) => _build(p, Brightness.light);
  static ThemeData dark(NeoPalette p) => _build(p, Brightness.dark);

  static ThemeData _build(NeoPalette p, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
    ).copyWith(
      surface: p.surface,
      onSurface: p.ink,
      primary: p.accent,
      // Dihitung, bukan diambil dari `ink`: label yang duduk di atas aksen
      // harus terbaca apa pun warna aksennya (chip terpilih, tombol).
      onPrimary: readableOn(p.accent),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: p.appBar,
        // Sama seperti aksen: dipilih otomatis agar selalu terbaca.
        foregroundColor: readableOn(p.appBar),
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: readableOn(p.appBar),
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.accent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        height: 64,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Neo.radius),
          side: BorderSide(color: p.ink, width: Neo.borderW),
        ),
      ),
    );
  }
}
