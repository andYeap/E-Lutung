import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:elutung/features/recap/recap_screen.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/util/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kriteria penerimaan Bagian 14: "Filter kategori pada rekap menyaring tabel
/// **dan** grafik secara konsisten." Persentase harus dihitung ulang terhadap
/// total yang sudah terfilter, bukan total semua kategori.
void main() {
  setUpAll(() async => ensureIntlLocale());

  testWidgets('filter kategori menyaring tabel rekap & menghitung ulang %', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = TransactionRepository(db);
    final now = DateTime.now();
    await repo.create(
      tipe: TxType.pengeluaran,
      nominal: 25000,
      tanggal: DateTime(now.year, now.month, 5),
      kategoriId: 'makanan',
    );
    await repo.create(
      tipe: TxType.pengeluaran,
      nominal: 75000,
      tanggal: DateTime(now.year, now.month, 6),
      kategoriId: 'transport',
    );

    await tester.binding.setSurfaceSize(const Size(1000, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: RecapScreen())),
      ),
    );
    // Stream drift memancarkan data secara asinkron — tunggu sampai muncul.
    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await waitFor(find.textContaining('(75.0%)'));

    // Tanpa filter: kedua kategori tampil, persentase terhadap total 100.000.
    expect(find.textContaining('(75.0%)'), findsOneWidget);
    expect(find.textContaining('(25.0%)'), findsOneWidget);

    // Sorot satu kategori. Chip-nya bisa berada di luar viewport (baris filter
    // bisa di-scroll horizontal), jadi pastikan terlihat dulu.
    final chip = find.widgetWithText(ChoiceChip, 'Makanan & Minuman');
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await waitFor(find.textContaining('(100.0%)'));

    // Tabel kini hanya kategori itu dan persentasenya dihitung ulang (100%),
    // bukan 25% dari total semua kategori.
    expect(find.textContaining('(100.0%)'), findsOneWidget);
    expect(find.textContaining('(75.0%)'), findsNothing);
    expect(find.textContaining('(25.0%)'), findsNothing);
    // Kategori lain hilang dari tabel **dan** legend donut.
    expect(find.textContaining('Rp 75.000'), findsNothing);
    // Persentase tidak boleh dihitung dari total semua kategori
    // (75.000 / 25.000 = 300% — inilah gejala bug lama).
    expect(find.textContaining('300.0%'), findsNothing);

    // Bongkar tree agar timer pembersihan drift sempat berjalan.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
