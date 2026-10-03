import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/recurring_repository.dart';
import 'package:elutung/services/recurring_runner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pembangkitan otomatis transaksi berulang (Bagian FR-12).
void main() {
  late AppDatabase db;
  late RecurringRepository rules;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    rules = RecurringRepository(db);
  });
  tearDown(() => db.close());

  Future<List<Transaction>> txs() => db.select(db.transactions).get();

  test('membangkitkan yang jatuh tempo lalu memajukan terakhirDibuat', () async {
    final id = await rules.create(
      tipe: TxType.pengeluaran,
      nominal: 25000,
      kategoriId: 'makanan',
      frekuensi: Frequency.bulanan,
      mulai: DateTime(2026, 1, 5),
    );

    final created = await RecurringRunner.runDue(db, now: DateTime(2026, 3, 20));

    expect(created, 3); // 5 Jan, 5 Feb, 5 Mar
    final rows = await txs();
    expect(rows.length, 3);
    expect(rows.every((t) => t.recurringRuleId == id), isTrue);
    expect(rows.every((t) => t.kategoriId == 'makanan'), isTrue);
    expect(rows.map((t) => t.tanggal), [
      DateTime(2026, 1, 5),
      DateTime(2026, 2, 5),
      DateTime(2026, 3, 5),
    ]);

    final rule = await db.select(db.recurringRules).getSingle();
    expect(rule.terakhirDibuat, DateTime(2026, 3, 5));
  });

  test('jalan kedua tidak menggandakan (idempotent)', () async {
    await rules.create(
      tipe: TxType.pemasukan,
      nominal: 5000000,
      kategoriId: 'gaji',
      frekuensi: Frequency.bulanan,
      mulai: DateTime(2026, 1, 25),
    );

    await RecurringRunner.runDue(db, now: DateTime(2026, 3, 31));
    final again = await RecurringRunner.runDue(db, now: DateTime(2026, 3, 31));

    expect(again, 0);
    expect((await txs()).length, 3); // 25 Jan, 25 Feb, 25 Mar
  });

  test('tidak ada transaksi ganda walau benar-benar dijalankan bersamaan', () async {
    await rules.create(
      tipe: TxType.pengeluaran,
      nominal: 10000,
      kategoriId: 'transport',
      frekuensi: Frequency.bulanan,
      mulai: DateTime(2026, 1, 5),
    );

    // Dua "pelari" bersamaan, meniru aplikasi dan WorkManager.
    final results = await Future.wait([
      RecurringRunner.runDue(db, now: DateTime(2026, 2, 20)),
      RecurringRunner.runDue(db, now: DateTime(2026, 2, 20)),
    ]);

    // Berapa pun yang masing-masing laporkan, invariannya satu: tidak boleh
    // ada periode yang tercatat dua kali, dan tidak boleh ada yang hilang.
    expect(results.reduce((a, b) => a + b), inInclusiveRange(2, 4));
    final rows = await txs();
    expect(rows.length, 2);
    expect(rows.map((t) => t.tanggal).toSet().length, 2);
  });

  test('aturan nonaktif dan yang sudah lewat tanggal selesai dilewati', () async {
    final nonaktif = await rules.create(
      tipe: TxType.pengeluaran,
      nominal: 10000,
      kategoriId: 'hiburan',
      frekuensi: Frequency.bulanan,
      mulai: DateTime(2026, 1, 1),
    );
    await rules.setActive(nonaktif, false);

    await rules.create(
      tipe: TxType.pengeluaran,
      nominal: 10000,
      kategoriId: 'hiburan',
      frekuensi: Frequency.bulanan,
      mulai: DateTime(2026, 1, 1),
      sampai: DateTime(2026, 2, 1),
    );

    final created = await RecurringRunner.runDue(db, now: DateTime(2026, 6, 30));

    expect(created, 2); // 1 Jan dan 1 Feb saja
    expect((await txs()).length, 2);
  });

  test('aturan terhapus tidak membangkitkan transaksi', () async {
    final id = await rules.create(
      tipe: TxType.pengeluaran,
      nominal: 10000,
      kategoriId: 'belanja',
      frekuensi: Frequency.harian,
      mulai: DateTime(2026, 1, 1),
    );
    await rules.softDelete(id);

    expect(await RecurringRunner.runDue(db, now: DateTime(2026, 3, 1)), 0);
    expect((await txs()), isEmpty);
  });

  test('dibatasi per jalan, lalu dilanjutkan jalan berikutnya', () async {
    await rules.create(
      tipe: TxType.pengeluaran,
      nominal: 1000,
      kategoriId: 'makanan',
      frekuensi: Frequency.harian,
      mulai: DateTime(2026, 1, 1),
    );

    final first = await RecurringRunner.runDue(db, now: DateTime(2026, 12, 31));
    expect(first, RecurringRunner.maxPerRulePerRun);

    final second = await RecurringRunner.runDue(db, now: DateTime(2026, 12, 31));
    expect(second, RecurringRunner.maxPerRulePerRun);

    // Tidak ada yang hilang maupun ganda: 365 kemunculan dalam setahun.
    final all = await txs();
    expect(all.length, 200);
    expect(all.map((t) => t.tanggal).toSet().length, 200);
    expect(all.first.tanggal, DateTime(2026, 1, 1));
  });
}
