import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'database.dart';

/// Ekspor/impor seluruh data (Bagian FR-10). Cadangan berbentuk satu file JSON.
class BackupService {
  BackupService(this._db);
  final AppDatabase _db;

  static const _lastBackupKey = 'last_backup_at';

  /// Kapan terakhir mencadangkan (FR-10.4).
  static Future<DateTime?> lastBackupAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastBackupKey);
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Tandai sudah mencadangkan.
  static Future<void> markBackedUp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// True bila belum pernah atau sudah >30 hari (pengingat cadangan).
  static Future<bool> shouldRemindBackup() async {
    final last = await lastBackupAt();
    if (last == null) return true;
    return DateTime.now().difference(last).inDays >= 30;
  }

  Future<Map<String, dynamic>> dump() async => {
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'institutions': (await _db.select(_db.institutions).get()).map((e) => e.toJson()).toList(),
    'categories': (await _db.select(_db.categories).get()).map((e) => e.toJson()).toList(),
    'accounts': (await _db.select(_db.accounts).get()).map((e) => e.toJson()).toList(),
    'transactions': (await _db.select(_db.transactions).get()).map((e) => e.toJson()).toList(),
    'budgets': (await _db.select(_db.budgets).get()).map((e) => e.toJson()).toList(),
    'recurringRules': (await _db.select(_db.recurringRules).get()).map((e) => e.toJson()).toList(),
  };

  Future<File> exportFile() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/elutung-backup-$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(await dump()),
    );
    return file;
  }

  /// Ekspor lalu buka lembar berbagi sistem. true bila sheet terbuka.
  Future<bool> shareBackup() async {
    try {
      final f = await exportFile();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path)], subject: 'Cadangan E-Lutung'),
      );
      await markBackedUp();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ekspor CSV transaksi untuk spreadsheet (FR-10.3).
  Future<File> exportCsvFile() async {
    final txs = await (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final cats = await _db.select(_db.categories).get();
    final accounts = await _db.select(_db.accounts).get();
    final insts = await _db.select(_db.institutions).get();

    final catName = {for (final c in cats) c.id: c.nama};
    final instName = {for (final i in insts) i.id: i.nama};
    final accLabel = {
      for (final a in accounts) a.id: (instName[a.institusiId] ?? '?'),
    };

    String cell(String s) => '"${s.replaceAll('"', '""')}"';
    final rows = <List<String>>[
      ['tanggal', 'tipe', 'kategori', 'akun', 'akun_asal', 'akun_tujuan', 'nominal', 'biaya_admin', 'catatan'],
    ];
    final sorted = [...txs]..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    for (final t in sorted) {
      rows.add([
        t.tanggal.toIso8601String(),
        t.tipe.name,
        catName[t.kategoriId] ?? '',
        accLabel[t.akunId] ?? '',
        accLabel[t.akunAsalId] ?? '',
        accLabel[t.akunTujuanId] ?? '',
        '${t.nominal}',
        '${t.biayaAdmin}',
        (t.catatan ?? '').replaceAll('\n', ' '),
      ]);
    }
    final csv = rows.map((r) => r.map(cell).join(',')).join('\n');

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/elutung-transaksi-$stamp.csv');
    await file.writeAsString(csv, encoding: utf8);
    return file;
  }

  /// Ekspor CSV lalu bagikan.
  Future<bool> shareCsv() async {
    try {
      final f = await exportCsvFile();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path)], subject: 'Transaksi E-Lutung (CSV)'),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Impor dari file yang dipilih pengguna.
  Future<int> importFile({required bool replace}) async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null) return -1;
      final path = picked.path;
      if (path == null) return 0;
      final raw = await File(path).readAsString();
      if (raw.isEmpty) return 0;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return await restore(map, replace: replace);
    } catch (_) {
      return 0;
    }
  }

  Future<int> restore(
    Map<String, dynamic> map, {
    required bool replace,
  }) async {
    List<Map<String, dynamic>> rows(String key) =>
        ((map[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    var count = 0;
    await _db.transaction(() async {
      if (replace) {
        // Urutan hapus: anak dulu, induk terakhir (menghormati FK).
        await _db.delete(_db.transactions).go();
        await _db.delete(_db.budgets).go();
        await _db.delete(_db.recurringRules).go();
        await _db.delete(_db.accounts).go();
        await _db.delete(_db.categories).go();
        await _db.delete(_db.institutions).go();
      }
      for (final m in rows('institutions')) {
        await _db.into(_db.institutions).insertOnConflictUpdate(Institution.fromJson(m));
        count++;
      }
      for (final m in rows('categories')) {
        await _db.into(_db.categories).insertOnConflictUpdate(Category.fromJson(m));
        count++;
      }
      for (final m in rows('accounts')) {
        await _db.into(_db.accounts).insertOnConflictUpdate(Account.fromJson(m));
        count++;
      }
      for (final m in rows('recurringRules')) {
        await _db.into(_db.recurringRules).insertOnConflictUpdate(RecurringRule.fromJson(m));
        count++;
      }
      for (final m in rows('transactions')) {
        await _db.into(_db.transactions).insertOnConflictUpdate(Transaction.fromJson(m));
        count++;
      }
      for (final m in rows('budgets')) {
        await _db.into(_db.budgets).insertOnConflictUpdate(Budget.fromJson(m));
        count++;
      }
    });
    return count;
  }

  /// Hapus data pengguna (transaksi, anggaran, akun). Master institusi &
  /// kategori dipertahankan agar aplikasi tetap bisa dipakai (FR-11.4).
  Future<void> wipeUserData() async {
    await _db.transaction(() async {
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.recurringRules).go();
      await _db.delete(_db.accounts).go();
    });
  }
}
