import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/merchant.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('polaMerchant', () {
    test('menyeragamkan huruf dan tanda baca', () {
      expect(polaMerchant('Warung Bu Ani,'), 'warung bu ani');
      expect(polaMerchant('  WARUNG   BU ANI  '), 'warung bu ani');
      expect(polaMerchant('Toko-A/Satu'), 'toko a satu');
    });

    test('terlalu pendek atau kosong bukan pola', () {
      expect(polaMerchant(null), isNull);
      expect(polaMerchant(''), isNull);
      expect(polaMerchant('  ... '), isNull);
      expect(polaMerchant('ok'), isNull);
    });
  });

  group('validasi nominal transaksi', () {
    late AppDatabase db;
    late TransactionRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = TransactionRepository(db);
    });
    tearDown(() => db.close());

    Future<String> simpan(int nominal, {int biayaAdmin = 0}) => repo.create(
      tipe: TxType.pengeluaran,
      nominal: nominal,
      tanggal: DateTime(2026, 5, 1),
      kategoriId: 'makanan',
      biayaAdmin: biayaAdmin,
    );

    test('nominal nol atau negatif ditolak saat create', () async {
      expect(() => simpan(0), throwsArgumentError);
      expect(() => simpan(-50000), throwsArgumentError);
    });

    test('biaya admin negatif ditolak saat create', () async {
      expect(() => simpan(10000, biayaAdmin: -100), throwsArgumentError);
    });

    test('nominal nol ditolak saat update', () async {
      final id = await simpan(10000);
      expect(
        () => repo.update(
          id: id,
          tipe: TxType.pengeluaran,
          nominal: 0,
          tanggal: DateTime(2026, 5, 1),
          kategoriId: 'makanan',
        ),
        throwsArgumentError,
      );
    });
  });

  group('kebiasaan pedagang', () {
    late AppDatabase db;
    late TransactionRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = TransactionRepository(db);
    });
    tearDown(() => db.close());

    test('menyimpan pemetaan dari transaksi pengeluaran', () async {
      await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 25000,
        tanggal: DateTime(2026, 5, 1),
        kategoriId: 'makanan',
        akunId: 'tunai',
        catatan: 'Warung Bu Ani',
      );

      final h = await repo.cariKebiasaan('warung bu ani');
      expect(h, isNotNull);
      expect(h!.pola, 'warung bu ani');
      expect(h.kategoriId, 'makanan');
      expect(h.akunId, 'tunai');
      expect(h.jumlahPemakaian, 1);
    });

    test('pilihan sama berulang menaikkan hitungan', () async {
      for (var i = 0; i < 3; i++) {
        await repo.create(
          tipe: TxType.pengeluaran,
          nominal: 10000,
          tanggal: DateTime(2026, 5, 1),
          kategoriId: 'makanan',
          akunId: 'tunai',
          catatan: 'Warung Bu Ani',
        );
      }

      final h = await repo.cariKebiasaan('Warung Bu Ani');
      expect(h!.jumlahPemakaian, 3);
    });

    test('pilihan terakhir menang dan hitungannya mulai lagi', () async {
      await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 10000,
        tanggal: DateTime(2026, 5, 1),
        kategoriId: 'makanan',
        akunId: 'tunai',
        catatan: 'Warung Bu Ani',
      );
      await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 12000,
        tanggal: DateTime(2026, 5, 2),
        kategoriId: 'belanja',
        akunId: 'bca',
        catatan: 'Warung Bu Ani',
      );

      final h = await repo.cariKebiasaan('Warung Bu Ani');
      expect(h!.kategoriId, 'belanja');
      expect(h.akunId, 'bca');
      expect(h.jumlahPemakaian, 1);
    });

    test('pemasukan dan transaksi tanpa keterangan tidak dicatat', () async {
      await repo.create(
        tipe: TxType.pemasukan,
        nominal: 500000,
        tanggal: DateTime(2026, 5, 1),
        kategoriId: 'gaji',
        catatan: 'Gaji Mei',
      );
      await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 15000,
        tanggal: DateTime(2026, 5, 1),
        kategoriId: 'makanan',
      );

      expect(await db.select(db.merchantHabits).get(), isEmpty);
    });

    test('tanpa kategori tidak ada yang dicatat', () async {
      await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 15000,
        tanggal: DateTime(2026, 5, 1),
        catatan: 'Warung Bu Ani',
      );

      expect(await db.select(db.merchantHabits).get(), isEmpty);
    });

    test('pedagang yang berbeda punya pola sendiri', () async {
      await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 10000,
        tanggal: DateTime(2026, 5, 1),
        kategoriId: 'makanan',
        catatan: 'Warung Bu Ani',
      );
      await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 20000,
        tanggal: DateTime(2026, 5, 2),
        kategoriId: 'belanja',
        catatan: 'Toko Serba Ada',
      );

      expect((await repo.cariKebiasaan('warung bu ani'))!.kategoriId, 'makanan');
      expect(
        (await repo.cariKebiasaan('toko serba ada'))!.kategoriId,
        'belanja',
      );
    });

    test('edit memperbarui kebiasaan pedagang (pilihan terakhir menang)', () async {
      final id = await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 10000,
        tanggal: DateTime(2026, 5, 1),
        kategoriId: 'makanan',
        akunId: 'tunai',
        catatan: 'Warung Bu Ani',
      );
      await repo.update(
        id: id,
        tipe: TxType.pengeluaran,
        nominal: 10000,
        tanggal: DateTime(2026, 5, 1),
        kategoriId: 'belanja',
        akunId: 'bca',
        catatan: 'Warung Bu Ani',
      );

      final h = await repo.cariKebiasaan('Warung Bu Ani');
      expect(h!.kategoriId, 'belanja');
      expect(h.akunId, 'bca');
      expect(h.jumlahPemakaian, 1);
    });

    test('hapusKebiasaan menghapus permanen pola itu saja', () async {
      await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 10000,
        tanggal: DateTime(2026, 5, 1),
        kategoriId: 'makanan',
        catatan: 'Warung Bu Ani',
      );
      await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 20000,
        tanggal: DateTime(2026, 5, 2),
        kategoriId: 'belanja',
        catatan: 'Toko Serba Ada',
      );

      await repo.hapusKebiasaan('warung bu ani');

      expect(await repo.cariKebiasaan('Warung Bu Ani'), isNull);
      expect(
        (await repo.cariKebiasaan('toko serba ada'))!.kategoriId,
        'belanja',
      );
    });
  });
}
