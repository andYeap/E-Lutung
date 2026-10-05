import 'package:drift/native.dart';
import 'package:elutung/data/backup.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/recurring_repository.dart';
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

  test('aturan berulang ikut terekspor dan terpulihkan', () async {
    final rules = RecurringRepository(db);
    final id = await rules.create(
      tipe: TxType.pengeluaran,
      nominal: 99000,
      kategoriId: 'hiburan',
      frekuensi: Frequency.bulanan,
      mulai: DateTime(2026, 5, 1),
    );

    final dump = await backup.dump();
    await db.delete(db.recurringRules).go();
    expect((await db.select(db.recurringRules).get()), isEmpty);

    await backup.restore(dump, replace: true);

    final restored = await db.select(db.recurringRules).get();
    expect(restored.length, 1);
    expect(restored.single.id, id);
    expect(restored.single.nominal, 99000);
    expect(restored.single.frekuensi, Frequency.bulanan);
    expect(restored.single.mulai, DateTime(2026, 5, 1));
  });

  test('impor mode gabung tidak menggandakan id yang sama', () async {
    final txRepo = TransactionRepository(db);
    await txRepo.create(
      tipe: TxType.pengeluaran,
      nominal: 12345,
      tanggal: DateTime(2026, 4, 9),
      kategoriId: 'makanan',
    );

    final dump = await backup.dump();
    await backup.restore(dump, replace: true);
    final count1 = (await db.select(db.transactions).get()).length;
    await backup.restore(dump, replace: false);
    final count2 = (await db.select(db.transactions).get()).length;
    expect(count2, count1);
    expect(count2, greaterThan(0));
  });

  test('impor menolak berkas yang bukan cadangan E-Lutung', () async {
    final txRepo = TransactionRepository(db);
    await txRepo.create(
      tipe: TxType.pengeluaran,
      nominal: 5000,
      tanggal: DateTime(2026, 4, 1),
      kategoriId: 'makanan',
    );

    // Map asing tanpa 'version' ditolak, dan mode ganti tidak menghapus data.
    final n = await backup.restore({'foo': 'bar'}, replace: true);
    expect(n, 0);
    expect((await db.select(db.transactions).get()).length, 1);
  });

  test('cadangan terenkripsi bisa dibuka dengan kata sandi benar', () async {
    final payload = await backup.dump();
    final envelope = await encryptBackup(payload, 'rahasia123');

    expect(isEncryptedBackup(envelope), isTrue);
    // Amplop tidak memuat data asli secara terbaca.
    expect(envelope.containsKey('transactions'), isFalse);

    final hasil = await decryptBackup(envelope, 'rahasia123');
    expect(hasil['version'], payload['version']);
    expect(hasil['categories'], isNotNull);
  });

  test('kata sandi salah gagal membuka cadangan', () async {
    final envelope = await encryptBackup(await backup.dump(), 'benar');
    await expectLater(decryptBackup(envelope, 'salah'), throwsA(anything));
  });
}
