import 'database.dart';

/// Aturan perlakuan transfer (Bagian 8.1 PRD).
///
/// - `pengeluaran`  -> dihitung pengeluaran sebesar nominal
/// - `pemasukan`    -> dihitung pemasukan sebesar nominal
/// - `transfer`     -> ke akun sendiri: hanya biaya admin yang jadi pengeluaran;
///                     ke pihak lain: nominal + biaya admin jadi pengeluaran
int expenseAmount(Transaction t, Set<String> ownAccountIds) {
  switch (t.tipe) {
    case TxType.pemasukan:
      return 0;
    case TxType.pengeluaran:
      return t.nominal;
    case TxType.transfer:
      final toOwn =
          t.akunTujuanId != null && ownAccountIds.contains(t.akunTujuanId);
      return toOwn ? t.biayaAdmin : t.nominal + t.biayaAdmin;
  }
}

int incomeAmount(Transaction t) =>
    t.tipe == TxType.pemasukan ? t.nominal : 0;

/// Kategori bawaan untuk biaya admin transfer antar akun sendiri (Bagian 8.1):
/// pengeluarannya dibukukan ke "Transfer & Admin", bukan ke kategori yang
/// dipilih untuk transfernya.
const String kTransferAdminCategoryId = 'transfer_admin';

/// Kategori tempat pengeluaran sebuah transaksi dibukukan.
///
/// Berbeda dari `Transaction.kategoriId` hanya untuk transfer antar akun
/// sendiri: satu-satunya pengeluarannya adalah biaya admin, dan Bagian 8.1
/// menetapkan biaya itu masuk kategori "Transfer & Admin".
String? expenseCategoryId(Transaction t, Set<String> ownAccountIds) {
  if (t.tipe == TxType.transfer) {
    final toOwn =
        t.akunTujuanId != null && ownAccountIds.contains(t.akunTujuanId);
    if (toOwn) return kTransferAdminCategoryId;
  }
  return t.kategoriId;
}

class Totals {
  const Totals(this.income, this.expense);
  final int income;
  final int expense;
  int get net => income - expense;
}

Totals computeTotals(List<Transaction> txs, Set<String> ownAccountIds) {
  var inc = 0;
  var exp = 0;
  for (final t in txs) {
    inc += incomeAmount(t);
    exp += expenseAmount(t, ownAccountIds);
  }
  return Totals(inc, exp);
}

class CategoryTotal {
  CategoryTotal({required this.kategoriId, required this.total});
  final String? kategoriId;
  final int total;
}

/// Total pengeluaran per kategori (untuk donut & tabel rekap).
List<CategoryTotal> expenseByCategory(
  List<Transaction> txs,
  Set<String> ownAccountIds,
) {
  final map = <String?, int>{};
  for (final t in txs) {
    final amount = expenseAmount(t, ownAccountIds);
    if (amount == 0) continue;
    final kategori = expenseCategoryId(t, ownAccountIds);
    map[kategori] = (map[kategori] ?? 0) + amount;
  }
  final list = map.entries
      .map((e) => CategoryTotal(kategoriId: e.key, total: e.value))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return list;
}

class MonthPoint {
  MonthPoint({required this.month, required this.income, required this.expense});
  final DateTime month;
  final int income;
  final int expense;
}

/// Seri bulanan untuk bar chart (Bagian FR-4.4).
List<MonthPoint> monthlySeries(
  List<Transaction> txs,
  Set<String> ownAccountIds,
  int months,
  DateTime now,
) {
  final points = <MonthPoint>[];
  for (var i = months - 1; i >= 0; i--) {
    final m = DateTime(now.year, now.month - i, 1);
    final inMonth = txs.where(
      (t) => t.tanggal.year == m.year && t.tanggal.month == m.month,
    );
    final totals = computeTotals(inMonth.toList(), ownAccountIds);
    points.add(
      MonthPoint(month: m, income: totals.income, expense: totals.expense),
    );
  }
  return points;
}

/// Saldo berjalan satu akun (Bagian FR-7.2).
int accountBalance(
  String accountId,
  int saldoAwal,
  List<Transaction> txs,
) {
  var balance = saldoAwal;
  for (final t in txs) {
    switch (t.tipe) {
      case TxType.pemasukan:
        if (t.akunId == accountId) balance += t.nominal;
        break;
      case TxType.pengeluaran:
        if (t.akunId == accountId) balance -= t.nominal;
        break;
      case TxType.transfer:
        if (t.akunAsalId == accountId) balance -= (t.nominal + t.biayaAdmin);
        if (t.akunTujuanId == accountId) balance += t.nominal;
        break;
    }
  }
  return balance;
}

