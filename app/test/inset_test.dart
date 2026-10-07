import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/features/shell.dart';
import 'package:elutung/features/transactions/transaction_form_screen.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/util/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ruang untuk bilah navigasi sistem. Tanpa ini, tombol paling bawah tertutup
/// di HP yang menyalakan navbar (aplikasi menggambar sampai tepi layar karena
/// targetSdk Android 15 memaksa edge-to-edge).
void main() {
  setUpAll(() async => ensureIntlLocale());

  const tinggiNavbar = 48.0;
  const tinggiLayar = 800.0;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> pompa(WidgetTester tester, [int kali = 12]) async {
    for (var i = 0; i < kali; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('FAB di shell tetap di atas bilah navigasi sistem', (tester) async {
    try {
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: tinggiNavbar);
      tester.view.padding = const FakeViewPadding(bottom: tinggiNavbar);
      addTearDown(tester.view.reset);

      await tester.binding.setSurfaceSize(
        const Size(400, tinggiLayar),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: ShellScreen()),
        ),
      );
      await pompa(tester);

      final fab = tester.getRect(find.byType(FloatingActionButton));
      final batas = tinggiLayar - tinggiNavbar;
      expect(
        fab.bottom,
        lessThanOrEqualTo(batas),
        reason: 'FAB (${fab.bottom}) tidak boleh masuk area navbar ($batas)',
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    }
  });

  testWidgets('tombol Simpan di form tetap di atas bilah navigasi', (tester) async {
    try {
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: tinggiNavbar);
      tester.view.padding = const FakeViewPadding(bottom: tinggiNavbar);
      addTearDown(tester.view.reset);

      await tester.binding.setSurfaceSize(
        const Size(400, tinggiLayar),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: TransactionFormScreen(tipe: TxType.pengeluaran),
          ),
        ),
      );
      await pompa(tester);

      // Daftarnya panjang dan ListView membangun anaknya bertahap, jadi digulir
      // dulu seperti pengguna sampai tombolnya benar-benar terbangun.
      await tester.scrollUntilVisible(
        find.text('Simpan'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      final batas = tinggiLayar - tinggiNavbar;
      // Area gulirnya sendiri tidak boleh menembus bilah navigasi: inilah yang
      // membuat isi paling bawah bisa tergulir sampai terlihat.
      final area = tester.getRect(find.byType(ListView).first);
      expect(
        area.bottom,
        lessThanOrEqualTo(batas),
        reason: 'Area gulir (${area.bottom}) menembus area navbar ($batas)',
      );

      final rect = tester.getRect(find.text('Simpan'));
      expect(
        rect.bottom,
        lessThanOrEqualTo(batas),
        reason: 'Tombol Simpan (${rect.bottom}) masuk area navbar ($batas)',
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
}
