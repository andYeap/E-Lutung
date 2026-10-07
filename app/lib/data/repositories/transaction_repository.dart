import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../finance.dart';
import '../merchant.dart';

String _monthKey(int year, int month) =>
    '$year-${month.toString().padLeft(2, '0')}';

/// Akses data Transaksi (Bagian 7.4). Filter dilakukan di SQL; rekap bulanan
/// (total, per kategori, seri 12 bulan) juga diagregasi di SQL lewat
/// `CaseWhenExpression` + `SUM`/`GROUP BY`. Aturan murninya ada di
/// `finance.dart` dan dijaga tetap setara oleh `test/sql_aggregate_test.dart`.
class TransactionRepository {
  TransactionRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Transaction>> watchFiltered({
    DateTime? from,
    DateTime? to,
    TxType? tipe,
    String? kategoriId,
    String? akunId,
    String? keyword,
  }) {
    final q = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNull());
    if (from != null) {
      q.where((t) => t.tanggal.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where((t) => t.tanggal.isSmallerOrEqualValue(to));
    }
    if (tipe != null) {
      q.where((t) => t.tipe.equals(tipe.name));
    }
    if (kategoriId != null) {
      q.where((t) => t.kategoriId.equals(kategoriId));
    }
    if (akunId != null) {
      q.where(
        (t) =>
            t.akunId.equals(akunId) |
            t.akunAsalId.equals(akunId) |
            t.akunTujuanId.equals(akunId),
      );
    }
    final kw = keyword?.trim().toLowerCase();
    if (kw != null && kw.isNotEmpty) {
      q.where((t) => t.catatan.lower().contains(kw));
    }
    q.orderBy([(t) => OrderingTerm(expression: t.tanggal, mode: OrderingMode.desc)]);
    return q.watch();
  }

  Future<List<Transaction>> all() =>
      (_db.select(_db.transactions)..where((t) => t.deletedAt.isNull())).get();

  // ---- Agregasi di SQL (Bagian 6 & 16 PRD) -------------------------------
  // Rekap bulanan dihitung basis data (SUM … GROUP BY), bukan fold di Dart.
  // Kedua ekspresi di bawah adalah padanan SQL dari `finance.incomeAmount` /
  // `expenseAmount`; kesetaraannya dijaga `test/sql_aggregate_test.dart`.

  /// Padanan SQL `finance.incomeAmount`.
  Expression<int> _incomeAmountExpr() {
    final t = _db.transactions;
    return CaseWhenExpression<int>(
      cases: [
        CaseWhen(t.tipe.equalsValue(TxType.pemasukan), then: t.nominal),
      ],
      orElse: const Constant(0),
    );
  }

  /// Padanan SQL `finance.expenseAmount` (aturan transfer Bagian 8.1).
  /// "Akun sendiri" = `accounts.milik_sendiri = 1` dan belum dihapus.
  Expression<int> _expenseAmountExpr() {
    final t = _db.transactions;
    final ownAccounts = _db.selectOnly(_db.accounts)
      ..addColumns([_db.accounts.id])
      ..where(
        _db.accounts.milikSendiri.equals(true) &
            _db.accounts.deletedAt.isNull(),
      );
    final isTransfer = t.tipe.equalsValue(TxType.transfer);
    final toOwnAccount = t.akunTujuanId.isInQuery(ownAccounts);
    return CaseWhenExpression<int>(
      cases: [
        CaseWhen(t.tipe.equalsValue(TxType.pengeluaran), then: t.nominal),
        CaseWhen(isTransfer & toOwnAccount, then: t.biayaAdmin),
        CaseWhen(isTransfer, then: t.nominal + t.biayaAdmin),
      ],
      orElse: const Constant(0),
    );
  }

