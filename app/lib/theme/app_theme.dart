import 'package:flutter/material.dart';

import '../util/contrast.dart';
import 'design_style.dart';
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

  /// Gaya desain yang berlaku (bentuk, border, bayangan). Palet menentukan
  /// warna, gaya menentukan struktur — keduanya independen.
  static DesignStyle _gaya = kDesignStyles.first;
  static DesignStyle get style => _gaya;

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

  // ---- Struktur (mengikuti gaya terpilih) ----
  static double get borderW => _gaya.borderW;
  static double get radius => _gaya.radius;

  /// Kekuatan blur latar; > 0 pada glass morphism.
  static double get blur => _gaya.blur;
  static const double space = 12.0;

  static void apply(NeoPalette palette) => _aktif = palette;
  static void applyStyle(DesignStyle gaya) => _gaya = gaya;

  /// Kembalikan token ke bawaan. Dipakai untuk isolasi pengujian supaya satu
  /// test tidak mewarisi palet/gaya yang disetel test sebelumnya.
  static void reset() {
    _aktif = kThemePresets.first.light;
    _gaya = kDesignStyles.first;
  }

  /// Warna bayangan: mengikuti [ink] selama ink-nya gelap, dan memakai hitam
  /// saat ink-nya terang supaya bayangan tetap berupa bayangan, bukan pendar.
  static Color get _shadowBase =>
      ink.computeLuminance() > 0.5 ? Colors.black : ink;

  /// Bayangan sesuai gaya aktif. [intensitas] 4 setara skala 1; nol atau gaya
  /// tanpa bayangan menghasilkan null.
  static List<BoxShadow>? shadows(double intensitas) =>
      styleBoxShadows(_gaya, _shadowBase, intensitas);

  /// Bayangan keras, untuk pemakaian langsung di luar [box].
  static List<BoxShadow> hardShadow([double offset = 3]) =>
      shadows(offset) ?? const [];

  static BoxDecoration box({Color? color, double shadow = 4}) =>
      styleDecoration(
        style: _gaya,
        surface: surface,
        ink: ink,
        color: color,
        shadowIntensity: shadow,
      );

  // ---- Tipografi & bentuk tombol (mengikuti gaya) ----
  static FontWeight get titleWeight => _gaya.titleWeight;
  static FontWeight get labelWeight => _gaya.labelWeight;
  static double get letterSpacing => _gaya.letterSpacing;
  static bool get uppercase => _gaya.uppercase;
  static double get cardPadding => _gaya.cardPadding;

  /// Radius tombol/FAB; gaya pil memakai nilai besar agar bulat penuh.
  static double get buttonRadius => _gaya.buttonPill ? 999 : _gaya.buttonRadius;

  /// Dekorasi tombol/FAB: seperti [box] tetapi memakai radius tombol.
  static BoxDecoration buttonBox({Color? color, double shadow = 4}) =>
      styleDecoration(
        style: _gaya,
        surface: surface,
        ink: ink,
        color: color,
        radius: buttonRadius,
        shadowIntensity: shadow,
      );

  /// Bentuk untuk `FloatingActionButton` (yang tidak memakai [box]).
  static OutlinedBorder buttonShapeBorder() {
    final side = _gaya.cardBorderW > 0
        ? BorderSide(
            color: _gaya.lightBorder
                ? Colors.white.withValues(alpha: 0.5)
                : ink,
            width: _gaya.cardBorderW,
          )
        : BorderSide.none;
    if (_gaya.buttonPill) return StadiumBorder(side: side);
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_gaya.buttonRadius),
      side: side,
    );
  }

  /// Garis tepi input mengikuti gaya: border tebal bila gayanya ber-border,
  /// atau garis tipis lembut bila tidak, supaya kolom tetap terlihat.
  static OutlineInputBorder fieldBorder({bool focused = false}) {
    final bw = _gaya.cardBorderW;
    if (bw > 0) {
      final c = _gaya.lightBorder
          ? Colors.white.withValues(alpha: 0.55)
          : ink;
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: c, width: focused ? bw + 1 : bw),
      );
    }
    final halus = Color.alphaBlend(ink.withValues(alpha: 0.22), surface);
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(
        color: focused ? accent : halus,
        width: focused ? 2 : 1,
      ),
    );
  }

  // ---- Efek tekan ----
  static Matrix4 pressTransform(bool down) => switch (_gaya.press) {
    PressKind.shift => Matrix4.translationValues(
      down ? 2 : 0,
      down ? 2 : 0,
      0,
    ),
    PressKind.scale => Matrix4.diagonal3Values(
      down ? 0.98 : 1,
      down ? 0.98 : 1,
      1,
    ),
    PressKind.dim => Matrix4.identity(),
  };

  static double pressShadow(bool down, double base) {
    if (!down) return base;
    return switch (_gaya.press) {
      PressKind.shift => base * 0.5,
      PressKind.scale => base * 0.6,
      PressKind.dim => base,
    };
  }

  static double pressOpacity(bool down) =>
      _gaya.press == PressKind.dim && down ? 0.72 : 1.0;
}

