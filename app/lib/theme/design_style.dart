import 'package:flutter/material.dart';

/// Warna dasar sebuah lapis bayangan.
enum ShadowTone {
  /// Bayangan gelap (bawaan) — memakai [Neo.ink] atau hitam.
  dark,

  /// Sorotan terang — dipakai soft UI/neomorphism untuk sisi yang "kena cahaya".
  light,
}

/// Satu lapis bayangan. Sebuah gaya boleh punya beberapa lapis (mis. dua arah
/// pada neomorphism).
class ShadowLayer {
  const ShadowLayer({
    this.dx = 0,
    this.dy = 0,
    this.blur = 2,
    this.alpha = 0.35,
    this.spread = 0,
    this.tone = ShadowTone.dark,
  });

  final double dx;
  final double dy;
  final double blur;
  final double alpha;
  final double spread;
  final ShadowTone tone;
}

/// Cara elemen memberi umpan balik ketika ditekan.
enum PressKind {
  /// Kartu bergeser turun-kanan dan bayangannya menyusut (neobrutalism).
  shift,

  /// Kartu mengecil sedikit (Material/soft UI).
  scale,

  /// Kartu meredup sedikit (flat/minimal).
  dim,
}

/// Cara permukaan diisi warna.
enum SurfaceFill {
  /// Warna rata.
  solid,

  /// Gradasi halus (skeuomorphism).
  gradient,

  /// Warna tembus pandang di atas latar yang diblur (glass morphism).
  translucent,
}

/// Bentuk penanda pilihan pada bilah navigasi bawah.
enum NavIndicator { square, pill, none }

/// Satu gaya desain aplikasi: bentuk, border, bayangan, isian permukaan, efek
/// tekan, **dan** tipografi/bentuk tombol.
///
/// Warna tetap datang dari [NeoPalette]; gaya mengatur struktur dan tipografi,
/// jadi gaya apa pun bisa dipasangkan dengan palet apa pun.
///
/// Istilah gayanya mengikuti "Top 22 Types of UI/UX Designs": Flat, Material,
/// Skeuomorphic, Neomorphism (Soft UI), Brutalism, Glass Morphism, Minimalism.
class DesignStyle {
  const DesignStyle({
    required this.id,
    required this.name,
    required this.description,
    this.radius = 8,
    this.borderW = 0,
    this.cardBorderW = 0,
    this.lightBorder = false,
    this.shadows = const [],
    this.press = PressKind.scale,
    this.fill = SurfaceFill.solid,
    this.surfaceAlpha = 1,
    this.blur = 0,
    this.fontFamily,
    this.titleWeight = FontWeight.w800,
    this.labelWeight = FontWeight.w700,
    this.letterSpacing = 0,
    this.uppercase = false,
    this.buttonRadius = 8,
    this.buttonPill = false,
    this.cardPadding = 14,
    this.bgGradient = false,
    this.navIndicator = NavIndicator.square,
  });

  final String id;
  final String name;
  final String description;

  /// Radius sudut untuk kartu dan input.
  final double radius;

  /// Tebal border struktural di seluruh aplikasi (chip, garis bawah bilah atas,
  /// tepi dialog). `0` berarti tanpa border.
  final double borderW;

  /// Tebal border permukaan kartu/tombol/input. Biasanya sama dengan
  /// [borderW], tetapi glass morphism memakainya untuk tepi tipis terang tanpa
  /// memberi garis bawah pada bilah atas.
  final double cardBorderW;

  /// Bila true, border kartu memakai garis terang (bukan [Neo.ink]).
  final bool lightBorder;

  final List<ShadowLayer> shadows;
  final PressKind press;
  final SurfaceFill fill;

  /// Kepekatan warna permukaan saat [SurfaceFill.translucent] (0–1).
  final double surfaceAlpha;

  /// Kekuatan blur latar (sigma) saat [SurfaceFill.translucent].
  final double blur;

  /// Jenis huruf khas gaya. `null` berarti huruf bawaan aplikasi (Roboto).
  final String? fontFamily;

  /// Bobot huruf judul (judul seksi, bilah atas).
  final FontWeight titleWeight;

  /// Bobot huruf label (tombol, teks tebal).
  final FontWeight labelWeight;

  /// Jarak antarhuruf untuk judul dan tombol.
  final double letterSpacing;

  /// Bila true, judul seksi ditulis kapital.
  final bool uppercase;

  /// Radius tombol dan FAB (bisa berbeda dari [radius] kartu).
  final double buttonRadius;

  /// Bila true, tombol berbentuk pil (Material).
  final bool buttonPill;

  /// Padding bawaan kartu.
  final double cardPadding;

  /// Bila true, latar aplikasi diberi gradasi halus (agar glass terlihat).
  final bool bgGradient;

  /// Bentuk penanda pilihan pada bilah navigasi.
  final NavIndicator navIndicator;
}

