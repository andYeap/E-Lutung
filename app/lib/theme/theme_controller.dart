import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_style.dart';
import 'neo_palette.dart';

/// Mode tema dan warna kustom yang tersimpan (Bagian FR-11.5 dan FR-11.6).
///
/// Palet bisa berbeda untuk mode terang dan gelap; tiap mode menyimpan
/// penyesuaiannya sendiri dan kembali ke preset saat direset.
class ThemeController extends ChangeNotifier {
  ThemeController();

  static final ThemeController instance = ThemeController();

  static const _modeKey = 'theme_mode';
  static const _customKey = 'theme_custom';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  String _presetId = kThemePresets.first.id;
  String get presetId => _presetId;
  ThemePreset get preset => presetById(_presetId);

  /// Gaya desain (bentuk/border/bayangan), terpisah dari warna.
  String _styleId = kDesignStyles.first.id;
  String get styleId => _styleId;
  DesignStyle get style => designStyleById(_styleId);

  NeoPalette? _lightOverride;
  NeoPalette? _darkOverride;

  /// Palet yang berlaku untuk [brightness]: penyesuaian pengguna bila ada,
  /// kalau tidak preset yang dipilih.
  NeoPalette paletteFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? (_darkOverride ?? preset.dark)
      : (_lightOverride ?? preset.light);

  bool isCustomized(Brightness brightness) =>
      (brightness == Brightness.dark ? _darkOverride : _lightOverride) != null;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = switch (prefs.getString(_modeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

      final raw = prefs.getString(_customKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _presetId = map['preset'] as String? ?? kThemePresets.first.id;
        final gaya = map['style'];
        if (gaya is String) _styleId = designStyleById(gaya).id;
        final light = map['light'];
        final dark = map['dark'];
        if (light is Map<String, dynamic>) {
          _lightOverride = NeoPalette.fromJson(light, preset.light);
        }
        if (dark is Map<String, dynamic>) {
          _darkOverride = NeoPalette.fromJson(dark, preset.dark);
        }
      }
      notifyListeners();
    } catch (_) {
      // Preferensi tidak tersedia atau rusak — pakai bawaan.
    }
  }

  Future<void> setMode(ThemeMode value) async {
    _mode = value;
    notifyListeners();
    await _save();
  }

  /// Pilih preset: penyesuaian manual kedua mode dibuang.
  Future<void> applyPreset(String id) async {
    _presetId = presetById(id).id;
    _lightOverride = null;
    _darkOverride = null;
    notifyListeners();
    await _save();
  }

  /// Pilih gaya desain. Tidak menyentuh warna sama sekali.
  Future<void> setStyle(String id) async {
    _styleId = designStyleById(id).id;
    notifyListeners();
    await _save();
  }

  Future<void> setToken(Brightness brightness, NeoToken token, Color color) async {
    final next = neoTokenWith(paletteFor(brightness), token, color);
    if (brightness == Brightness.dark) {
      _darkOverride = next;
    } else {
      _lightOverride = next;
    }
    notifyListeners();
    await _save();
  }

  /// Kembalikan satu mode ke preset-nya.
  Future<void> resetBrightness(Brightness brightness) async {
    if (brightness == Brightness.dark) {
      _darkOverride = null;
    } else {
      _lightOverride = null;
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, _mode.name);
      await prefs.setString(
        _customKey,
        jsonEncode({
          'preset': _presetId,
          'style': _styleId,
          if (_lightOverride != null) 'light': _lightOverride!.toJson(),
          if (_darkOverride != null) 'dark': _darkOverride!.toJson(),
        }),
      );
    } catch (_) {}
  }
}

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Mengikuti sistem',
  ThemeMode.light => 'Terang',
  ThemeMode.dark => 'Gelap',
};
