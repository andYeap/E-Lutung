import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

/// Akun dipasangkan dengan institusinya untuk ditampilkan (Bagian 7.3).
class AccountWithInstitution {
  AccountWithInstitution({required this.account, required this.institusi});
  final Account account;
  final Institution institusi;
}

/// Akses data Akun (Bagian 7.3). Nama diambil dari institusi; tanpa label.
class AccountRepository {
  AccountRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<AccountWithInstitution>> watchAll() {
    final q = _db.select(_db.accounts).join([
      innerJoin(
        _db.institutions,
        _db.institutions.id.equalsExp(_db.accounts.institusiId),
      ),
    ])..where(_db.accounts.deletedAt.isNull());
    return q.watch().map(
      (rows) => rows
          .map(
            (r) => AccountWithInstitution(
              account: r.readTable(_db.accounts),
              institusi: r.readTable(_db.institutions),
            ),
          )
          .toList(),
    );
  }

  Future<String> create({
    required String institusiId,
    required bool milikSendiri,
    required int saldoAwal,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.accounts).insert(
      AccountsCompanion.insert(
        id: id,
        institusiId: institusiId,
        milikSendiri: Value(milikSendiri),
        saldoAwal: Value(saldoAwal),
      ),
    );
    return id;
  }

  Future<void> update({
    required String id,
    required String institusiId,
    required bool milikSendiri,
    required int saldoAwal,
    required bool aktif,
  }) {
    return (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(
        institusiId: Value(institusiId),
        milikSendiri: Value(milikSendiri),
        saldoAwal: Value(saldoAwal),
        aktif: Value(aktif),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) {
    final now = DateTime.now();
    return (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Account terhapus (layar Sampah).
  Stream<List<Account>> watchDeleted() {
    final q = _db.select(_db.accounts)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }

  /// Pulihkan Account dari Sampah.
  Future<void> restore(String id) {
    return (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(deletedAt: const Value(null), updatedAt: Value(DateTime.now())),
    );
  }

}
