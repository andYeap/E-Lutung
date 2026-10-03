import 'package:flutter/material.dart';

/// Token gaya neobrutalism (Bagian 6b PRD).
///
/// Warna bersifat **mutable** dan di-swap oleh [applyBrightness] saat tema
/// berubah (terang/gelap). Konstanta struktural (border/radius/spacing) tetap.
class Neo {
  Neo._();

  // ---- Warna (berubah mengikuti brightness) ----
  static Color bg = _bgLight;
  static Color surface = _surfaceLight;
  static Color ink = _inkLight;
  static Color muted = _mutedLight;

  // Aksen & warna semantik — versi lembut (tidak menyilaukan)
  static const Color accent = Color(0xFFF2CE6B); // kuning lembut
  static const Color income = Color(0xFF2E7D5B); // hijau sage
  static const Color expense = Color(0xFFB85C5C); // merah bata lembut
  static const Color transfer = Color(0xFF5B6BB5); // indigo lembut

  // Nilai dasar tema terang/gelap
  static const _bgLight = Color(0xFFF6F5F1);
  static const _bgDark = Color(0xFF1E1F22);
  static const _surfaceLight = Color(0xFFFCFCFA);
  static const _surfaceDark = Color(0xFF2A2C30);
  static const _inkLight = Color(0xFF3A3934); // arang, bukan hitam pekat
  static const _inkDark = Color(0xFFE8E7E3);
  static const _mutedLight = Color(0xFF7C7B75);
  static const _mutedDark = Color(0xFFA6A5A0);

  // ---- Struktur (konstan) ----
  static const double borderW = 2.0;
  static const double radius = 6.0;
  static const double space = 12.0;

  /// Panggil sebelum membangun MaterialApp agar warna sesuai tema aktif.
  static void applyBrightness(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    bg = dark ? _bgDark : _bgLight;
    surface = dark ? _surfaceDark : _surfaceLight;
    ink = dark ? _inkDark : _inkLight;
    muted = dark ? _mutedDark : _mutedLight;
  }

  static List<BoxShadow> hardShadow([double offset = 3]) => [
    // Bayangan memakai warna arang transparan (bukan hitam pekat) agar lembut.
    BoxShadow(
      color: const Color(0xFF3A3934).withValues(alpha: 0.35),
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

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: Neo.accent,
      brightness: brightness,
    ).copyWith(
      surface: dark ? Neo._bgDark : Neo._surfaceLight,
      onSurface: dark ? Neo._inkDark : Neo._inkLight,
      primary: Neo.accent,
      onPrimary: const Color(0xFF3A3934),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? Neo._bgDark : Neo._bgLight,
      appBarTheme: AppBarTheme(
        // Terang: bar kuning lembut. Gelap: permukaan gelap (bukan kuning) agar
        // tidak kontras menyilaukan.
        backgroundColor: dark ? Neo._surfaceDark : Neo.accent,
        foregroundColor: dark ? Neo._inkDark : const Color(0xFF3A3934),
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: dark ? Neo._inkDark : const Color(0xFF3A3934),
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? Neo._surfaceDark : Neo._surfaceLight,
        indicatorColor: Neo.accent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        height: 64,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? Neo._surfaceDark : Neo._surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Neo.radius),
          side: BorderSide(color: dark ? Neo._inkDark : Neo._inkLight, width: Neo.borderW),
        ),
      ),
    );
  }
}