  /// Padanan SQL `finance.expenseCategoryId` (Bagian 8.1): pengeluaran transfer
  /// antar akun sendiri dibukukan ke kategori "Transfer & Admin".
  Expression<String> _expenseCategoryExpr() {
    final t = _db.transactions;
    final ownAccounts = _db.selectOnly(_db.accounts)
      ..addColumns([_db.accounts.id])
      ..where(
        _db.accounts.milikSendiri.equals(true) &
            _db.accounts.deletedAt.isNull(),
      );
    final toOwnAccount = t.akunTujuanId.isInQuery(ownAccounts);
    return CaseWhenExpression<String>(
      cases: [
        CaseWhen(
          t.tipe.equalsValue(TxType.transfer) & toOwnAccount,
          then: const Constant<String>(kTransferAdminCategoryId),
        ),
      ],
      orElse: t.kategoriId,
    );
  }

  /// Baris pengeluaran mentah pada rentang `[from, to)` — dipakai bersama oleh
  /// query agregat di bawah.
  Expression<bool> _rangeFilter(DateTime from, DateTime to) {
    final t = _db.transactions;
    return t.deletedAt.isNull() &
        t.tanggal.isBiggerOrEqualValue(from) &
        t.tanggal.isSmallerThanValue(to);
  }

  /// FR-4.1 — total masuk & keluar satu bulan, dihitung di SQL.
  /// [kategoriId] membatasi ke satu kategori (FR-4.3).
  Stream<Totals> watchMonthTotals(
    int year,
    int month, {
    String? kategoriId,
  }) {
    final t = _db.transactions;
    final income = _incomeAmountExpr().sum();
    final expense = _expenseAmountExpr().sum();
    var predicate = _rangeFilter(DateTime(year, month, 1), DateTime(year, month + 1, 1));
    if (kategoriId != null) {
      // Filter memakai kategori pembukuan, bukan `transactions.kategori_id`,
      // supaya konsisten dengan tabel/grafik (mis. "Transfer & Admin").
      predicate = predicate & _expenseCategoryExpr().equals(kategoriId);
    }
    final q = _db.selectOnly(t)
      ..addColumns([income, expense])
      ..where(predicate);
    return q.watchSingle().map(
      (row) => Totals(row.read(income) ?? 0, row.read(expense) ?? 0),
    );
  }

  /// FR-4.2 & FR-5.1 — pengeluaran per kategori satu bulan (SQL `GROUP BY`).
  /// [kategoriId] membatasi ke satu kategori, agar tabel & grafik tetap
  /// konsisten dengan filter (FR-4.3/FR-5.5).
  Stream<List<CategoryTotal>> watchMonthExpenseByCategory(
    int year,
    int month, {
    String? kategoriId,
  }) {
    final t = _db.transactions;
    final total = _expenseAmountExpr().sum();
    final kategoriExpr = _expenseCategoryExpr();
    var predicate =
        _rangeFilter(DateTime(year, month, 1), DateTime(year, month + 1, 1));
    if (kategoriId != null) {
      predicate = predicate & kategoriExpr.equals(kategoriId);
    }
    final q = _db.selectOnly(t)
      ..addColumns([kategoriExpr, total])
      ..where(predicate)
      ..groupBy([kategoriExpr]);
    return q.watch().map((rows) {
      final list = <CategoryTotal>[];
      for (final row in rows) {
        final value = row.read(total) ?? 0;
        if (value == 0) continue;
        list.add(
          CategoryTotal(kategoriId: row.read(kategoriExpr), total: value),
        );
      }
      list.sort((a, b) => b.total.compareTo(a.total));
      return list;
    });
  }