/// Gaya bawaan. Yang pertama adalah gaya lama (neobrutalism) sehingga tampilan
/// pengguna yang sudah ada tidak berubah setelah pembaruan.
const List<DesignStyle> kDesignStyles = [
  DesignStyle(
    id: 'brutal',
    name: 'Neobrutalism',
    description: 'Border tebal, sudut tegas, bayangan keras.',
    radius: 4,
    borderW: 2,
    cardBorderW: 2,
    shadows: [ShadowLayer(dx: 4, dy: 4, blur: 2, alpha: 0.35)],
    press: PressKind.shift,
    buttonRadius: 3,
    cardPadding: 12,
  ),
  DesignStyle(
    id: 'flat',
    name: 'Flat',
    description: 'Rata, sudut hampir tegak, warna solid tanpa bayangan.',
    radius: 3,
    press: PressKind.dim,
    buttonRadius: 3,
    cardPadding: 16,
  ),
  DesignStyle(
    id: 'material',
    name: 'Material',
    description: 'Tombol pil, kartu membulat, bayangan kertas yang halus.',
    radius: 16,
    shadows: [ShadowLayer(dy: 3, blur: 10, alpha: 0.18)],
    press: PressKind.scale,
    buttonRadius: 28,
    buttonPill: true,
    cardPadding: 16,
    navIndicator: NavIndicator.pill,
  ),
  DesignStyle(
    id: 'neumorph',
    name: 'Neomorphism',
    description: 'Timbul lembut dari latar, dua bayangan terang-gelap.',
    radius: 24,
    shadows: [
      ShadowLayer(dx: 4, dy: 4, blur: 8, alpha: 0.28),
      ShadowLayer(dx: -4, dy: -4, blur: 8, alpha: 0.85, tone: ShadowTone.light),
    ],
    press: PressKind.scale,
    buttonRadius: 20,
    cardPadding: 18,
    navIndicator: NavIndicator.pill,
  ),
  DesignStyle(
    id: 'glass',
    name: 'Glass Morphism',
    description: 'Kaca buram di atas latar berwarna, tepi tipis terang.',
    radius: 18,
    cardBorderW: 1,
    lightBorder: true,
    press: PressKind.scale,
    fill: SurfaceFill.translucent,
    surfaceAlpha: 0.45,
    blur: 14,
    buttonRadius: 14,
    cardPadding: 16,
    bgGradient: true,
    navIndicator: NavIndicator.pill,
  ),
  DesignStyle(
    id: 'skeuo',
    name: 'Skeuomorphic',
    description: 'Permukaan bergradasi dan bayangan, kesan benda nyata.',
    radius: 8,
    borderW: 1,
    cardBorderW: 1,
    shadows: [ShadowLayer(dy: 2, blur: 6, alpha: 0.25)],
    press: PressKind.shift,
    fill: SurfaceFill.gradient,
    buttonRadius: 8,
  ),
  DesignStyle(
    id: 'minimal',
    name: 'Minimalism',
    description: 'Banyak ruang, tanpa bayangan, warna tenang.',
    radius: 6,
    press: PressKind.dim,
    buttonRadius: 6,
    cardPadding: 20,
    navIndicator: NavIndicator.none,
  ),
];

DesignStyle designStyleById(String? id) => kDesignStyles.firstWhere(
  (s) => s.id == id,
  orElse: () => kDesignStyles.first,
);

/// Membentuk dekorasi kotak dari sebuah [style] secara murni (tanpa state
/// global), supaya bisa dipakai juga untuk pratinjau gaya lain.
BoxDecoration styleDecoration({
  required DesignStyle style,
  required Color surface,
  required Color ink,
  Color? color,
  double? radius,
  double shadowIntensity = 4,
}) {
  final base = color ?? surface;
  final darkBase = ink.computeLuminance() > 0.5 ? Colors.black : ink;
  final bw = style.cardBorderW;
  return BoxDecoration(
    color: switch (style.fill) {
      SurfaceFill.gradient => null,
      SurfaceFill.translucent => base.withValues(alpha: style.surfaceAlpha),
      SurfaceFill.solid => base,
    },
    gradient: style.fill == SurfaceFill.gradient
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(Colors.white.withValues(alpha: 0.28), base),
              Color.alphaBlend(ink.withValues(alpha: 0.12), base),
            ],
          )
        : null,
    borderRadius: BorderRadius.circular(radius ?? style.radius),
    border: bw > 0
        ? Border.all(
            color: style.lightBorder
                ? Colors.white.withValues(alpha: 0.45)
                : ink,
            width: bw,
          )
        : null,
    boxShadow: styleBoxShadows(style, darkBase, shadowIntensity),
  );
}

/// Menghitung bayangan sebuah gaya. [intensity] 4 setara skala 1.
List<BoxShadow>? styleBoxShadows(
  DesignStyle style,
  Color darkBase,
  double intensity,
) {
  if (intensity <= 0 || style.shadows.isEmpty) return null;
  final scale = intensity / 4.0;
  return [
    for (final l in style.shadows)
      BoxShadow(
        color: (l.tone == ShadowTone.light ? Colors.white : darkBase)
            .withValues(alpha: l.alpha),
        offset: Offset(l.dx * scale, l.dy * scale),
        blurRadius: l.blur * scale,
        spreadRadius: l.spread * scale,
      ),
  ];
}

/// Gradasi latar aplikasi untuk gaya yang memintanya (mis. glass morphism),
/// supaya permukaan tembus pandang punya sesuatu untuk di-blur.
LinearGradient? styleBackgroundGradient(
  DesignStyle style,
  Color bg,
  Color accent,
) {
  if (!style.bgGradient) return null;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.alphaBlend(accent.withValues(alpha: 0.35), bg),
      Color.alphaBlend(accent.withValues(alpha: 0.10), bg),
      bg,
    ],
  );
}
