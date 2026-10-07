import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/debt_repository.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Catatan utang/piutang: hanya pokoknya yang disimpan, sedangkan pelunasan
/// dibaca dari transaksi yang tertaut supaya tidak ada uang yang dicatat dua
/// kali dan ikut terhitung di saldo serta riwayat.
void main() {
  late AppDatabase db;
  late DebtRepository debts;
  late TransactionRepository transactions;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    debts = DebtRepository(db);
    transactions = TransactionRepository(db);
  });
  tearDown(() => db.close());

  Future<String> catat({
    DebtDirection arah = DebtDirection.utang,
    int nominal = 500000,
  }) => debts.create(arah: arah, pihak: 'Budi', nominal: nominal);

  Future<void> bayar(String debtId, int nominal) => transactions.create(
    tipe: TxType.pengeluaran,
    nominal: nominal,
    tanggal: DateTime(2026, 3, 5),
    kategoriId: 'lain2',
    debtId: debtId,
  );

  test('catatan baru belum terbayar', () async {
    await catat();
    final d = (await debts.watchAll().first).single;

    expect(d.terbayar, 0);
    expect(d.sisa, 500000);
    expect(d.lunas, isFalse);
    expect(d.fraksi, 0);
  });

  test('transaksi tertaut menambah jumlah terbayar', () async {
    final id = await catat();
    await bayar(id, 200000);

    final d = (await debts.watchAll().first).single;
    expect(d.terbayar, 200000);
    expect(d.sisa, 300000);
    expect(d.fraksi, closeTo(0.4, 1e-9));
  });

  test('transaksi yang tidak tertaut tidak ikut terhitung', () async {
    await catat();
    await transactions.create(
      tipe: TxType.pengeluaran,
      nominal: 200000,
      tanggal: DateTime(2026, 3, 5),
      kategoriId: 'lain2',
    );

    expect((await debts.watchAll().first).single.terbayar, 0);
  });

  test('yang sudah lunas turun ke bawah daftar', () async {
    final lunas = await catat(nominal: 100000);
    final belum = await catat(nominal: 200000);
    await bayar(lunas, 100000);
    await bayar(belum, 50000);

    final list = await debts.watchAll().first;
    expect(list.first.debt.id, belum);
    expect(list.first.lunas, isFalse);
    expect(list.last.debt.id, lunas);
    expect(list.last.lunas, isTrue);
  });

  test('hapus lunak menyembunyikan catatan, transaksinya tetap', () async {
    final id = await catat();
    await bayar(id, 200000);

    await debts.softDelete(id);

    expect(await debts.watchAll().first, isEmpty);
    expect((await db.select(db.transactions).get()).length, 1);
  });

  test('piutang dibayar dengan pemasukan, utang dengan pengeluaran', () async {
    await catat(arah: DebtDirection.piutang);
    expect((await debts.watchAll().first).single.tipeBayar, TxType.pemasukan);

    await db.delete(db.debts).go();
    await catat(arah: DebtDirection.utang);
    expect((await debts.watchAll().first).single.tipeBayar, TxType.pengeluaran);
  });
}
