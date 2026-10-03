import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/account_repository.dart';
import 'package:elutung/data/repositories/institution_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InstitutionRepository institutions;
  late AccountRepository accounts;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    institutions = InstitutionRepository(db);
    accounts = AccountRepository(db);
  });

  tearDown(() => db.close());

  test('seed institusi & kategori terisi saat onCreate', () async {
    final inst = await db.select(db.institutions).get();
    final cat = await db.select(db.categories).get();
    expect(inst.length, greaterThan(5));
    expect(cat.length, greaterThan(5));
    expect(inst.any((e) => e.nama == 'Tunai'), isTrue);
    expect(cat.any((e) => e.nama == 'Makanan & Minuman'), isTrue);
  });

  test('CRUD institusi (create/update/soft delete)', () async {
    final id = await institutions.create(
      nama: 'Bank Uji',
      tipe: InstitutionType.bank,
    );
    var list = await institutions.watchAll().first;
    expect(list.any((e) => e.id == id && e.nama == 'Bank Uji'), isTrue);

    await institutions.update(
      id: id,
      nama: 'Bank Uji 2',
      tipe: InstitutionType.ewallet,
      aktif: false,
    );
    list = await institutions.watchAll().first;
    final updated = list.firstWhere((e) => e.id == id);
    expect(updated.nama, 'Bank Uji 2');
    expect(updated.tipe, InstitutionType.ewallet);
    expect(updated.aktif, isFalse);

    await institutions.softDelete(id);
    list = await institutions.watchAll().first;
    expect(list.any((e) => e.id == id), isFalse);
  });

  test('akun terhubung ke institusi (join) dan saldo tersimpan', () async {
    final iid = await institutions.create(
      nama: 'OVO Uji',
      tipe: InstitutionType.ewallet,
    );
    final aid = await accounts.create(
      institusiId: iid,
      milikSendiri: true,
      saldoAwal: 50000,
    );

    final rows = await accounts.watchAll().first;
    final row = rows.firstWhere((e) => e.account.id == aid);
    expect(row.institusi.nama, 'OVO Uji');
    expect(row.account.saldoAwal, 50000);
    expect(row.account.milikSendiri, isTrue);
  });

  test('usedByAccounts menghitung akun aktif pemakai institusi', () async {
    final iid = await institutions.create(
      nama: 'Dana Uji',
      tipe: InstitutionType.ewallet,
    );
    expect(await institutions.usedByAccounts(iid), 0);
    await accounts.create(institusiId: iid, milikSendiri: true, saldoAwal: 0);
    expect(await institutions.usedByAccounts(iid), 1);
  });

  test('skema v2: categories tanpa archived, indeks transaksi dibuat', () async {
    final cols = await db.customSelect('PRAGMA table_info(categories)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('archived'), isFalse);

    final indexes = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final indexNames = indexes.map((r) => r.read<String>('name')).toSet();
    expect(indexNames.contains('idx_transactions_tipe_tanggal_kategori'), isTrue);
  });
}
