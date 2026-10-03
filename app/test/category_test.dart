import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/category_repository.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository categories;
  late TransactionRepository transactions;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    categories = CategoryRepository(db);
    transactions = TransactionRepository(db);
  });
  tearDown(() => db.close());

  test('usedByTransactions menghitung transaksi aktif pemakai kategori', () async {
    final id = await categories.create(nama: 'Kategori Uji');
    expect(await categories.usedByTransactions(id), 0);

    final txId = await transactions.create(
      tipe: TxType.pengeluaran,
      nominal: 10000,
      tanggal: DateTime(2026, 4, 1),
      kategoriId: id,
    );
    expect(await categories.usedByTransactions(id), 1);

    // Transaksi yang dihapus tidak lagi menghalangi penghapusan kategori.
    await transactions.softDelete(txId);
    expect(await categories.usedByTransactions(id), 0);
  });

  test('kategori terhapus hilang dari watchAll tapi tetap terbaca labelnya', () async {
    final id = await categories.create(nama: 'Kategori Historis', warna: '#D98C7A');
    await transactions.create(
      tipe: TxType.pengeluaran,
      nominal: 15000,
      tanggal: DateTime(2026, 4, 2),
      kategoriId: id,
    );

    await categories.softDelete(id);

    final active = await categories.watchAll().first;
    expect(active.any((c) => c.id == id), isFalse);

    // Lookup historis tetap menemukan nama & warna aslinya.
    final all = await categories.watchAllIncludingDeleted().first;
    final found = all.firstWhere((c) => c.id == id);
    expect(found.nama, 'Kategori Historis');
    expect(found.warna, '#D98C7A');
  });
}
