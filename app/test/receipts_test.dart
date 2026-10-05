import 'dart:io';

import 'package:drift/native.dart';
import 'package:elutung/data/backup.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:elutung/services/receipt_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TransactionRepository(db);
  });

  tearDown(() => db.close());

  Future<String> kategoriSeed() async {
    final cats = await db.select(db.categories).get();
    return cats.first.id;
  }

  Future<String> buat({
    String? strukPath,
    bool hapus = false,
  }) async {
    final id = await repo.create(
      tipe: TxType.pengeluaran,
      nominal: 25000,
      tanggal: DateTime(2026, 5, 12),
      kategoriId: await kategoriSeed(),
      strukPath: strukPath,
    );
    if (hapus) await repo.softDelete(id);
    return id;
  }

  group('transaksi dengan foto struk', () {
    test('hanya transaksi yang punya strukPath yang muncul', () async {
      await buat(strukPath: '/tmp/a.jpg');
      await buat(strukPath: null);

      final list = await repo.watchWithReceipt().first;
      expect(list.length, 1);
      expect(list.first.strukPath, '/tmp/a.jpg');
    });

    test('transaksi terhapus tidak muncul', () async {
      await buat(strukPath: '/tmp/a.jpg');
      await buat(strukPath: '/tmp/b.jpg', hapus: true);

      final list = await repo.watchWithReceipt().first;
      expect(list.map((t) => t.strukPath), ['/tmp/a.jpg']);
    });

    test('path hilang tetap dikembalikan agar bisa dibersihkan', () async {
      // Foto tidak ikut ekspor cadangan, jadi path bisa menunjuk berkas yang
      // sudah tidak ada. Layar harus bisa membedakannya, bukan menyembunyikan.
      await buat(strukPath: '/tmp/hilang.jpg');

      final list = await repo.watchWithReceipt().first;
      expect(list.length, 1);
      expect(ReceiptStorage.ada(list.first.strukPath), isFalse);
    });

    test('clearReceiptPath melepas foto tanpa menghapus transaksi', () async {
      final id = await buat(strukPath: '/tmp/a.jpg');
      await repo.clearReceiptPath(id);

      final transaksi = await (db.select(db.transactions)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(transaksi.strukPath, isNull);
      expect(transaksi.deletedAt, isNull);
    });

    test('clearReceiptPaths melepas banyak sekaligus', () async {
      final a = await buat(strukPath: '/tmp/a.jpg');
      final b = await buat(strukPath: '/tmp/b.jpg');
      await buat(strukPath: null);

      await repo.clearReceiptPaths([a, b]);

      final list = await repo.watchWithReceipt().first;
      expect(list, isEmpty);
    });

    test('clearReceiptPaths dengan daftar kosong tidak gagal', () async {
      await buat(strukPath: '/tmp/a.jpg');
      await repo.clearReceiptPaths(const []);
      expect((await repo.watchWithReceipt().first).length, 1);
    });

    test('diurutkan dari tanggal terbaru', () async {
      final lama = repo.create(
        tipe: TxType.pengeluaran,
        nominal: 1000,
        tanggal: DateTime(2026, 1, 1),
        strukPath: '/tmp/lama.jpg',
      );
      final baru = repo.create(
        tipe: TxType.pengeluaran,
        nominal: 2000,
        tanggal: DateTime(2026, 6, 1),
        strukPath: '/tmp/baru.jpg',
      );
      await lama;
      await baru;

      final list = await repo.watchWithReceipt().first;
      expect(list.map((t) => t.strukPath), ['/tmp/baru.jpg', '/tmp/lama.jpg']);
    });
  });

  group('ReceiptStorage', () {
    late Directory temp;

    setUp(() async => temp = await Directory.systemTemp.createTemp('struk_test'));
    tearDown(() async {
      if (temp.existsSync()) await temp.delete(recursive: true);
    });

    String buatFile(String nama, [int? ukuran]) {
      final f = File('${temp.path}/$nama');
      f.writeAsBytesSync(List<int>.filled(ukuran ?? 10, 0));
      return f.path;
    }

    test('ada membedakan berkas nyata, path kosong, dan null', () {
      expect(ReceiptStorage.ada(buatFile('a.jpg')), isTrue);
      expect(ReceiptStorage.ada('${temp.path}/tidak-ada.jpg'), isFalse);
      expect(ReceiptStorage.ada(''), isFalse);
      expect(ReceiptStorage.ada(null), isFalse);
    });

    test('ukuran 0 untuk berkas yang hilang atau null', () {
      expect(ReceiptStorage.ukuran(buatFile('a.jpg', 100)), 100);
      expect(ReceiptStorage.ukuran('${temp.path}/hilang.jpg'), 0);
      expect(ReceiptStorage.ukuran(null), 0);
    });

    test('totalUkuranSync menjumlahkan yang ada saja', () {
      expect(
        ReceiptStorage.totalUkuranSync([
          buatFile('a.jpg', 100),
          '${temp.path}/hilang.jpg',
          null,
          buatFile('b.jpg', 50),
        ]),
        150,
      );
    });

    test('hapus menghapus berkas dan aman dipanggil ulang', () async {
      final path = buatFile('a.jpg');
      await ReceiptStorage.hapus(path);
      expect(File(path).existsSync(), isFalse);
      // Panggil kedua kali tidak boleh melempar.
      await ReceiptStorage.hapus(path);
      await ReceiptStorage.hapus(null);
    });

    test('hapusSemua membersihkan banyak berkas, mengabaikan yang hilang', () async {
      final a = buatFile('a.jpg');
      final b = buatFile('b.jpg');
      await ReceiptStorage.hapusSemua([a, '${temp.path}/hilang.jpg', null, b]);
      expect(File(a).existsSync(), isFalse);
      expect(File(b).existsSync(), isFalse);
    });

    test('formatUkuran memakai satuan yang wajar', () {
      expect(ReceiptStorage.formatUkuran(512), '512 B');
      expect(ReceiptStorage.formatUkuran(2048), '2 KB');
      expect(ReceiptStorage.formatUkuran(5 * 1024 * 1024), '5.0 MB');
    });

    test('hapus semua data ikut menghapus berkas foto', () async {
      // Tanpa ini, "Hapus semua data" meninggalkan foto pengguna di dokumen
      // aplikasi tanpa jejak di database dan tanpa layar untuk menemukannya.
      final path = buatFile('a.jpg', 20);
      await repo.create(
        tipe: TxType.pengeluaran,
        nominal: 10000,
        tanggal: DateTime(2026, 5, 12),
        kategoriId: await kategoriSeed(),
        strukPath: path,
      );

      await BackupService(db).wipeUserData();

      expect(File(path).existsSync(), isFalse);
      expect(await db.select(db.transactions).get(), isEmpty);
      // Master kategori dipertahankan agar aplikasi masih bisa dipakai.
      expect(await db.select(db.categories).get(), isNotEmpty);
    });
  });
}
