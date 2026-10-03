import 'package:drift/native.dart';
import 'package:elutung/data/backup.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late BackupService backup;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    backup = BackupService(db);
  });
  tearDown(() => db.close());

  test('ekspor -> hapus -> impor (ganti) menghasilkan data sama', () async {
    final txRepo = TransactionRepository(db);
    await txRepo.create(
      tipe: TxType.pengeluaran,
      nominal: 25000,
      tanggal: DateTime(2026, 3, 5),
      kategoriId: 'makanan',
    );
    await txRepo.create(
      tipe: TxType.transfer,
      nominal: 100000,
      tanggal: DateTime(2026, 3, 6),
      akunAsalId: 'x',
      akunTujuanId: 'y',
      biayaAdmin: 2500,
    );

    final dump = await backup.dump();
    final before = await db.select(db.transactions).get();
    expect(before.length, 2);

    // Kosongkan lalu restore mode ganti
    await db.delete(db.transactions).go();
    expect((await db.select(db.transactions).get()), isEmpty);

    final restored = await backup.restore(dump, replace: true);
    expect(restored, greaterThanOrEqualTo(2));

    final after = await db.select(db.transactions).get();
    expect(after.length, 2);
    final total = after.fold<int>(0, (a, t) => a + t.nominal);
    expect(total, 125000);
  });

  test('impor mode gabung tidak menggandakan id yang sama', () async {
    final dump = await backup.dump();
    await backup.restore(dump, replace: true);
    final count1 = (await db.select(db.transactions).get()).length;
    await backup.restore(dump, replace: false);
    final count2 = (await db.select(db.transactions).get()).length;
    expect(count2, count1);
  });
}
