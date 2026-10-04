import 'package:elutung/theme/app_theme.dart';
import 'package:elutung/theme/neo_palette.dart';
import 'package:elutung/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema yang dapat disesuaikan (Bagian 6c, FR-11.6).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('bawaan: ikut sistem, preset pertama, belum ada penyesuaian', () async {
    final c = ThemeController();
    expect(c.mode, ThemeMode.system);
    expect(c.presetId, kThemePresets.first.id);
    expect(c.isCustomized(Brightness.light), isFalse);
    expect(c.isCustomized(Brightness.dark), isFalse);
    expect(c.paletteFor(Brightness.light), kThemePresets.first.light);
    expect(c.paletteFor(Brightness.dark), kThemePresets.first.dark);
  });

  test('memilih preset mengganti warna kedua mode', () async {
    final c = ThemeController();
    await c.applyPreset('ungu');
    final ungu = presetById('ungu');
    expect(c.presetId, 'ungu');
    expect(c.paletteFor(Brightness.light).bg, ungu.light.bg);
    expect(c.paletteFor(Brightness.dark).bg, ungu.dark.bg);
  });

  test('menyetel satu mode tidak mengubah mode lain', () async {
    final c = ThemeController();
    await c.applyPreset('krem');
    await c.setToken(Brightness.light, NeoToken.bg, const Color(0xFF123456));

    expect(c.paletteFor(Brightness.light).bg, const Color(0xFF123456));
    expect(c.paletteFor(Brightness.dark).bg, presetById('krem').dark.bg);
    expect(c.isCustomized(Brightness.light), isTrue);
    expect(c.isCustomized(Brightness.dark), isFalse);
  });

  test('reset mengembalikan satu mode ke preset, mode lain tetap', () async {
    final c = ThemeController();
    await c.setToken(Brightness.dark, NeoToken.accent, const Color(0xFF223344));
    await c.setToken(Brightness.light, NeoToken.accent, const Color(0xFF556677));

    await c.resetBrightness(Brightness.dark);

    expect(c.isCustomized(Brightness.dark), isFalse);
    expect(c.paletteFor(Brightness.dark), presetById(c.presetId).dark);
    expect(c.paletteFor(Brightness.light).accent, const Color(0xFF556677));
  });

  test('mengganti preset membuang penyesuaian manual', () async {
    final c = ThemeController();
    await c.setToken(Brightness.light, NeoToken.bg, const Color(0xFF123456));
    await c.applyPreset('biru');
    expect(c.isCustomized(Brightness.light), isFalse);
    expect(c.paletteFor(Brightness.light), presetById('biru').light);
  });

  test('pengaturan bertahan setelah dimuat ulang', () async {
    final pertama = ThemeController();
    await pertama.setMode(ThemeMode.dark);
    await pertama.applyPreset('teal');
    await pertama.setToken(
      Brightness.light,
      NeoToken.accent,
      const Color(0xFF0A0B0C),
    );

    final kedua = ThemeController();
    await kedua.load();

    expect(kedua.mode, ThemeMode.dark);
    expect(kedua.presetId, 'teal');
    expect(kedua.paletteFor(Brightness.light).accent, const Color(0xFF0A0B0C));
    // Mode gelap tetap memakai preset, tidak ikut berubah.
    expect(
      kedua.paletteFor(Brightness.dark).accent,
      presetById('teal').dark.accent,
    );
  });

  test('pengaturan rusak tidak menggagalkan pemuatan', () async {
    SharedPreferences.setMockInitialValues({'theme_custom': 'bukan json'});
    final c = ThemeController();
    await c.load();
    expect(c.presetId, kThemePresets.first.id);
    expect(c.isCustomized(Brightness.light), isFalse);
    expect(c.mode, ThemeMode.system);
  });

  test('hanya token tampilan yang bisa diubah; warna semantik terkunci', () {
    expect(NeoToken.values.toSet(), {
      NeoToken.bg,
      NeoToken.surface,
      NeoToken.ink,
      NeoToken.appBar,
      NeoToken.accent,
    });
    expect(Neo.income, kIncomeColor);
    expect(Neo.expense, kExpenseColor);
    expect(Neo.transfer, kTransferColor);
  });

  test('token Neo mengikuti palet yang diterapkan', () {
    final c = ThemeController();
    final palet = c.paletteFor(Brightness.light);
    Neo.apply(palet);
    expect(Neo.bg, palet.bg);
    expect(Neo.appBar, palet.appBar);
    expect(Neo.accent, palet.accent);
    // muted diturunkan, bukan token yang bisa disetel.
    expect(Neo.muted, isNot(palet.bg));
    expect(Neo.muted, isNot(palet.ink));
  });
}