/// Uang yang tersisa sampai akhir suatu tanggal: jumlah saldo berjalan seluruh
/// akun milik sendiri.
///
/// Dihitung lewat [accountBalance] supaya aturan transfer tetap punya satu
/// sumber, dengan begitu transfer antar akun sendiri tidak mengubah total.
/// Akun milik pihak lain tidak dihitung karena uangnya bukan milik pengguna.
int sisaUangSampai(
  List<Account> accounts,
  List<Transaction> txs,
  DateTime sampai,
) {
  final batas = DateTime(sampai.year, sampai.month, sampai.day, 23, 59, 59);
  final sampaiSini = txs.where((t) => !t.tanggal.isAfter(batas)).toList();
  var total = 0;
  for (final a in accounts) {
    if (!a.aktif || !a.milikSendiri) continue;
    total += accountBalance(a.id, a.saldoAwal, sampaiSini);
  }
  return total;
}

class BudgetUsage {
  BudgetUsage({required this.budget, required this.used});
  final Budget budget;
  final int used;

  /// Terpakai 0..∞ (>=1 berarti lewat batas).
  double get fraction => budget.nominal <= 0 ? 0 : used / budget.nominal;
  int get remaining => budget.nominal - used;
}

DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59);

bool _within(DateTime t, DateTime start, DateTime end) =>
    !t.isBefore(DateTime(start.year, start.month, start.day)) &&
    !t.isAfter(_endOfDay(end));

/// Pemakaian satu anggaran: pengeluaran dalam rentang (dan kategori bila
/// lingkup = kategori), mengikuti aturan transfer Bagian 8.1.
BudgetUsage budgetUsageOf(
  Budget b,
  List<Transaction> txs,
  Set<String> ownAccountIds,
) {
  var used = 0;
  for (final t in txs) {
    if (!_within(t.tanggal, b.periodeMulai, b.periodeSelesai)) continue;
    if (b.lingkup == BudgetScope.kategori &&
        expenseCategoryId(t, ownAccountIds) != b.kategoriId) {
      continue;
    }
    used += expenseAmount(t, ownAccountIds);
  }
  return BudgetUsage(budget: b, used: used);
}

/// Angka "Total Anggaran" gabungan dari sekumpulan anggaran yang berlaku.
///
/// Bila ada anggaran lingkup total, itulah totalnya (PRD Bagian 8.2) supaya
/// anggaran kategori yang berperan sebagai sub-batas tidak terhitung dua kali.
/// Bila anggaran total belum disetel, seluruh anggaran kategori dijumlahkan
/// sehingga pengguna yang hanya menetapkan batas per kategori tetap punya satu
/// angka total. Anggaran nonaktif selalu diabaikan.
class BudgetTotal {
  BudgetTotal({
    required this.nominal,
    required this.used,
    required this.jumlahAnggaran,
    required this.dariKategori,
  });

  final int nominal;
  final int used;

  /// Banyaknya anggaran yang diwakili angka ini.
  final int jumlahAnggaran;

  /// true bila angka ini hasil penjumlahan anggaran kategori.
  final bool dariKategori;

  bool get kosong => jumlahAnggaran == 0;

  /// Terpakai 0..∞ (>=1 berarti lewat batas).
  double get fraction => nominal <= 0 ? 0 : used / nominal;
  int get remaining => nominal - used;
}

BudgetTotal totalAnggaranOf(
  List<Budget> budgets,
  List<Transaction> txs,
  Set<String> ownAccountIds,
) {
  final aktif = budgets.where((b) => b.aktif).toList();

  for (final b in aktif) {
    if (b.lingkup != BudgetScope.total) continue;
    return BudgetTotal(
      nominal: b.nominal,
      used: budgetUsageOf(b, txs, ownAccountIds).used,
      jumlahAnggaran: 1,
      dariKategori: false,
    );
  }

  var nominal = 0;
  var used = 0;
  var jumlah = 0;
  for (final b in aktif) {
    if (b.lingkup != BudgetScope.kategori) continue;
    nominal += b.nominal;
    used += budgetUsageOf(b, txs, ownAccountIds).used;
    jumlah++;
  }
  return BudgetTotal(
    nominal: nominal,
    used: used,
    jumlahAnggaran: jumlah,
    dariKategori: true,
  );
}