  /// FR-4.4 — seri masuk/keluar per bulan untuk [months] bulan terakhir.
  /// Dikelompokkan di SQL menurut tahun & bulan **waktu lokal** perangkat
  /// (`modify(localTime())`), supaya transaksi dekat batas bulan tidak
  /// tergeser oleh konversi UTC.
  ///
  /// [kategoriId] membatasi ke satu kategori (memakai kategori pembukuan),
  /// agar grafik ikut filter seperti tabel & donut (FR-4.3/FR-5.5).
  Stream<List<MonthPoint>> watchMonthlySeries(
    int months, {
    required int anchorYear,
    required int anchorMonth,
    String? kategoriId,
  }) {
    final t = _db.transactions;
    final local = t.tanggal.modify(DateTimeModifier.localTime());
    final yearExpr = local.year;
    final monthExpr = local.month;
    final income = _incomeAmountExpr().sum();
    final expense = _expenseAmountExpr().sum();
    var predicate = _rangeFilter(
      DateTime(anchorYear, anchorMonth - (months - 1), 1),
      DateTime(anchorYear, anchorMonth + 1, 1),
    );
    if (kategoriId != null) {
      predicate = predicate & _expenseCategoryExpr().equals(kategoriId);
    }
    final q = _db.selectOnly(t)
      ..addColumns([yearExpr, monthExpr, income, expense])
      ..where(predicate)
      ..groupBy([yearExpr, monthExpr]);
    return q.watch().map((rows) {
      final byKey = <String, MonthPoint>{};
      for (final row in rows) {
        final y = row.read(yearExpr);
        final m = row.read(monthExpr);
        if (y == null || m == null) continue;
        byKey[_monthKey(y, m)] = MonthPoint(
          month: DateTime(y, m, 1),
          income: row.read(income) ?? 0,
          expense: row.read(expense) ?? 0,
        );
      }
      // Bulan tanpa transaksi tetap muncul sebagai titik nol.
      return [
        for (var i = months - 1; i >= 0; i--)
          () {
            final d = DateTime(anchorYear, anchorMonth - i, 1);
            return byKey[_monthKey(d.year, d.month)] ??
                MonthPoint(month: d, income: 0, expense: 0);
          }(),
      ];
    });
  }

  /// Transaksi yang punya foto struk tersimpan (untuk layar Foto struk di
  /// Pengaturan).
  ///
  /// Hanya transaksi aktif — struk transaksi yang sudah dihapus ikut dibuang
  /// berkasnya, jadi tidak ada yang perlu dilihat lagi. Berkas yang hilang
  /// (mis. setelah impor cadangan, karena gambar tidak ikut JSON) tetap
  /// dikembalikan; pemanggil yang memeriksa `File.existsSync`, supaya
  /// dashboard bisa membedakan "tidak ada struk" dari "struk hilang".
  Stream<List<Transaction>> watchWithReceipt() {
    final q = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNull() & t.strukPath.isNotNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.tanggal, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }

  /// Melepas foto struk dari satu transaksi **tanpa** menghapus transaksinya.
  ///
  /// Dipakai ketika berkasnya memang hilang, supaya `strukPath` tidak
  /// menunjuk ke file yang sudah tidak ada selamanya.
  Future<void> clearReceiptPath(String id) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        strukPath: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Melepas foto struk dari banyak transaksi sekaligus, untuk membersihkan
  /// seluruh path yang menunjuk ke berkas hilang.
  Future<void> clearReceiptPaths(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.update(_db.transactions)..where((t) => t.id.isIn(ids))).write(
      TransactionsCompanion(
        strukPath: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Transaksi terhapus (untuk layar Sampah, v1.1).
  Stream<List<Transaction>> watchDeleted() {
    final q = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
      ]);
    return q.watch();
  }

  /// Pulihkan transaksi dari Sampah.
  Future<void> restore(String id) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<String> create({
    required TxType tipe,
    required int nominal,
    required DateTime tanggal,
    String? kategoriId,
    String? akunId,
    String? catatan,
    String? akunAsalId,
    String? akunTujuanId,
    int biayaAdmin = 0,
    String? strukPath,
    String? debtId,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.transactions).insert(
      TransactionsCompanion.insert(
        id: id,
        tipe: tipe,
        nominal: nominal,
        tanggal: tanggal,
        kategoriId: Value(kategoriId),
        akunId: Value(akunId),
        catatan: Value(catatan),
        akunAsalId: Value(akunAsalId),
        akunTujuanId: Value(akunTujuanId),
        biayaAdmin: Value(biayaAdmin),
        strukPath: Value(strukPath),
        debtId: Value(debtId),
      ),
    );
    await _catatKebiasaan(
      tipe: tipe,
      catatan: catatan,
      kategoriId: kategoriId,
      akunId: akunId,
    );
    return id;
  }

