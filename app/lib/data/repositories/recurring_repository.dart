import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

/// Akses data aturan transaksi berulang (Bagian 7.6). Hapus = soft delete.
class RecurringRepository {
  RecurringRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<RecurringRule>> watchAll() {
    final q = _db.select(_db.recurringRules)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.mulai, mode: OrderingMode.desc)]);
    return q.watch();
  }

  /// Aturan yang boleh menghasilkan transaksi: belum dihapus dan aktif.
  Future<List<RecurringRule>> activeRules() =>
      (_db.select(_db.recurringRules)
            ..where((t) => t.deletedAt.isNull() & t.aktif.equals(true)))
          .get();

  Future<String> create({
    required TxType tipe,
    required int nominal,
    String? kategoriId,
    String? akunId,
    String? catatan,
    required Frequency frekuensi,
    required DateTime mulai,
    DateTime? sampai,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.recurringRules).insert(
      RecurringRulesCompanion.insert(
        id: id,
        tipe: tipe,
        nominal: nominal,
        kategoriId: Value(kategoriId),
        akunId: Value(akunId),
        catatan: Value(catatan),
        frekuensi: frekuensi,
        mulai: mulai,
        sampai: Value(sampai),
      ),
    );
    return id;
  }

  Future<void> update({
    required String id,
    required TxType tipe,
    required int nominal,
    String? kategoriId,
    String? akunId,
    String? catatan,
    required Frequency frekuensi,
    required DateTime mulai,
    DateTime? sampai,
    required bool aktif,
  }) {
    return (_db.update(_db.recurringRules)..where((t) => t.id.equals(id))).write(
      RecurringRulesCompanion(
        tipe: Value(tipe),
        nominal: Value(nominal),
        kategoriId: Value(kategoriId),
        akunId: Value(akunId),
        catatan: Value(catatan),
        frekuensi: Value(frekuensi),
        mulai: Value(mulai),
        sampai: Value(sampai),
        aktif: Value(aktif),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setActive(String id, bool aktif) {
    return (_db.update(_db.recurringRules)..where((t) => t.id.equals(id))).write(
      RecurringRulesCompanion(
        aktif: Value(aktif),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Catat jatuh tempo terakhir yang sudah dibuatkan transaksi.
  Future<void> markGenerated(String id, DateTime terakhir) {
    return (_db.update(_db.recurringRules)..where((t) => t.id.equals(id))).write(
      RecurringRulesCompanion(
        terakhirDibuat: Value(terakhir),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) {
    final now = DateTime.now();
    return (_db.update(_db.recurringRules)..where((t) => t.id.equals(id))).write(
      RecurringRulesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Aturan terhapus (layar Sampah).
  Stream<List<RecurringRule>> watchDeleted() {
    final q = _db.select(_db.recurringRules)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }

  Future<void> restore(String id) {
    return (_db.update(_db.recurringRules)..where((t) => t.id.equals(id))).write(
      RecurringRulesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
