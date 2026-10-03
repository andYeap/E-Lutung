import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/category_repository.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late CategoryRepository catRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TransactionRepository(db);
    catRepo = CategoryRepository(db);
  });
  tearDown(() => db.close());

  test('hapus -> masuk Sampah -> pulihkan kembali', () async {
    final id = await repo.create(
      tipe: TxType.pengeluaran,
      nominal: 15000,
      tanggal: DateTime(2026, 2, 10),
      kategoriId: 'makanan',
    );

    // Terlihat di daftar normal.
    expect((await repo.watchFiltered().first).any((t) => t.id == id), isTrue);
    expect((await repo.watchDeleted().first).any((t) => t.id == id), isFalse);

    await repo.softDelete(id);

    // Hilang dari daftar normal, muncul di Sampah.
    expect((await repo.watchFiltered().first).any((t) => t.id == id), isFalse);
    expect((await repo.watchDeleted().first).any((t) => t.id == id), isTrue);

    await repo.restore(id);

    // Kembali ke daftar normal.
    expect((await repo.watchFiltered().first).any((t) => t.id == id), isTrue);
    expect((await repo.watchDeleted().first).any((t) => t.id == id), isFalse);
  });

  test('kategori dihapus masuk Sampah dan bisa dipulihkan', () async {
    final id = await catRepo.create(nama: 'Kategori Uji', warna: '#D98C7A');

    expect((await catRepo.watchAll().first).any((c) => c.id == id), isTrue);

    await catRepo.softDelete(id);
    expect((await catRepo.watchAll().first).any((c) => c.id == id), isFalse);
    expect((await catRepo.watchDeleted().first).any((c) => c.id == id), isTrue);

    await catRepo.restore(id);
    expect((await catRepo.watchAll().first).any((c) => c.id == id), isTrue);
    expect((await catRepo.watchDeleted().first).any((c) => c.id == id), isFalse);
  });
}
