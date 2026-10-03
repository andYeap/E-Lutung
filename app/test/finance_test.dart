import 'package:elutung/data/database.dart';
import 'package:elutung/data/finance.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction tx({
  required TxType tipe,
  required int nominal,
  int biayaAdmin = 0,
  String? kategoriId,
  String? akunId,
  String? akunAsalId,
  String? akunTujuanId,
  DateTime? tanggal,
}) => Transaction(
  id: 'id',
  tipe: tipe,
  nominal: nominal,
  tanggal: tanggal ?? DateTime(2026, 1, 5),
  kategoriId: kategoriId,
  akunId: akunId,
  catatan: null,
  akunAsalId: akunAsalId,
  akunTujuanId: akunTujuanId,
  biayaAdmin: biayaAdmin,
  createdAt: DateTime(2026, 1, 5),
  updatedAt: DateTime(2026, 1, 5),
  deletedAt: null,
);

void main() {
  const own = {'a1', 'a2'};

  group('aturan transfer (Bagian 8.1)', () {
    test('pengeluaran dihitung sebesar nominal', () {
      expect(expenseAmount(tx(tipe: TxType.pengeluaran, nominal: 25000), own), 25000);
    });

    test('pemasukan tidak masuk pengeluaran', () {
      expect(expenseAmount(tx(tipe: TxType.pemasukan, nominal: 1000000), own), 0);
      expect(incomeAmount(tx(tipe: TxType.pemasukan, nominal: 1000000)), 1000000);
    });

    test('transfer ke akun sendiri: hanya biaya admin yang jadi pengeluaran', () {
      final t = tx(
        tipe: TxType.transfer,
        nominal: 500000,
        biayaAdmin: 2500,
        akunAsalId: 'a1',
        akunTujuanId: 'a2',
      );
      expect(expenseAmount(t, own), 2500);
    });

    test('admin transfer antar akun sendiri dibukukan ke "Transfer & Admin"', () {
      final internal = tx(
        tipe: TxType.transfer,
        nominal: 500000,
        biayaAdmin: 2500,
        kategoriId: 'hiburan', // kategori transfer diabaikan untuk admin
        akunAsalId: 'a1',
        akunTujuanId: 'a2',
      );
      expect(expenseCategoryId(internal, own), kTransferAdminCategoryId);

      final external = tx(
        tipe: TxType.transfer,
        nominal: 500000,
        biayaAdmin: 2500,
        kategoriId: 'belanja',
        akunAsalId: 'a1',
        akunTujuanId: 'luar',
      );
      expect(expenseCategoryId(external, own), 'belanja');

      final belanja = tx(
        tipe: TxType.pengeluaran,
        nominal: 10000,
        kategoriId: 'makanan',
      );
      expect(expenseCategoryId(belanja, own), 'makanan');

      final byCat = expenseByCategory([internal, external, belanja], own);
      final map = {for (final c in byCat) c.kategoriId: c.total};
      expect(map[kTransferAdminCategoryId], 2500);
      expect(map['belanja'], 502500);
      expect(map['makanan'], 10000);
    });

    test('transfer ke pihak lain: nominal + admin jadi pengeluaran', () {
      final t = tx(
        tipe: TxType.transfer,
        nominal: 500000,
        biayaAdmin: 2500,
        akunAsalId: 'a1',
        akunTujuanId: 'luar',
      );
      expect(expenseAmount(t, own), 502500);
    });
  });

  group('agregasi', () {
    test('computeTotals menjumlahkan masuk/keluar', () {
      final t = computeTotals([
        tx(tipe: TxType.pemasukan, nominal: 1000000),
        tx(tipe: TxType.pengeluaran, nominal: 200000),
        tx(tipe: TxType.transfer, nominal: 300000, biayaAdmin: 2000, akunAsalId: 'a1', akunTujuanId: 'a2'),
      ], own);
      expect(t.income, 1000000);
      expect(t.expense, 202000);
      expect(t.net, 1000000 - 202000);
    });

    test('expenseByCategory mengelompokkan & mengurutkan menurun', () {
      final list = expenseByCategory([
        tx(tipe: TxType.pengeluaran, nominal: 10000, kategoriId: 'makanan'),
        tx(tipe: TxType.pengeluaran, nominal: 30000, kategoriId: 'makanan'),
        tx(tipe: TxType.pengeluaran, nominal: 5000, kategoriId: 'transport'),
      ], own);
      expect(list.length, 2);
      expect(list.first.kategoriId, 'makanan');
      expect(list.first.total, 40000);
    });

    test('monthlySeries menghasilkan N titik sesuai bulan', () {
      final now = DateTime(2026, 3, 15);
      final points = monthlySeries([
        tx(tipe: TxType.pengeluaran, nominal: 1000, tanggal: DateTime(2026, 3, 1)),
      ], own, 3, now);
      expect(points.length, 3);
      expect(points.last.expense, 1000);
    });

    test('batas bulan: 23:59 tgl terakhir vs 00:00 tgl 1 jatuh ke periode beda', () {
      final points = monthlySeries([
        tx(
          tipe: TxType.pengeluaran,
          nominal: 1000,
          tanggal: DateTime(2026, 3, 31, 23, 59, 59),
        ),
        tx(
          tipe: TxType.pengeluaran,
          nominal: 2000,
          tanggal: DateTime(2026, 4, 1),
        ),
      ], own, 2, DateTime(2026, 4, 15));
      expect(points.length, 2);
      expect(points[0].expense, 1000); // Maret
      expect(points[1].expense, 2000); // April
    });

    test('saldo akun: transfer internal memindahkan uang, admin mengurangi asal', () {
      final balance = accountBalance('a1', 100000, [
        tx(tipe: TxType.transfer, nominal: 40000, biayaAdmin: 2500, akunAsalId: 'a1', akunTujuanId: 'a2'),
      ]);
      expect(balance, 100000 - 42500);
      final balance2 = accountBalance('a2', 0, [
        tx(tipe: TxType.transfer, nominal: 40000, biayaAdmin: 2500, akunAsalId: 'a1', akunTujuanId: 'a2'),
      ]);
      expect(balance2, 40000);
    });
  });
}
