import 'package:drift/native.dart';
import 'package:elutung/app.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/budget_repository.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/theme/theme_controller.dart';
import 'package:elutung/util/format.dart';
import 'package:elutung/widgets/neo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kartu anggaran di Dashboard: hanya anggaran yang sudah terpakai yang
/// ditampilkan, yang paling terkuras lebih dulu.
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
  Future<void> catatPengeluaran(
    DateTime tanggal, {
    int nominal = 50000,
    String kategori = 'makanan',
  }) => transactions.create(
    tipe: TxType.pengeluaran,
    nominal: nominal,
    tanggal: tanggal,
    kategoriId: kategori,
  );

  Future<void> buatAnggaran({
    BudgetScope lingkup = BudgetScope.kategori,
    String? kategoriId,
    required int nominal,
    DateTime? mulai,
    DateTime? selesai,
  }) async {
    final now = DateTime.now();
    await budgets.create(
      lingkup: lingkup,
      kategoriId: kategoriId,
      nominal: nominal,
      periodeMulai: mulai ?? DateTime(now.year, now.month, 1),
      periodeSelesai: selesai ?? DateTime(now.year, now.month + 1, 0),
    );
  }

  Future<void> bukaDashboard(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
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

  /// Nama kategori juga muncul di daftar transaksi terbaru dan di tab Anggaran,
  /// jadi pencarian dibatasi ke dalam kartu anggaran Dashboard.
  Finder diKartuAnggaran(Finder f) => find.descendant(
    of: find
        .ancestor(
          of: find.text('Anggaran terpakai'),
          matching: find.byType(NeoCard),
        )
        .first,
    matching: f,
  );

  const pesanTidakAdaAktif =
      'Belum ada anggaran aktif untuk periode ini. Setel di tab Anggaran.';
  const pesanPeriodeLain =
      'Tidak ada anggaran yang mencakup periode ini. Anggaran aktif '
      'lainnya ada di periode berbeda, buka tab Anggaran.';

  testWidgets('hanya yang terpakai yang tampil, yang paling terkuras di atas', (
    tester,
  ) async {
    final now = DateTime.now();
    await catatPengeluaran(now, nominal: 50000); // makanan 50.000
    await catatPengeluaran(now, nominal: 150000, kategori: 'transport');
    await buatAnggaran(kategoriId: 'makanan', nominal: 500000); // 10%
    await buatAnggaran(kategoriId: 'transport', nominal: 300000); // 50%
    await buatAnggaran(kategoriId: 'tagihan', nominal: 200000);

    await bukaDashboard(tester);

    expect(find.text('Anggaran terpakai'), findsOneWidget);
    expect(diKartuAnggaran(find.text('Makanan & Minuman')), findsOneWidget);
    expect(diKartuAnggaran(find.text('Transport')), findsOneWidget);
    expect(diKartuAnggaran(find.text('10%')), findsOneWidget);
    expect(diKartuAnggaran(find.text('50%')), findsOneWidget);

    // Anggaran yang belum tersentuh tidak memakan ruang, hanya dihitung.
    expect(diKartuAnggaran(find.text('Tagihan & Utilitas')), findsNothing);
    expect(find.text('1 anggaran lain belum terpakai'), findsOneWidget);

    // Transport 50% tampil di atas makanan 10%.
    expect(
      tester.getTopLeft(diKartuAnggaran(find.text('Transport'))).dy,
      lessThan(
        tester.getTopLeft(diKartuAnggaran(find.text('Makanan & Minuman'))).dy,
      ),
    );

    await bereskan(tester);
  });

  testWidgets('anggaran total punya barisnya sendiri', (tester) async {
    final now = DateTime.now();
    await catatPengeluaran(now, nominal: 50000);
    await buatAnggaran(lingkup: BudgetScope.total, nominal: 1000000);

    await bukaDashboard(tester);

    expect(diKartuAnggaran(find.text('Total pengeluaran')), findsOneWidget);
    expect(diKartuAnggaran(find.text('5%')), findsOneWidget);
    expect(find.text(pesanTidakAdaAktif), findsNothing);
    expect(find.text(pesanPeriodeLain), findsNothing);

    await bereskan(tester);
  });

  testWidgets('belum ada yang terpakai: pesannya menyebut jumlah anggaran', (
    tester,
  ) async {
    final now = DateTime.now();
    // Pengeluaran di kategori yang tidak punya anggaran.
    await catatPengeluaran(now, kategori: 'hiburan');
    await buatAnggaran(kategoriId: 'makanan', nominal: 500000);
    await buatAnggaran(kategoriId: 'transport', nominal: 300000);

    await bukaDashboard(tester);

    expect(
      find.text(
        'Belum ada anggaran yang terpakai untuk periode ini. '
        '2 anggaran sudah disetel, buka tab Anggaran.',
      ),
      findsOneWidget,
    );
    expect(find.text('Anggaran terpakai'), findsNothing);

    await bereskan(tester);
  });

  testWidgets('baris dibatasi tiga, sisanya diringkas', (tester) async {
    final now = DateTime.now();
    for (final (kategori, nominal, belanja) in [
      ('makanan', 500000, 50000), // 10%, terendah
      ('transport', 300000, 150000), // 50%
      ('tagihan', 200000, 40000), // 20%
      ('hiburan', 400000, 400000), // 100%, tertinggi
    ]) {
      await catatPengeluaran(now, nominal: belanja, kategori: kategori);
      await buatAnggaran(kategoriId: kategori, nominal: nominal);
    }

    await bukaDashboard(tester);

    expect(diKartuAnggaran(find.text('100%')), findsOneWidget);
    expect(diKartuAnggaran(find.text('50%')), findsOneWidget);
    expect(diKartuAnggaran(find.text('20%')), findsOneWidget);
    // Baris keempat jatuh ke ringkasan.
    expect(diKartuAnggaran(find.text('Makanan & Minuman')), findsNothing);
    expect(find.text('+1 anggaran terpakai lain'), findsOneWidget);

    await bereskan(tester);
  });

  testWidgets('rentang yang tidak mulai tanggal 1 tetap dihitung', (tester) async {
    final now = DateTime.now();
    final tanggalLima = DateTime(now.year, now.month, 5);
    // Kasus yang pernah dilaporkan: anggaran dimulai tanggal 5, bukan tanggal 1.
    await catatPengeluaran(tanggalLima, nominal: 50000);
    await buatAnggaran(
      kategoriId: 'makanan',
      nominal: 500000,
      mulai: tanggalLima,
      selesai: DateTime(now.year, now.month + 1, 5),
    );

    await bukaDashboard(tester);

    expect(diKartuAnggaran(find.text('Makanan & Minuman')), findsOneWidget);
    expect(find.text(pesanTidakAdaAktif), findsNothing);
    expect(find.text(pesanPeriodeLain), findsNothing);

    await bereskan(tester);
  });

  testWidgets('anggaran hanya di periode lain: pesannya menyebut sebabnya', (
    tester,
  ) async {
    final now = DateTime.now();
    final lampau = DateTime(now.year, now.month - 3, 1);
    await catatPengeluaran(now);
    await buatAnggaran(
      kategoriId: 'makanan',
      nominal: 500000,
      mulai: lampau,
      selesai: DateTime(lampau.year, lampau.month + 1, 0),
    );

    await bukaDashboard(tester);

    expect(find.text(pesanPeriodeLain), findsOneWidget);
    expect(find.text(pesanTidakAdaAktif), findsNothing);

    await bereskan(tester);
  });

  testWidgets('anggaran nonaktif diabaikan', (tester) async {
    final now = DateTime.now();
    await catatPengeluaran(now);
    final id = await budgets.create(
      lingkup: BudgetScope.kategori,
      kategoriId: 'makanan',
      nominal: 500000,
      periodeMulai: DateTime(now.year, now.month, 1),
      periodeSelesai: DateTime(now.year, now.month + 1, 0),
    );
    await budgets.update(
      id: id,
      lingkup: BudgetScope.kategori,
      kategoriId: 'makanan',
      periodeMulai: DateTime(now.year, now.month, 1),
      periodeSelesai: DateTime(now.year, now.month + 1, 0),
      nominal: 500000,
      aktif: false,
    );

    await bukaDashboard(tester);

    expect(find.text(pesanTidakAdaAktif), findsOneWidget);

    await bereskan(tester);
  });
}
