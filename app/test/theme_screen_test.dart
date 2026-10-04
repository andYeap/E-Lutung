import 'package:elutung/features/theme/theme_screen.dart';
import 'package:elutung/theme/neo_palette.dart';
import 'package:elutung/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layar Tema & warna (Bagian 6c, FR-11.6).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ThemeController> pasang(WidgetTester tester) async {
    // Layarnya panjang; viewport test harus cukup tinggi agar seluruh daftar
    // ikut dibangun (ListView hanya membangun anak yang terlihat).
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final c = ThemeController();
    await tester.pumpWidget(MaterialApp(home: ThemeScreen(controller: c)));
    await tester.pump();
    return c;
  }

  testWidgets('menampilkan semua preset, mode, dan lima token warna', (
    tester,
  ) async {
    await pasang(tester);

    for (final preset in kThemePresets) {
      expect(find.text(preset.name), findsOneWidget);
    }
    for (final token in NeoToken.values) {
      expect(find.text(neoTokenLabel(token)), findsOneWidget);
    }
    expect(find.text('Warna terang'), findsOneWidget);
    expect(find.text('Warna gelap'), findsOneWidget);
  });

  testWidgets('memilih preset langsung mengubah palet', (tester) async {
    final c = await pasang(tester);

    await tester.tap(find.text('Ungu Lembut'));
    await tester.pump();

    expect(c.presetId, 'ungu');
    expect(c.paletteFor(Brightness.light).bg, presetById('ungu').light.bg);
    expect(c.paletteFor(Brightness.dark).bg, presetById('ungu').dark.bg);
  });

  testWidgets('mengganti mode tampilan tidak menyentuh warna', (tester) async {
    final c = await pasang(tester);

    await tester.tap(find.text('Gelap'));
    await tester.pump();

    expect(c.mode, ThemeMode.dark);
    expect(c.isCustomized(Brightness.light), isFalse);
    expect(c.isCustomized(Brightness.dark), isFalse);
  });

  testWidgets('warna semantik tidak pernah muncul sebagai token yang bisa diubah', (
    tester,
  ) async {
    await pasang(tester);

    // Yang tampil hanya lima token tampilan; tidak ada pemasukan/pengeluaran.
    expect(find.textContaining('Pemasukan'), findsNothing);
    expect(find.textContaining('Pengeluaran'), findsNothing);
    expect(NeoToken.values.length, 5);
  });
}
