import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/features/budget/budget_screen.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/util/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await ensureIntlLocale();
  });

  testWidgets('tombol + di Anggaran membuka dialog Tambah Anggaran', (tester) async {
    // DB dibiarkan terbuka sampai test selesai — menutupnya saat stream masih
    // aktif memicu "Cannot add event while adding stream".
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: BudgetScreen()),
      ),
    );
    // Jangan pumpAndSettle: ada CircularProgressIndicator (animasi tak berujung)
    // selama stream anggaran belum mengirim data pertama.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tombol + harus ada.
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dialog harus terbuka.
    expect(find.text('Tambah Anggaran'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Bongkar widget agar timer pembersihan drift sempat berjalan
    // (kalau tidak, flutter_test melaporkan "Pending timers").
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
