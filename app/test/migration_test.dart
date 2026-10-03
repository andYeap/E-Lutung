import 'dart:io';

import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Migrasi v1 -> v2 diuji nyata pada file DB: buat skema (v2), turunkan ke
/// bentuk v1 (kolom `archived` + `user_version = 1`), lalu buka ulang supaya
/// `onUpgrade` benar-benar dijalankan. Data harus selamat.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('elutung_migrasi');
    file = File('${dir.path}/elutung.sqlite');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('v1 -> v2 membuang archived & membuat indeks, data selamat', () async {
    final v2 = AppDatabase(NativeDatabase(file));
    await v2.customStatement(
      'ALTER TABLE categories ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
    );
    await v2.customStatement(
      "INSERT INTO categories (id, nama, archived, created_at, updated_at) "
      "VALUES ('uji', 'Kategori Lama', 0, 0, 0)",
    );
    await v2.customStatement(
      'DROP INDEX IF EXISTS idx_transactions_tipe_tanggal_kategori',
    );
    await v2.customStatement('PRAGMA user_version = 1');
    await v2.close();

    final db = AppDatabase(NativeDatabase(file));
    final cols = await db.customSelect('PRAGMA table_info(categories)').get();
    expect(cols.map((r) => r.read<String>('name')), isNot(contains('archived')));

    final rows = await db.select(db.categories).get();
    expect(rows.any((c) => c.id == 'uji' && c.nama == 'Kategori Lama'), isTrue);

    final indexes = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    expect(
      indexes.map((r) => r.read<String>('name')),
      contains('idx_transactions_tipe_tanggal_kategori'),
    );
    await db.close();
  });
}
