import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

/// Akses data Institusi (Bagian 7.1). Hapus = soft delete.
class InstitutionRepository {
  InstitutionRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Institution>> watchAll() {
    final q = _db.select(_db.institutions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.nama)]);
    return q.watch();
  }

  Future<String> create({required String nama, required InstitutionType tipe}) async {
    final id = _uuid.v4();
    await _db.into(_db.institutions).insert(
      InstitutionsCompanion.insert(id: id, nama: nama.trim(), tipe: tipe),
    );
    return id;
  }

  Future<void> update({
    required String id,
    required String nama,
    required InstitutionType tipe,
    required bool aktif,
  }) {
    return (_db.update(_db.institutions)..where((t) => t.id.equals(id))).write(
      InstitutionsCompanion(
        nama: Value(nama.trim()),
        tipe: Value(tipe),
        aktif: Value(aktif),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) {
    final now = DateTime.now();
    return (_db.update(_db.institutions)..where((t) => t.id.equals(id))).write(
      InstitutionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Berapa akun aktif yang memakai institusi ini (cegah hapus).
  Future<int> usedByAccounts(String id) async {
    final c = _db.accounts.id.count();
    final q = _db.selectOnly(_db.accounts)
      ..addColumns([c])
      ..where(_db.accounts.institusiId.equals(id) & _db.accounts.deletedAt.isNull());
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  /// Institution terhapus (layar Sampah).
  Stream<List<Institution>> watchDeleted() {
    final q = _db.select(_db.institutions)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }

  /// Pulihkan Institution dari Sampah.
  Future<void> restore(String id) {
    return (_db.update(_db.institutions)..where((t) => t.id.equals(id))).write(
      InstitutionsCompanion(deletedAt: const Value(null), updatedAt: Value(DateTime.now())),
    );
  }

}
