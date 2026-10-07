import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

/// Satu catatan utang/piutang beserta jumlah yang sudah dibayar.
///
/// Jumlah terbayar **tidak** disimpan di tabel: ia dijumlahkan dari transaksi
/// yang menunjuk ke catatan ini. Dengan begitu uangnya cuma punya satu catatan,
/// ikut terhitung di saldo, riwayat, dan rekap seperti transaksi lain, dan tidak
/// ada angka yang perlu dijaga di dua tempat.
class DebtWithPaid {
  DebtWithPaid({required this.debt, required this.terbayar});

  final Debt debt;
  final int terbayar;

  int get sisa => debt.nominal - terbayar;
  bool get lunas => sisa <= 0;

  /// Bagian yang sudah dibayar, 0..1.
  double get fraksi => debt.nominal <= 0
      ? 0
      : (terbayar / debt.nominal).clamp(0, 1).toDouble();

  /// Arah pembayaran: utang dibayar dengan pengeluaran, piutang dengan pemasukan.
  TxType get tipeBayar => debt.arah == DebtDirection.utang
      ? TxType.pengeluaran
      : TxType.pemasukan;
}

/// Akses data catatan utang/piutang (Bagian 7.7 PRD, v1.4).
class DebtRepository {
  DebtRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Semua catatan: yang belum lunas lebih dulu, lalu tenggat terdekat, lalu
  /// yang terbaru. Yang sudah lunas tetap tampil di bawah supaya bisa dilihat
  /// kembali, dan bisa dihapus sendiri oleh pengguna.
  Stream<List<DebtWithPaid>> watchAll() {
    return _db
        .customSelect(
          '''
SELECT d.*, COALESCE(SUM(t.nominal), 0) AS terbayar
FROM debts d
LEFT JOIN transactions t ON t.debt_id = d.id AND t.deleted_at IS NULL
WHERE d.deleted_at IS NULL
GROUP BY d.id
ORDER BY (COALESCE(SUM(t.nominal), 0) >= d.nominal) ASC,
         (d.tenggat IS NULL) ASC,
         d.tenggat ASC,
         d.created_at DESC
''',
          readsFrom: {_db.debts, _db.transactions},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (r) => DebtWithPaid(
                  debt: _db.debts.map(r.data),
                  terbayar: r.read<int>('terbayar'),
                ),
              )
              .toList(),
        );
  }

  Future<String> create({
    required DebtDirection arah,
    required String pihak,
    required int nominal,
    DateTime? tenggat,
    String? catatan,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.debts).insert(
      DebtsCompanion.insert(
        id: id,
        arah: arah,
        pihak: pihak.trim(),
        nominal: nominal,
        tenggat: Value(tenggat),
        catatan: Value(_bersih(catatan)),
      ),
    );
    return id;
  }

  Future<void> update({
    required String id,
    required DebtDirection arah,
    required String pihak,
    required int nominal,
    DateTime? tenggat,
    String? catatan,
  }) => (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
    DebtsCompanion(
      arah: Value(arah),
      pihak: Value(pihak.trim()),
      nominal: Value(nominal),
      tenggat: Value(tenggat),
      catatan: Value(_bersih(catatan)),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Hapus lunak, mengikuti aturan aplikasi. Transaksi pelunasan yang sudah
  /// tertaut dibiarkan: uangnya memang benar-benar berpindah.
  Future<void> softDelete(String id) =>
      (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
        DebtsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  static String? _bersih(String? teks) {
    final s = teks?.trim() ?? '';
    return s.isEmpty ? null : s;
  }
}
