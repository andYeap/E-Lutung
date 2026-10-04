import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/features/shell.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/util/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Penjaga regresi untuk bug lama: tombol tambah anggaran pernah tidak berfungsi
/// karena `LocaleDataException` (DateFormat dipakai sebelum locale dimuat).
///
/// Sejak tombol tambah dimiliki shell, pengujiannya lewat [ShellScreen] lalu
/// pindah ke tab Anggaran — bukan lagi lewat FAB milik layar Anggaran.
void main() {
  setUpAll(() async {
    await ensureIntlLocale();
  });

  /// DB dibiarkan terbuka sampai test selesai — menutupnya saat stream masih
  /// aktif memicu "Cannot add event while adding stream".
  Future<AppDatabase> nyalakan(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ShellScreen()),
      ),
    );
    // Jangan pumpAndSettle: stream drift butuh beberapa putaran pump.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return db;
  }

  Future<void> bukaTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> bereskan(WidgetTester tester) async {
    // Bongkar widget agar timer pembersihan drift sempat berjalan
    // (kalau tidak, flutter_test melaporkan "Pending timers").
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('tombol + di tab Anggaran membuka dialog Tambah Anggaran', (
    tester,
  ) async {
    await nyalakan(tester);
    await bukaTab(tester, 'Anggaran');

    // Tombol + milik shell harus ada di tab ini.
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tambah Anggaran'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await bereskan(tester);
  });

  testWidgets('tab Rekap tidak menampilkan tombol tambah', (tester) async {
    await nyalakan(tester);
    await bukaTab(tester, 'Rekap');

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);

    await bereskan(tester);
  });
}
