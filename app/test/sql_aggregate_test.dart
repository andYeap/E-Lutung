import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/finance.dart';
import 'package:elutung/data/repositories/account_repository.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Memastikan agregasi SQL (yang dipakai layar Rekap) menghasilkan angka yang
/// **sama persis** dengan aturan murni di `finance.dart` — sumber kebenaran
/// tunggal untuk perlakuan transfer (Bagian 8.1).
void main() {
  late AppDatabase db;
  late TransactionRepository txs;
  late AccountRepository accounts;

  late String own1;
  late String own2;
  late String ext;
  late String ownThenDeleted;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    txs = TransactionRepository(db);
    accounts = AccountRepository(db);

    own1 = await accounts.create(
      institusiId: 'tunai',
      milikSendiri: true,
      saldoAwal: 0,
    );
    own2 = await accounts.create(
      institusiId: 'bca',
      milikSendiri: true,
      saldoAwal: 0,
    );
    ext = await accounts.create(
      institusiId: 'lain',
      milikSendiri: false,
      saldoAwal: 0,
    );
    ownThenDeleted = await accounts.create(
      institusiId: 'ovo',
      milikSendiri: true,
      saldoAwal: 0,
    );
    await accounts.softDelete(ownThenDeleted);
  });
  tearDown(() => db.close());

  /// Isi fixture: campuran pemasukan, pengeluaran, dan ketiga jenis transfer.
  Future<void> seed() async {
    // Maret 2026
    await txs.create(
      tipe: TxType.pengeluaran,
      nominal: 25000,
      tanggal: DateTime(2026, 3, 5, 9),
      kategoriId: 'makanan',
    );
    await txs.create(
      tipe: TxType.pemasukan,
      nominal: 1000000,
      tanggal: DateTime(2026, 3, 10, 8),
      kategoriId: 'gaji',
    );
    // Transfer antar akun sendiri → hanya biaya admin jadi pengeluaran.
    await txs.create(
      tipe: TxType.transfer,
      nominal: 500000,
      biayaAdmin: 2500,
      tanggal: DateTime(2026, 3, 12, 10),
      akunAsalId: own1,
      akunTujuanId: own2,
    );
    // Transfer ke pihak lain → nominal + admin.
    await txs.create(
      tipe: TxType.transfer,
      nominal: 100000,
      biayaAdmin: 1000,
      tanggal: DateTime(2026, 3, 15, 10),
      akunAsalId: own1,
      akunTujuanId: ext,
    );
    // Tujuan akun yang sudah dihapus → tidak lagi "milik sendiri".
    await txs.create(
      tipe: TxType.transfer,
      nominal: 400000,
      tanggal: DateTime(2026, 3, 20, 10),
      akunAsalId: own1,
      akunTujuanId: ownThenDeleted,
    );
    // Transaksi terhapus harus diabaikan.
    final gone = await txs.create(
      tipe: TxType.pengeluaran,
      nominal: 999999,
      tanggal: DateTime(2026, 3, 21),
      kategoriId: 'makanan',
    );
    await txs.softDelete(gone);
    // April 2026, tepat setelah batas bulan.
    await txs.create(
      tipe: TxType.pengeluaran,
      nominal: 7000,
      tanggal: DateTime(2026, 4, 1, 5),
      kategoriId: 'transport',
    );
  }

  Future<Set<String>> ownIds() async {
    final rows = await accounts.watchAll().first;
    return rows
        .where((a) => a.account.milikSendiri)
        .map((a) => a.account.id)
        .toSet();
  }

  /// Transaksi Maret 2026 menurut Dart (pembanding yang setara dengan query
  /// SQL `watchMonthTotals(2026, 3)`).
  Future<List<Transaction>> marchRows() async => (await txs.all())
      .where((t) => t.tanggal.year == 2026 && t.tanggal.month == 3)
      .toList();

  test('total bulan (SQL) == computeTotals (Dart)', () async {
    await seed();
    final own = await ownIds();
    final dartTotals = computeTotals(await marchRows(), own);

    final sqlTotals = await txs.watchMonthTotals(2026, 3).first;

    expect(sqlTotals.income, dartTotals.income);
    expect(sqlTotals.expense, dartTotals.expense);
    // Nilai eksplisit: pengeluaran 25.000 + admin 2.500 + (100.000+1.000)
    // + 400.000 (tujuan akun terhapus) = 528.500.
    expect(sqlTotals.expense, 528500);
    expect(sqlTotals.income, 1000000);
  });

  test('batas bulan: transaksi 1 April tidak masuk total Maret', () async {
    await seed();
    final march = await txs.watchMonthTotals(2026, 3).first;
    final april = await txs.watchMonthTotals(2026, 4).first;
    expect(april.expense, 7000);
    expect(march.expense, 528500);
  });

  test('pengeluaran per kategori (SQL) == expenseByCategory (Dart)', () async {
    await seed();
    final own = await ownIds();
    final dart = expenseByCategory(await marchRows(), own)
        .where((c) => c.total != 0)
        .toList();

    final sql = await txs.watchMonthExpenseByCategory(2026, 3).first;

    expect(sql.length, dart.length);
    for (var i = 0; i < dart.length; i++) {
      expect(sql[i].kategoriId, dart[i].kategoriId);
      expect(sql[i].total, dart[i].total);
    }
  });

  test('per kategori terfilter (FR-5.5) hanya berisi kategori itu', () async {
    await seed();
    final sql = await txs
        .watchMonthExpenseByCategory(2026, 3, kategoriId: 'makanan')
        .first;
    expect(sql.length, 1);
    expect(sql.single.kategoriId, 'makanan');
    expect(sql.single.total, 25000);
  });

  test('biaya admin transfer antar akun sendiri masuk "Transfer & Admin"', () async {
    await seed();
    final all = await txs.watchMonthExpenseByCategory(2026, 3).first;
    // makanan 25.000 · Transfer & Admin 2.500 (admin internal) ·
    // Tanpa kategori 501.000 (transfer ke pihak lain + tujuan akun terhapus).
    expect(all.length, 3);
    final admin = all.firstWhere(
      (c) => c.kategoriId == kTransferAdminCategoryId,
    );
    expect(admin.total, 2500);

    // Filter kategori memakai kategori pembukuan yang sama, bukan kolom mentah.
    final filtered = await txs
        .watchMonthExpenseByCategory(2026, 3, kategoriId: kTransferAdminCategoryId)
        .first;
    expect(filtered.single.total, 2500);

    final totals = await txs
        .watchMonthTotals(2026, 3, kategoriId: kTransferAdminCategoryId)
        .first;
    expect(totals.expense, 2500);
  });

  test('jumlah total per kategori == total pengeluaran bulan (Bagian 14)', () async {
    await seed();
    final byCat = await txs.watchMonthExpenseByCategory(2026, 3).first;
    final totals = await txs.watchMonthTotals(2026, 3).first;
    // Kalau jumlahnya sama, persentase per kategori pasti berjumlah 100%.
    expect(byCat.fold<int>(0, (sum, c) => sum + c.total), totals.expense);
  });

  test('total per kategori (filter FR-4.3) cocok dengan Dart', () async {
    await seed();
    final own = await ownIds();
    final all = await txs.all();
    final dart = computeTotals(
      all.where((t) => t.kategoriId == 'makanan').toList(),
      own,
    );
    final sql = await txs
        .watchMonthTotals(2026, 3, kategoriId: 'makanan')
        .first;
    expect(sql.expense, dart.expense);
    expect(sql.expense, 25000);
  });

  test('seri 12 bulan (SQL) == monthlySeries (Dart)', () async {
    await seed();
    final own = await ownIds();
    final anchor = DateTime(2026, 4, 15);
    final sql = await txs
        .watchMonthlySeries(12, anchorYear: anchor.year, anchorMonth: anchor.month)
        .first;
    final dart = monthlySeries(await txs.all(), own, 12, anchor);

    expect(sql.length, 12);
    for (var i = 0; i < 12; i++) {
      expect(sql[i].month, dart[i].month);
      expect(sql[i].income, dart[i].income);
      expect(sql[i].expense, dart[i].expense);
    }
    expect(sql.last.expense, 7000); // April
    expect(sql[10].expense, 528500); // Maret
  });

  test('bulan tanpa transaksi tetap muncul sebagai titik nol', () async {
    await seed();
    final sql = await txs
        .watchMonthlySeries(3, anchorYear: 2026, anchorMonth: 4)
        .first;
    expect(sql.length, 3);
    expect(sql.first.month, DateTime(2026, 2, 1));
    expect(sql.first.income, 0);
    expect(sql.first.expense, 0);
  });
}
