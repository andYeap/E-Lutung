import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/recurring_repository.dart';
import 'package:elutung/features/recurring/recurring_screen.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/util/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async => ensureIntlLocale());

  Future<void> pumpScreen(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RecurringScreen()),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('tanpa aturan: tampil keadaan kosong yang menjelaskan', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await pumpScreen(tester, db);

    expect(find.text('Belum ada aturan berulang'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('aturan tampil dengan nominal dan jatuh tempo berikutnya', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await RecurringRepository(db).create(
      tipe: TxType.pengeluaran,
      nominal: 150000,
      kategoriId: 'hiburan',
      frekuensi: Frequency.bulanan,
      // Jatuh tempo berikutnya sudah lewat, jadi pasti terlihat tanggalnya.
      mulai: DateTime(2020, 1, 15),
    );

    await pumpScreen(tester, db);

    expect(find.text('−Rp 150.000'), findsOneWidget);
    expect(find.textContaining('Hiburan'), findsWidgets);
    expect(find.textContaining('Berikutnya:'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
