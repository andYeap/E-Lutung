import 'package:elutung/data/database.dart';
import 'package:elutung/data/finance.dart';
import 'package:elutung/util/budget.dart';
import 'package:flutter_test/flutter_test.dart';

Budget budget({
  required BudgetScope lingkup,
  String? kategoriId,
  required int nominal,
  DateTime? mulai,
  DateTime? selesai,
}) => Budget(
  id: 'b1',
  lingkup: lingkup,
  kategoriId: kategoriId,
  periodeMulai: mulai ?? DateTime(2026, 1, 5),
  periodeSelesai: selesai ?? DateTime(2026, 1, 10),
  nominal: nominal,
  aktif: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  deletedAt: null,
);

Transaction tx({
  required TxType tipe,
  required int nominal,
  int biayaAdmin = 0,
  String? kategoriId,
  String? akunAsalId,
  String? akunTujuanId,
  DateTime? tanggal,
}) => Transaction(
  id: 't',
  tipe: tipe,
  nominal: nominal,
  tanggal: tanggal ?? DateTime(2026, 1, 7),
  kategoriId: kategoriId,
  akunId: null,
  catatan: null,
  akunAsalId: akunAsalId,
  akunTujuanId: akunTujuanId,
  biayaAdmin: biayaAdmin,
  createdAt: DateTime(2026, 1, 7),
  updatedAt: DateTime(2026, 1, 7),
  deletedAt: null,
);

void main() {
  group('budgetLevel (Bagian 8.2)', () {
    test('ambang batas warna', () {
      expect(budgetLevel(0.0), BudgetLevel.aman);
      expect(budgetLevel(0.59), BudgetLevel.aman);
      expect(budgetLevel(0.60), BudgetLevel.waspada);
      expect(budgetLevel(0.85), BudgetLevel.menipis);
      expect(budgetLevel(0.99), BudgetLevel.menipis);
      expect(budgetLevel(1.0), BudgetLevel.lewat);
      expect(budgetLevel(1.5), BudgetLevel.lewat);
    });
  });

  group('budgetUsageOf', () {
    const own = {'a1', 'a2'};
    final b = budget(lingkup: BudgetScope.total, nominal: 100000);

    test('menjumlahkan pengeluaran dalam rentang saja', () {
      final usage = budgetUsageOf(b, [
        tx(tipe: TxType.pengeluaran, nominal: 30000, tanggal: DateTime(2026, 1, 7)),
        tx(tipe: TxType.pengeluaran, nominal: 50000, tanggal: DateTime(2026, 1, 20)), // di luar
        tx(tipe: TxType.pemasukan, nominal: 999999, tanggal: DateTime(2026, 1, 8)),
      ], own);
      expect(usage.used, 30000);
      expect(usage.remaining, 70000);
      expect(usage.fraction, closeTo(0.3, 0.0001));
    });

    test('transfer ke pihak lain menambah pengeluaran; ke akun sendiri hanya admin', () {
      final usage = budgetUsageOf(b, [
        tx(tipe: TxType.transfer, nominal: 40000, biayaAdmin: 2000, akunAsalId: 'a1', akunTujuanId: 'luar'),
        tx(tipe: TxType.transfer, nominal: 40000, biayaAdmin: 2000, akunAsalId: 'a1', akunTujuanId: 'a2'),
      ], own);
      expect(usage.used, 42000 + 2000);
    });

    test('rentang inklusif sampai 23:59:59 di tanggal selesai', () {
      final b = budget(
        lingkup: BudgetScope.total,
        nominal: 100000,
        mulai: DateTime(2026, 1, 5),
        selesai: DateTime(2026, 1, 10),
      );
      final usage = budgetUsageOf(b, [
        tx(tipe: TxType.pengeluaran, nominal: 1000, tanggal: DateTime(2026, 1, 5)),
        tx(
          tipe: TxType.pengeluaran,
          nominal: 2000,
          tanggal: DateTime(2026, 1, 10, 23, 59, 59),
        ),
        tx(tipe: TxType.pengeluaran, nominal: 4000, tanggal: DateTime(2026, 1, 11)),
        tx(tipe: TxType.pengeluaran, nominal: 8000, tanggal: DateTime(2026, 1, 4, 23, 59)),
      ], own);
      expect(usage.used, 3000);
    });

    test('pembagi nol tidak menghasilkan NaN (Bagian 13)', () {
      final b = budget(
        lingkup: BudgetScope.total,
        nominal: 0,
        mulai: DateTime(2026, 1, 1),
        selesai: DateTime(2026, 1, 31),
      );
      final usage = budgetUsageOf(b, [
        tx(tipe: TxType.pengeluaran, nominal: 5000),
      ], own);
      expect(usage.fraction.isNaN, isFalse);
      expect(usage.fraction, 0);
      expect(usage.remaining, -5000);
    });

    test('anggaran kategori "Transfer & Admin" menangkap admin internal', () {
      final b = budget(
        lingkup: BudgetScope.kategori,
        kategoriId: kTransferAdminCategoryId,
        nominal: 100000,
      );
      final usage = budgetUsageOf(b, [
        tx(
          tipe: TxType.transfer,
          nominal: 500000,
          biayaAdmin: 2500,
          akunAsalId: 'a1',
          akunTujuanId: 'a2',
        ),
        tx(
          tipe: TxType.transfer,
          nominal: 400000,
          biayaAdmin: 1000,
          akunAsalId: 'a1',
          akunTujuanId: 'luar',
        ),
      ], own);
      // Hanya admin transfer internal (2.500) yang masuk kategori ini.
      expect(usage.used, 2500);
    });

    test('lingkup kategori hanya menghitung kategori itu', () {
      final bk = budget(lingkup: BudgetScope.kategori, kategoriId: 'makanan', nominal: 50000);
      final usage = budgetUsageOf(bk, [
        tx(tipe: TxType.pengeluaran, nominal: 20000, kategoriId: 'makanan'),
        tx(tipe: TxType.pengeluaran, nominal: 30000, kategoriId: 'transport'),
      ], own);
      expect(usage.used, 20000);
    });
  });
}
