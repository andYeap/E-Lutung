import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/account_repository.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// NFR Bagian 10 PRD: "query rekap bulanan < 100 ms" pada dataset normal
/// (≤ 10.000 transaksi). Diukur pada basis data in-memory berisi 10.000 baris.
void main() {
  test('rekap bulanan pada 10.000 transaksi < 100 ms', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final txs = TransactionRepository(db);
    final accounts = AccountRepository(db);

    final own = await accounts.create(
      institusiId: 'tunai',
      milikSendiri: true,
      saldoAwal: 0,
    );

    const kategori = ['makanan', 'transport', 'belanja', 'gaji'];
    const total = 10000;
    await db.batch((b) {
      for (var i = 0; i < total; i++) {
        b.insert(
          db.transactions,
          TransactionsCompanion.insert(
            id: 'tx$i',
            tipe: i % 4 == 0 ? TxType.pemasukan : TxType.pengeluaran,
            nominal: 1000 + (i % 500),
            tanggal: DateTime(2026, (i % 12) + 1, (i % 28) + 1, i % 24),
            kategoriId: Value(kategori[i % kategori.length]),
            akunId: Value(own),
          ),
        );
      }
    });
    expect((await txs.all()).length, total);

    // Panaskan cache halaman SQLite untuk ketiga query sebelum pengukuran.
    await txs.watchMonthTotals(2026, 12).first;
    await txs.watchMonthExpenseByCategory(2026, 12).first;
    await txs.watchMonthlySeries(12, anchorYear: 2026, anchorMonth: 12).first;

    Future<int> ms(Future<void> Function() run) async {
      final sw = Stopwatch()..start();
      await run();
      return sw.elapsedMilliseconds;
    }

    final totalsMs = await ms(() => txs.watchMonthTotals(2026, 12).first);
    final byCatMs =
        await ms(() => txs.watchMonthExpenseByCategory(2026, 12).first);
    final seriesMs = await ms(
      () => txs.watchMonthlySeries(12, anchorYear: 2026, anchorMonth: 12).first,
    );

    final totals = await txs.watchMonthTotals(2026, 12).first;
    final byCat = await txs.watchMonthExpenseByCategory(2026, 12).first;
    final series = await txs
        .watchMonthlySeries(12, anchorYear: 2026, anchorMonth: 12)
        .first;

    // ignore: avoid_print
    print(
      '[NFR] rekap 10.000 transaksi — total $totalsMs ms, '
      'per-kategori $byCatMs ms, seri 12 bulan $seriesMs ms '
      '(masuk=${totals.income}, keluar=${totals.expense}, '
      'kategori=${byCat.length}, titik=${series.length})',
    );
    // Setiap query rekap harus di bawah target PRD 100 ms.
    expect(totalsMs, lessThan(100));
    expect(byCatMs, lessThan(100));
    expect(seriesMs, lessThan(100));

    await db.close();
  });
}
