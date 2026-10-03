import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

/// Anggaran (Bagian 7.5) — rentang tanggal eksplisit, sekali pakai.
class BudgetRepository {
  BudgetRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Budget>> watchAll() {
    final q = _db.select(_db.budgets)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.periodeMulai, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<String> create({
    required BudgetScope lingkup,
    String? kategoriId,
    required DateTime periodeMulai,
    required DateTime periodeSelesai,
    required int nominal,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.budgets).insert(
      BudgetsCompanion.insert(
        id: id,
        lingkup: lingkup,
        kategoriId: Value(lingkup == BudgetScope.kategori ? kategoriId : null),
        periodeMulai: periodeMulai,
        periodeSelesai: periodeSelesai,
        nominal: nominal,
      ),
    );
    return id;
  }

  Future<void> update({
    required String id,
    required BudgetScope lingkup,
    String? kategoriId,
    required DateTime periodeMulai,
    required DateTime periodeSelesai,
    required int nominal,
    required bool aktif,
  }) {
    return (_db.update(_db.budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(
        lingkup: Value(lingkup),
        kategoriId: Value(lingkup == BudgetScope.kategori ? kategoriId : null),
        periodeMulai: Value(periodeMulai),
        periodeSelesai: Value(periodeSelesai),
        nominal: Value(nominal),
        aktif: Value(aktif),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) {
    final now = DateTime.now();
    return (_db.update(_db.budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Budget terhapus (layar Sampah).
  Stream<List<Budget>> watchDeleted() {
    final q = _db.select(_db.budgets)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }

  /// Pulihkan Budget dari Sampah.
  Future<void> restore(String id) {
    return (_db.update(_db.budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(deletedAt: const Value(null), updatedAt: Value(DateTime.now())),
    );
  }

}
