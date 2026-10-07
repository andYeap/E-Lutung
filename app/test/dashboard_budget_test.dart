import 'package:drift/native.dart';
import 'package:elutung/app.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/budget_repository.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/theme/theme_controller.dart';
import 'package:elutung/util/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kartu anggaran di Dashboard. Bagian ini sebelumnya tidak punya test sama
/// sekali, sehingga dua cacat lolos: anggaran per kategori tidak pernah
/// ditampilkan, dan pesan "belum ada anggaran aktif" dipakai untuk sebab yang
/// berbeda-beda.
void main() {
  setUpAll(() async => ensureIntlLocale());

  late AppDatabase db;
  late BudgetRepository budgets;
  late TransactionRepository transactions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    budgets = BudgetRepository(db);
    transactions = TransactionRepository(db);
  });
  tearDown(() => db.close());

  /// Kartu anggaran hanya dirender kalau sudah ada transaksi; jika kosong,
  /// Dashboard menampilkan "Data belum ada".
  Future<void> catatPengeluaran(DateTime tanggal, [int nominal = 50000]) =>
      transactions.create(
        tipe: TxType.pengeluaran,
        nominal: nominal,
        tanggal: tanggal,
        kategoriId: 'makanan',
      );

  Future<void> bukaDashboard(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final theme = ThemeController();
    await theme.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: ElutungApp(themeController: theme),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (find.text('Lewati').evaluate().isNotEmpty) {
      await tester.tap(find.text('Lewati'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> bereskan(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  const pesanTidakAdaAktif =
      'Belum ada anggaran aktif untuk periode ini. Setel di tab Anggaran.';
  const pesanPeriodeLain =
      'Tidak ada anggaran yang mencakup periode ini. Anggaran aktif '
      'lainnya ada di periode berbeda, buka tab Anggaran.';

  testWidgets('anggaran total bulan ini: kartu Anggaran aktif muncul', (tester) async {
    final now = DateTime.now();
    await catatPengeluaran(now);
    await budgets.create(
      lingkup: BudgetScope.total,
      nominal: 1000000,
      periodeMulai: DateTime(now.year, now.month, 1),
      periodeSelesai: DateTime(now.year, now.month + 1, 0),
    );

    await bukaDashboard(tester);

    expect(find.text('Anggaran aktif'), findsOneWidget);
    expect(find.text('Total anggaran'), findsNothing);
    expect(find.text(pesanTidakAdaAktif), findsNothing);

    await bereskan(tester);
  });

  testWidgets('anggaran per kategori: Dashboard menampilkan total gabungan', (tester) async {
    final now = DateTime.now();
    await catatPengeluaran(now);
    await budgets.create(
      lingkup: BudgetScope.kategori,
      kategoriId: 'makanan',
      nominal: 500000,
      periodeMulai: DateTime(now.year, now.month, 1),
      periodeSelesai: DateTime(now.year, now.month + 1, 0),
    );

    await bukaDashboard(tester);

    // Sebelum diperbaiki, di sini Dashboard berkata tidak ada anggaran aktif.
    expect(find.text('Total anggaran'), findsOneWidget);
    expect(find.textContaining('gabungan 1 anggaran kategori'), findsOneWidget);
    expect(find.textContaining('Rp 500.000'), findsOneWidget);
    expect(find.text(pesanTidakAdaAktif), findsNothing);

    await bereskan(tester);
  });

  testWidgets('beberapa anggaran kategori: nominalnya dijumlahkan', (tester) async {
    final now = DateTime.now();
    await catatPengeluaran(now);
    for (final (kategori, nominal) in [('makanan', 500000), ('transport', 300000)]) {
      await budgets.create(
        lingkup: BudgetScope.kategori,
        kategoriId: kategori,
        nominal: nominal,
        periodeMulai: DateTime(now.year, now.month, 1),
        periodeSelesai: DateTime(now.year, now.month + 1, 0),
      );
    }

    await bukaDashboard(tester);

    expect(find.textContaining('gabungan 2 anggaran kategori'), findsOneWidget);
    expect(find.textContaining('Rp 800.000'), findsOneWidget);

    await bereskan(tester);
  });

  testWidgets('anggaran total menang, anggaran kategori tidak dihitung ganda', (tester) async {
    final now = DateTime.now();
    await catatPengeluaran(now);
    await budgets.create(
      lingkup: BudgetScope.total,
      nominal: 3000000,
      periodeMulai: DateTime(now.year, now.month, 1),
      periodeSelesai: DateTime(now.year, now.month + 1, 0),
    );
    await budgets.create(
      lingkup: BudgetScope.kategori,
      kategoriId: 'makanan',
      nominal: 500000,
      periodeMulai: DateTime(now.year, now.month, 1),
      periodeSelesai: DateTime(now.year, now.month + 1, 0),
    );

    await bukaDashboard(tester);

    expect(find.text('Anggaran aktif'), findsOneWidget);
    expect(find.textContaining('Rp 3.000.000'), findsOneWidget);
    expect(find.textContaining('Rp 3.500.000'), findsNothing);

    await bereskan(tester);
  });

  testWidgets('rentang 5 bulan ini sampai 5 bulan depan tetap dihitung', (tester) async {
    final now = DateTime.now();
    await catatPengeluaran(now);
    // Kasus yang dilaporkan: anggaran dimulai tanggal 5, bukan tanggal 1.
    await budgets.create(
      lingkup: BudgetScope.total,
      nominal: 1000000,
      periodeMulai: DateTime(now.year, now.month, 5),
      periodeSelesai: DateTime(now.year, now.month + 1, 5),
    );

    await bukaDashboard(tester);

    expect(find.text('Anggaran aktif'), findsOneWidget);
    expect(find.text(pesanTidakAdaAktif), findsNothing);
    expect(find.text(pesanPeriodeLain), findsNothing);

    await bereskan(tester);
  });

  testWidgets('anggaran hanya di periode lain: pesannya menyebut sebabnya', (tester) async {
    final now = DateTime.now();
    final lampau = DateTime(now.year, now.month - 3, 1);
    await catatPengeluaran(now);
    await budgets.create(
      lingkup: BudgetScope.total,
      nominal: 1000000,
      periodeMulai: lampau,
      periodeSelesai: DateTime(lampau.year, lampau.month + 1, 0),
    );

    await bukaDashboard(tester);

    expect(find.text(pesanPeriodeLain), findsOneWidget);
    expect(find.text(pesanTidakAdaAktif), findsNothing);

    await bereskan(tester);
  });

  testWidgets('anggaran nonaktif diabaikan', (tester) async {
    final now = DateTime.now();
    final mulai = DateTime(now.year, now.month, 1);
    final selesai = DateTime(now.year, now.month + 1, 0);
    await catatPengeluaran(now);
    final id = await budgets.create(
      lingkup: BudgetScope.total,
      nominal: 1000000,
      periodeMulai: mulai,
      periodeSelesai: selesai,
    );
    await budgets.update(
      id: id,
      lingkup: BudgetScope.total,
      kategoriId: null,
      periodeMulai: mulai,
      periodeSelesai: selesai,
      nominal: 1000000,
      aktif: false,
    );

    await bukaDashboard(tester);

    expect(find.text(pesanTidakAdaAktif), findsOneWidget);

    await bereskan(tester);
  });
}
