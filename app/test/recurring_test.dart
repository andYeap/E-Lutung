import 'package:elutung/data/database.dart';
import 'package:elutung/data/recurring.dart';
import 'package:flutter_test/flutter_test.dart';

/// Matematika jadwal transaksi berulang (Bagian 7.6 PRD). Ini bagian paling
/// rawan salah, terutama penjepitan akhir bulan dan tahun kabisat.
void main() {
  group('occurrenceAt', () {
    test('harian dan mingguan menambah hari', () {
      final m = DateTime(2026, 3, 1, 9, 30);
      expect(occurrenceAt(m, Frequency.harian, 3), DateTime(2026, 3, 4, 9, 30));
      expect(
        occurrenceAt(m, Frequency.mingguan, 2),
        DateTime(2026, 3, 15, 9, 30),
      );
    });

    test('bulanan menjepit ke akhir bulan, acuan tetap tanggal asli', () {
      final m = DateTime(2026, 1, 31);
      expect(occurrenceAt(m, Frequency.bulanan, 1), DateTime(2026, 2, 28));
      // Kembali ke 31, bukan menempel di 28.
      expect(occurrenceAt(m, Frequency.bulanan, 2), DateTime(2026, 3, 31));
      expect(occurrenceAt(m, Frequency.bulanan, 3), DateTime(2026, 4, 30));
      expect(occurrenceAt(m, Frequency.bulanan, 4), DateTime(2026, 5, 31));
    });

    test('tahun kabisat', () {
      expect(
        occurrenceAt(DateTime(2024, 1, 31), Frequency.bulanan, 1),
        DateTime(2024, 2, 29),
      );
      expect(
        occurrenceAt(DateTime(2024, 2, 29), Frequency.tahunan, 1),
        DateTime(2025, 2, 28),
      );
      // Kembali ke 29 Februari pada tahun kabisat berikutnya.
      expect(
        occurrenceAt(DateTime(2024, 2, 29), Frequency.tahunan, 4),
        DateTime(2028, 2, 29),
      );
    });

    test('bulanan melintasi pergantian tahun', () {
      expect(
        occurrenceAt(DateTime(2026, 11, 15), Frequency.bulanan, 3),
        DateTime(2027, 2, 15),
      );
    });
  });

  group('occurrences', () {
    test('mengambil yang jatuh tempo, batas atas inklusif', () {
      final due = occurrences(
        mulai: DateTime(2026, 1, 10),
        frekuensi: Frequency.bulanan,
        untilInclusive: DateTime(2026, 3, 10),
      );
      expect(due, [
        DateTime(2026, 1, 10),
        DateTime(2026, 2, 10),
        DateTime(2026, 3, 10),
      ]);
    });

    test('afterExclusive melewati yang sudah pernah dibuat', () {
      final due = occurrences(
        mulai: DateTime(2026, 1, 10),
        frekuensi: Frequency.bulanan,
        afterExclusive: DateTime(2026, 1, 10),
        untilInclusive: DateTime(2026, 3, 10),
      );
      expect(due, [DateTime(2026, 2, 10), DateTime(2026, 3, 10)]);
    });

    test('sampai memotong jadwal', () {
      final due = occurrences(
        mulai: DateTime(2026, 1, 10),
        frekuensi: Frequency.bulanan,
        untilInclusive: DateTime(2026, 12, 31),
        sampai: DateTime(2026, 3, 10),
      );
      expect(due.length, 3);
      expect(due.last, DateTime(2026, 3, 10));
    });

    test('maxCount membatasi, sisanya menyusul', () {
      final due = occurrences(
        mulai: DateTime(2026, 1, 1),
        frekuensi: Frequency.harian,
        untilInclusive: DateTime(2026, 12, 31),
        maxCount: 10,
      );
      expect(due.length, 10);
      expect(due.first, DateTime(2026, 1, 1));
      expect(due.last, DateTime(2026, 1, 10));
    });

    test('jadwal hari ini ikut walau jamnya belum lewat', () {
      final due = occurrences(
        mulai: DateTime(2026, 1, 10, 20),
        frekuensi: Frequency.bulanan,
        untilInclusive: DateTime(2026, 1, 10, 6),
      );
      expect(due, [DateTime(2026, 1, 10, 20)]);
    });
  });

  group('nextDue', () {
    test('null bila jadwal sudah melewati batas', () {
      expect(
        nextDue(
          mulai: DateTime(2026, 1, 1),
          frekuensi: Frequency.bulanan,
          terakhirDibuat: DateTime(2026, 3, 1),
          sampai: DateTime(2026, 3, 1),
        ),
        isNull,
      );
    });

    test('kemunculan pertama bila belum pernah dibuat', () {
      expect(
        nextDue(mulai: DateTime(2026, 1, 1), frekuensi: Frequency.bulanan),
        DateTime(2026, 1, 1),
      );
    });

    test('jatuh tempo setelah yang terakhir dibuat', () {
      expect(
        nextDue(
          mulai: DateTime(2026, 1, 1),
          frekuensi: Frequency.bulanan,
          terakhirDibuat: DateTime(2026, 1, 1),
        ),
        DateTime(2026, 2, 1),
      );
    });
  });
}