  /// Catat/mutakhirkan kebiasaan pedagang → kategori & akun (v1.5).
  ///
  /// Dipanggil setiap transaksi pengeluaran disimpan, baik dari form biasa
  /// maupun dari scan. Tidak pernah menyimpan apa pun yang belum dipilih
  /// pengguna: tanpa keterangan atau tanpa kategori, tidak ada yang dicatat.
  ///
  /// Pilihan **terakhir** yang menang. Bila pemetaan berubah, hitungannya
  /// mulai lagi dari satu supaya angka "(Nx)" di layar berarti pemetaan yang
  /// sedang berlaku, bukan total transaksi pada pedagang itu.
  Future<void> _catatKebiasaan({
    required TxType tipe,
    required String? catatan,
    required String? kategoriId,
    required String? akunId,
  }) async {
    // Saran hanya muncul saat scan pengeluaran, jadi hanya itu yang berguna
    // dicatat — pemasukan tidak punya pedagang.
    if (tipe != TxType.pengeluaran) return;
    if (kategoriId == null) return;
    final pola = polaMerchant(catatan);
    if (pola == null) return;

    final lama = await (_db.select(_db.merchantHabits)
          ..where((h) => h.pola.equals(pola)))
        .getSingleOrNull();
    final sekarang = DateTime.now();
    if (lama == null) {
      await _db.into(_db.merchantHabits).insert(
        MerchantHabitsCompanion.insert(
          pola: pola,
          kategoriId: Value(kategoriId),
          akunId: Value(akunId),
          terakhirDipakai: Value(sekarang),
          jumlahPemakaian: const Value(1),
        ),
      );
      return;
    }
    final sama = lama.kategoriId == kategoriId && lama.akunId == akunId;
    await (_db.update(_db.merchantHabits)..where((h) => h.pola.equals(pola)))
        .write(
      MerchantHabitsCompanion(
        kategoriId: Value(kategoriId),
        akunId: Value(akunId),
        terakhirDipakai: Value(sekarang),
        jumlahPemakaian: Value(sama ? lama.jumlahPemakaian + 1 : 1),
      ),
    );
  }

  /// Kebiasaan pedagang untuk [catatan], atau null bila belum pernah dicatat.
  ///
  /// Dipakai layar scan untuk mengusulkan kategori & akun. Ini hanya saran:
  /// pemanggil tetap harus menampilkannya dan pengguna tetap harus menyimpan.
  Future<MerchantHabit?> cariKebiasaan(String? catatan) {
    final pola = polaMerchant(catatan);
    if (pola == null) return Future.value(null);
    return (_db.select(_db.merchantHabits)..where((h) => h.pola.equals(pola)))
        .getSingleOrNull();
  }

  Future<void> update({
    required String id,
    required TxType tipe,
    required int nominal,
    required DateTime tanggal,
    String? kategoriId,
    String? akunId,
    String? catatan,
    String? akunAsalId,
    String? akunTujuanId,
    int biayaAdmin = 0,
    String? strukPath,
    String? debtId,
  }) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        tipe: Value(tipe),
        nominal: Value(nominal),
        tanggal: Value(tanggal),
        kategoriId: Value(kategoriId),
        akunId: Value(akunId),
        catatan: Value(catatan),
        akunAsalId: Value(akunAsalId),
        akunTujuanId: Value(akunTujuanId),
        biayaAdmin: Value(biayaAdmin),
        // Diabaikan bila tidak diteruskan, supaya edit biasa tidak menghapus
        // tautan foto struk.
        strukPath: strukPath == null ? const Value.absent() : Value(strukPath),
        // Sama seperti foto: tautan ke catatan utang tidak dilepas oleh edit
        // biasa, karena tidak ada antarmuka untuk memasangnya kembali.
        debtId: debtId == null ? const Value.absent() : Value(debtId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) {
    final now = DateTime.now();
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
