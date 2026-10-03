import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../data/recurring.dart';

/// Membangkitkan transaksi dari aturan berulang yang sudah jatuh tempo
/// (Bagian FR-12). Dipanggil saat aplikasi dibuka dan oleh tugas WorkManager.
class RecurringRunner {
  RecurringRunner._();

  static const _uuid = Uuid();

  /// Batas jumlah transaksi per aturan sekali jalan (FR-12.7). Sisa periode
  /// yang belum terbuat akan menyusul pada pemanggilan berikutnya.
  static const int maxPerRulePerRun = 100;

  /// Mengembalikan jumlah transaksi yang benar-benar dibuat.
  static Future<int> runDue(AppDatabase db, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final rules =
        await (db.select(db.recurringRules)
              ..where((r) => r.deletedAt.isNull() & r.aktif.equals(true)))
            .get();

    var created = 0;
    for (final rule in rules) {
      final due = occurrences(
        mulai: rule.mulai,
        frekuensi: rule.frekuensi,
        afterExclusive: rule.terakhirDibuat,
        untilInclusive: at,
        sampai: rule.sampai,
        maxCount: maxPerRulePerRun,
      );
      if (due.isEmpty) continue;

      // Satu transaksi basis data: menyisipkan transaksi dan memajukan penanda
      // harus terjadi bersama, kalau tidak aturan bisa terlewat atau ganda.
      await db.transaction(() async {
        for (final tanggal in due) {
          // Lewati yang sudah ada supaya jumlah yang dilaporkan akurat, dan
          // supaya tabrakan indeks unik tidak menggagalkan seluruh proses.
          final existing =
              await (db.select(db.transactions)..where(
                    (t) =>
                        t.recurringRuleId.equals(rule.id) &
                        t.tanggal.equals(tanggal),
                  ))
                  .getSingleOrNull();
          if (existing != null) continue;

          await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: _uuid.v4(),
              tipe: rule.tipe,
              nominal: rule.nominal,
              tanggal: tanggal,
              kategoriId: Value(rule.kategoriId),
              akunId: Value(rule.akunId),
              catatan: Value(rule.catatan),
              recurringRuleId: Value(rule.id),
            ),
            // Jaring pengaman terakhir bila aplikasi dan WorkManager berjalan
            // bersamaan lalu lolos dari pemeriksaan di atas.
            mode: InsertMode.insertOrIgnore,
          );
          created++;
        }

        await (db.update(db.recurringRules)..where(
              (r) => r.id.equals(rule.id),
            ))
            .write(
              RecurringRulesCompanion(
                terakhirDibuat: Value(due.last),
                updatedAt: Value(DateTime.now()),
              ),
            );
      });
    }
    return created;
  }
}
