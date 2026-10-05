import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/backup.dart';
import 'data/database.dart';
import 'data/finance.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/budget_repository.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/institution_repository.dart';
import 'data/repositories/recurring_repository.dart';
import 'data/repositories/transaction_repository.dart';

export 'data/backup.dart' show BackupService;
export 'data/repositories/account_repository.dart' show AccountWithInstitution;

/// Database aplikasi (satu instance, ditutup saat provider dibuang).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final institutionRepositoryProvider = Provider<InstitutionRepository>(
  (ref) => InstitutionRepository(ref.watch(databaseProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(databaseProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(databaseProvider)),
);

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(databaseProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

/// Daftar aturan transaksi berulang.
final recurringRulesProvider = StreamProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRepositoryProvider).watchAll(),
);

/// Daftar anggaran.
final budgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(budgetRepositoryProvider).watchAll(),
);

/// Daftar kategori aktif (untuk pemilih & filter).
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

/// Semua kategori termasuk yang terhapus — hanya untuk menerjemahkan
/// `kategoriId` lama jadi nama/warna. Jangan dipakai sebagai pilihan input baru.
final allCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAllIncludingDeleted(),
);

/// Daftar institusi.
final institutionsProvider = StreamProvider<List<Institution>>(
  (ref) => ref.watch(institutionRepositoryProvider).watchAll(),
);

/// Daftar akun (+ institusinya).
final accountsProvider = StreamProvider<List<AccountWithInstitution>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

/// Semua transaksi aktif (dipakai jalur yang butuh data per baris: anggaran,
/// saldo akun, dan widget).
final allTransactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchFiltered(),
);

/// Transaksi yang punya foto struk tersimpan — untuk layar Foto struk di
/// Pengaturan.
final receiptTransactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchWithReceipt(),
);

// ---- Agregat SQL untuk rekap (Bagian 6 & 16 PRD) -------------------------
// Rekap bulanan dihitung di basis data, bukan dengan memuat seluruh transaksi
// ke memori lalu fold di Dart.

/// Total masuk/keluar satu bulan (opsional per kategori) — `SUM` di SQL.
final monthTotalsProvider =
    StreamProvider.family<Totals, ({int year, int month, String? kategoriId})>(
  (ref, key) => ref.watch(transactionRepositoryProvider).watchMonthTotals(
    key.year,
    key.month,
    kategoriId: key.kategoriId,
  ),
);

/// Pengeluaran per kategori satu bulan — `SUM … GROUP BY` di SQL. Ikut
/// terfilter kategori supaya tabel & grafik konsisten (FR-4.3/FR-5.5).
final monthExpenseByCategoryProvider = StreamProvider.family<
    List<CategoryTotal>, ({int year, int month, String? kategoriId})>(
  (ref, key) => ref
      .watch(transactionRepositoryProvider)
      .watchMonthExpenseByCategory(
        key.year,
        key.month,
        kategoriId: key.kategoriId,
      ),
);

/// Seri masuk/keluar per bulan untuk grafik batang — `GROUP BY` di SQL.
/// Ikut terfilter kategori agar sejalan dengan tabel & donut.
final monthlySeriesProvider = StreamProvider.family<
    List<MonthPoint>,
    ({int months, int year, int month, String? kategoriId})>(
  (ref, key) => ref.watch(transactionRepositoryProvider).watchMonthlySeries(
    key.months,
    anchorYear: key.year,
    anchorMonth: key.month,
    kategoriId: key.kategoriId,
  ),
);

/// Id akun milik sendiri (untuk aturan transfer Bagian 8.1).
final ownAccountIdsProvider = Provider<Set<String>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const [];
  return accounts
      .where((a) => a.account.milikSendiri)
      .map((a) => a.account.id)
      .toSet();
});
