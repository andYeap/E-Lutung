import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../finance.dart';

/// Kategori (Bagian 7.2) — CRUD; hapus = arsip.
class CategoryRepository {
  CategoryRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Category>> watchAll() {
    final q = _db.select(_db.categories)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.nama)]);
    return q.watch();
  }

  /// Semua kategori termasuk yang terhapus — dipakai hanya untuk menerjemahkan
  /// `kategoriId` lama menjadi nama & warna di riwayat/rekap/grafik, supaya
  /// transaksi historis tidak kehilangan labelnya setelah kategorinya dihapus.
  Stream<List<Category>> watchAllIncludingDeleted() {
    final q = _db.select(_db.categories)
      ..orderBy([(t) => OrderingTerm(expression: t.nama)]);
    return q.watch();
  }

  /// Berapa transaksi yang masih memakai kategori ini (cegah hapus).
  ///
  /// Transfer antar akun sendiri **dibukukan** ke kategori "Transfer & Admin"
  /// (Bagian 8.1) walau `transactions.kategori_id`-nya kategori lain, jadi
  /// kategori itu ikut dihitung saat menilai `transfer_admin`.
  Future<int> usedByTransactions(String id) async {
    final c = _db.transactions.id.count();
    final t = _db.transactions;
    var cond = t.kategoriId.equals(id);
    if (id == kTransferAdminCategoryId) {
      final ownAccounts = _db.selectOnly(_db.accounts)
        ..addColumns([_db.accounts.id])
        ..where(_db.accounts.milikSendiri.equals(true));
      cond =
          cond |
          (t.tipe.equalsValue(TxType.transfer) &
              t.akunTujuanId.isInQuery(ownAccounts));
    }
    final q = _db.selectOnly(t)
      ..addColumns([c])
      ..where(cond & t.deletedAt.isNull());
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  Future<String> create({required String nama, String? ikon, String? warna}) async {
    final id = _uuid.v4();
    await _db.into(_db.categories).insert(
      CategoriesCompanion.insert(
        id: id,
        nama: nama.trim(),
        ikon: Value(ikon),
        warna: Value(warna),
      ),
    );
    return id;
  }

  Future<void> update({
    required String id,
    required String nama,
    String? ikon,
    String? warna,
  }) {
    return (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        nama: Value(nama.trim()),
        ikon: Value(ikon),
        warna: Value(warna),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Category terhapus (layar Sampah).
  Stream<List<Category>> watchDeleted() {
    final q = _db.select(_db.categories)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }

  /// Pulihkan Category dari Sampah.
  Future<void> restore(String id) {
    return (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hapus kategori ke Sampah (bukan permanen).
  Future<void> softDelete(String id) {
    final now = DateTime.now();
    return (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

}
