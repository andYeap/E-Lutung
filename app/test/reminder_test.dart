import 'package:elutung/data/backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengingat cadangan (FR-10.4).
///
/// Dulu pengingat berbunyi di **setiap** pembukaan selama pengguna belum pernah
/// mengekspor, sehingga aplikasi baru terasa menagih terus. Sekarang ada tiga
/// penjaga: harus ada data, tidak diulang dalam 7 hari, dan hanya bila belum
/// pernah mencadangkan atau sudah lewat 30 hari.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tidak mengingatkan bila belum ada data untuk dicadangkan', () async {
    expect(await BackupService.shouldRemindBackup(hasData: false), isFalse);
  });

  test('mengingatkan sekali, lalu diam dalam 7 hari', () async {
    expect(await BackupService.shouldRemindBackup(hasData: true), isTrue);
    expect(await BackupService.shouldRemindBackup(hasData: true), isFalse);
  });

  test('tidak mengingatkan bila baru saja mencadangkan', () async {
    SharedPreferences.setMockInitialValues({
      'last_backup_at': DateTime.now().toIso8601String(),
    });
    expect(await BackupService.shouldRemindBackup(hasData: true), isFalse);
  });

  test('pengingat berbunyi lagi setelah lewat 30 hari', () async {
    SharedPreferences.setMockInitialValues({
      'last_backup_at': DateTime.now()
          .subtract(const Duration(days: 40))
          .toIso8601String(),
    });
    expect(await BackupService.shouldRemindBackup(hasData: true), isTrue);
  });

  test('sudah pernah mencadangkan tapi belum 30 hari: tidak berbunyi', () async {
    SharedPreferences.setMockInitialValues({
      'last_backup_at': DateTime.now()
          .subtract(const Duration(days: 3))
          .toIso8601String(),
    });
    expect(await BackupService.shouldRemindBackup(hasData: true), isFalse);
  });
}
