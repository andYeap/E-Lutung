import 'database.dart';

/// Perhitungan jadwal transaksi berulang (Bagian 7.6 PRD).
///
/// Sengaja murni dan tanpa akses basis data supaya mudah diuji dan tidak
/// mengandung rumus duplikat di tempat lain.

/// Jumlah hari pada [month] di [year].
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Kemunculan ke-[step] dihitung dari [mulai] (step 0 = [mulai] itu sendiri).
///
/// Untuk bulanan dan tahunan, tanggal acuan diambil dari [mulai] lalu dijepit
/// ke hari terakhir bulan itu bila bulannya lebih pendek. Langkah berikutnya
/// **kembali mengacu ke tanggal asli**, bukan ke hasil jepitan, supaya jadwal
/// tidak bergeser permanen (31 Januari menjadi 28/29 Februari, lalu 31 Maret).
DateTime occurrenceAt(DateTime mulai, Frequency frekuensi, int step) {
  switch (frekuensi) {
    case Frequency.harian:
      return DateTime(
        mulai.year,
        mulai.month,
        mulai.day + step,
        mulai.hour,
        mulai.minute,
      );
    case Frequency.mingguan:
      return DateTime(
        mulai.year,
        mulai.month,
        mulai.day + 7 * step,
        mulai.hour,
        mulai.minute,
      );
    case Frequency.bulanan:
      return _monthStep(mulai, step);
    case Frequency.tahunan:
      return _monthStep(mulai, 12 * step);
  }
}

DateTime _monthStep(DateTime mulai, int months) {
  final total = mulai.month - 1 + months;
  final year = mulai.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = daysInMonth(year, month);
  final day = mulai.day <= lastDay ? mulai.day : lastDay;
  return DateTime(year, month, day, mulai.hour, mulai.minute);
}

/// Kemunculan yang jatuh tempo pada rentang `(afterExclusive, untilInclusive]`.
///
/// Perbandingan memakai **tanggal** (bukan jam), jadi jadwal yang jatuh hari ini
/// tetap terbuat walau jamnya belum lewat. Jumlah hasil dibatasi [maxCount]
/// supaya aturan bertanggal mulai lama tidak membanjiri riwayat sekaligus;
/// sisanya akan menyusul pada pemanggilan berikutnya (FR-12.7).
///
/// [sampai] bersifat inklusif dan memotong rentang lebih awal bila perlu.
List<DateTime> occurrences({
  required DateTime mulai,
  required Frequency frekuensi,
  DateTime? afterExclusive,
  required DateTime untilInclusive,
  DateTime? sampai,
  int maxCount = 100,
}) {
  final limit = _dayOf(untilInclusive);
  final end = sampai != null && _dayOf(sampai).isBefore(limit)
      ? _dayOf(sampai)
      : limit;
  final after = afterExclusive == null ? null : _dayOf(afterExclusive);

  final result = <DateTime>[];
  for (var step = 0; step < 100000 && result.length < maxCount; step++) {
    final occ = occurrenceAt(mulai, frekuensi, step);
    if (_dayOf(occ).isAfter(end)) break;
    if (after != null && !_dayOf(occ).isAfter(after)) continue;
    result.add(occ);
  }
  return result;
}

/// Jatuh tempo berikutnya yang belum dibuat, untuk ditampilkan di daftar
/// aturan. null bila jadwal sudah berakhir atau melewati [sampai].
DateTime? nextDue({
  required DateTime mulai,
  required Frequency frekuensi,
  DateTime? terakhirDibuat,
  DateTime? sampai,
}) {
  final after = terakhirDibuat == null ? null : _dayOf(terakhirDibuat);
  final end = sampai == null ? null : _dayOf(sampai);

  for (var step = 0; step < 100000; step++) {
    final occ = occurrenceAt(mulai, frekuensi, step);
    if (end != null && _dayOf(occ).isAfter(end)) return null;
    if (after == null || _dayOf(occ).isAfter(after)) return occ;
  }
  return null;
}

/// Label frekuensi untuk tampilan.
String frequencyLabel(Frequency f) => switch (f) {
  Frequency.harian => 'Harian',
  Frequency.mingguan => 'Mingguan',
  Frequency.bulanan => 'Bulanan',
  Frequency.tahunan => 'Tahunan',
};