class AppTheme {
  AppTheme._();

  /// Tema dibangun dari palet yang diberikan, bukan dari palet global, supaya
  /// `theme` dan `darkTheme` bisa dibangun berdampingan pada `MaterialApp`.
  static ThemeData light(NeoPalette p) => _build(p, Brightness.light);
  static ThemeData dark(NeoPalette p) => _build(p, Brightness.dark);

  static ThemeData _build(NeoPalette p, Brightness brightness) {
    // Gaya aktif bersifat global (satu untuk terang & gelap), sudah disetel
    // `ElutungApp` sebelum tema dibangun.
    final style = Neo.style;
    final muted = Color.alphaBlend(p.ink.withValues(alpha: 0.55), p.bg);
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
      // Label ChoiceChip terpilih memakai peran ini di Material 3; tanpa
      // override, warnanya berasal dari skema berbasis aksen dan bisa tak
      // terbaca di atas aksen pilihan pengguna.
      onSecondaryContainer: readableOn(p.accent),
    );

    final indikatorTampak = style.navIndicator != NavIndicator.none;
    final navShape = style.navIndicator == NavIndicator.pill
        ? const StadiumBorder()
        : const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          );
    final dlgBorder = style.cardBorderW > 0
        ? BorderSide(
            color: style.lightBorder
                ? Colors.white.withValues(alpha: 0.5)
                : p.ink,
            width: style.cardBorderW,
          )
        : BorderSide.none;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Huruf khas gaya (mis. monospace untuk neobrutalism, serif untuk
      // skeuomorphism). null = huruf bawaan.
      fontFamily: style.fontFamily,
      colorScheme: scheme,
      // Latar transparan bila gaya memakai gradasi latar (glass morphism);
      // gradasinya dipasang `ElutungApp` di belakang konten.
      scaffoldBackgroundColor: style.bgGradient ? Colors.transparent : p.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: p.appBar,
        // Sama seperti aksen: dipilih otomatis agar selalu terbaca.
        foregroundColor: readableOn(p.appBar),
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: readableOn(p.appBar),
          fontWeight: style.titleWeight,
          fontSize: 18,
          letterSpacing: style.letterSpacing,
        ),
      ),
      // `floating` supaya SnackBar tidak menimpa FAB: Material otomatis
      // meletakkannya di atas tombol itu. Sebelumnya mode `fixed` (bawaan)
      // menutupi FAB di Dashboard, Riwayat, dan Anggaran.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.radius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: indikatorTampak ? p.accent : Colors.transparent,
        indicatorShape: navShape,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            fontSize: 12,
            fontWeight: style.labelWeight,
            letterSpacing: style.letterSpacing,
          ),
        ),
        // Tanpa penanda (minimalism), pilihan ditandai lewat warna ikon saja.
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final dipilih = states.contains(WidgetState.selected);
          return IconThemeData(
            color: dipilih
                ? (indikatorTampak ? readableOn(p.accent) : p.accent)
                : muted,
            size: 24,
          );
        }),
        height: 64,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.radius),
          side: dlgBorder,
        ),
      ),
    );
  }
}
