import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

/// Akun dipasangkan dengan institusinya untuk ditampilkan (Bagian 7.3).
class AccountWithInstitution {
  AccountWithInstitution({required this.account, required this.institusi});
  final Account account;
  final Institution institusi;
}

/// Label tampilan satu akun: nama institusinya, ditambah nomor urut bila
/// institusi yang sama punya lebih dari satu akun.
///
/// Akun memang tidak punya nama sendiri (PRD FR-7.2: namanya diambil dari
/// institusi), jadi tanpa nomor urut dua akun di bank yang sama tampil identik
/// dan pengguna bisa membaca saldo atau memilih akun yang keliru.
///
/// [semua] harus daftar akun yang lengkap, bukan yang sudah disaring: kalau
/// daftarnya berbeda-beda, nomor urutnya ikut berbeda antar layar. Urutan
/// nomornya berdasarkan waktu dibuat lalu id, supaya tetap stabil.
String akunLabel(List<AccountWithInstitution> semua, String akunId) {
  AccountWithInstitution? target;
  for (final a in semua) {
    if (a.account.id == akunId) target = a;
  }
  if (target == null) return '?';

  final nama = target.institusi.nama;
  final serupa = semua.where((a) => a.institusi.nama == nama).toList()
    ..sort((a, b) {
      final urut = a.account.createdAt.compareTo(b.account.createdAt);
      return urut != 0 ? urut : a.account.id.compareTo(b.account.id);
    });
  if (serupa.length <= 1) return nama;

  final nomor = serupa.indexWhere((a) => a.account.id == akunId) + 1;
  return '$nama ($nomor)';
}

/// Peta id akun ke label tampilannya, siap dipakai daftar maupun pemilih.
Map<String, String> akunLabels(List<AccountWithInstitution> semua) => {
  for (final a in semua) a.account.id: akunLabel(semua, a.account.id),
};

/// Akses data Akun (Bagian 7.3). Nama diambil dari institusi; label tampilan
/// dibentuk [akunLabel] supaya akun sejenis tetap bisa dibedakan.
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
