import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Migrasi skema diuji nyata pada berkas basis data: skema versi terbaru dibuat,
/// lalu diturunkan ke bentuk versi lama, lalu dibuka ulang supaya `onUpgrade`
/// benar-benar berjalan. Data lama harus selamat.
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

  Future<bool> hasColumn(AppDatabase db, String table, String column) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.any((r) => r.read<String>('name') == column);
  }

  Future<bool> hasEntity(AppDatabase db, String name) async {
    final rows = await db
        .customSelect(
          'SELECT name FROM sqlite_master WHERE name = ?',
          variables: [Variable<String>(name)],
        )
        .get();
    return rows.isNotEmpty;
  }

  test('v1 -> v3: archived dibuang, tabel & indeks berulang dibuat', () async {
    final seed = AppDatabase(NativeDatabase(file));
    // Kembalikan ke bentuk v1.
    await seed.customStatement(
      'ALTER TABLE categories ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
    );
    await seed.customStatement(
      "INSERT INTO categories (id, nama, archived, created_at, updated_at) "
      "VALUES ('uji', 'Kategori Lama', 0, 0, 0)",
    );
    await seed.customStatement(
      'DROP INDEX IF EXISTS idx_transactions_tipe_tanggal_kategori',
    );
    await seed.customStatement(
      'DROP INDEX IF EXISTS idx_transactions_recurring_tanggal',
    );
    await seed.customStatement('DROP TABLE IF EXISTS recurring_rules');
    await seed.customStatement(
      'ALTER TABLE transactions DROP COLUMN recurring_rule_id',
    );
    await seed.customStatement('PRAGMA user_version = 1');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));

    // Langkah v2: kolom archived hilang, data lama selamat.
    expect(await hasColumn(db, 'categories', 'archived'), isFalse);
    final kategori = await db.select(db.categories).get();
    expect(kategori.any((c) => c.id == 'uji'), isTrue);
    expect(
      await hasEntity(db, 'idx_transactions_tipe_tanggal_kategori'),
      isTrue,
    );

    // Langkah v3: tabel aturan, kolom penanda, dan indeks uniknya.
    expect(await hasEntity(db, 'recurring_rules'), isTrue);
    expect(await hasColumn(db, 'transactions', 'recurring_rule_id'), isTrue);
    expect(await hasEntity(db, 'idx_transactions_recurring_tanggal'), isTrue);

    await db.close();
  });

  test('v2 -> v3: menambah kolom & tabel tanpa menyentuh data lama', () async {
    final seed = AppDatabase(NativeDatabase(file));
    await seed.customStatement(
      "INSERT INTO transactions (id, tipe, nominal, tanggal, biaya_admin, "
      "created_at, updated_at) VALUES ('lama', 'pengeluaran', 5000, 0, 0, 0, 0)",
    );
    // Turunkan ke bentuk v2: belum ada apa pun soal transaksi berulang.
    await seed.customStatement(
      'DROP INDEX IF EXISTS idx_transactions_recurring_tanggal',
    );
    await seed.customStatement('DROP TABLE IF EXISTS recurring_rules');
    await seed.customStatement(
      'ALTER TABLE transactions DROP COLUMN recurring_rule_id',
    );
    await seed.customStatement('PRAGMA user_version = 2');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));

    expect(await hasColumn(db, 'transactions', 'recurring_rule_id'), isTrue);
    expect(await hasEntity(db, 'recurring_rules'), isTrue);
    expect(await hasEntity(db, 'idx_transactions_recurring_tanggal'), isTrue);

    // Transaksi lama tetap ada, penandanya masih kosong.
    final rows = await db.select(db.transactions).get();
    expect(rows.length, 1);
    expect(rows.single.nominal, 5000);
    expect(rows.single.recurringRuleId, isNull);

    // Kolom baru benar-benar bisa dipakai.
    await db.customStatement(
      "UPDATE transactions SET recurring_rule_id = 'r1' WHERE id = 'lama'",
    );
    expect(
      (await db.select(db.transactions).getSingle()).recurringRuleId,
      'r1',
    );

    await db.close();
  });

  test('indeks unik menolak periode yang sama dua kali', () async {
    final db = AppDatabase(NativeDatabase(file));
    const berulang =
        "INSERT INTO transactions (id, tipe, nominal, tanggal, biaya_admin, "
        "created_at, updated_at, recurring_rule_id) "
        "VALUES (?, 'pengeluaran', 1000, 100, 0, 0, 0, 'r1')";

    await db.customStatement(berulang, ['a']);
    await expectLater(db.customStatement(berulang, ['b']), throwsA(anything));

    // Transaksi biasa (tanpa aturan) tidak dibatasi oleh indeks unik itu.
    const manual =
        "INSERT INTO transactions (id, tipe, nominal, tanggal, biaya_admin, "
        "created_at, updated_at) VALUES (?, 'pengeluaran', 1000, 100, 0, 0, 0)";
    await db.customStatement(manual, ['c']);
    await db.customStatement(manual, ['d']);
    expect((await db.select(db.transactions).get()).length, 3);

    await db.close();
  });
}
