import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../services/receipt_storage.dart';
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

  static const _reminderKey = 'last_backup_reminder_at';

  /// Pengingat cadangan (FR-10.4) yang tidak mengganggu.
  ///
  /// Dulu fungsi ini mengembalikan true selama pengguna belum pernah mengekspor,
  /// sehingga aplikasi baru menagih di **setiap** pembukaan. Sekarang:
  /// - tidak diingatkan bila belum ada data untuk dicadangkan;
  /// - tidak diulang dalam 7 hari;
  /// - dan hanya bila belum pernah mencadangkan atau sudah lewat 30 hari.
  ///
  /// Saat memutuskan untuk mengingatkan, waktu pengingat ikut dicatat.
  static Future<bool> shouldRemindBackup({required bool hasData}) async {
    if (!hasData) return false;
    final now = DateTime.now();
    final last = await lastBackupAt();
    if (last != null && now.difference(last).inDays < 30) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_reminderKey);
      final terakhir = raw == null ? null : DateTime.tryParse(raw);
      if (terakhir != null && now.difference(terakhir).inDays < 7) return false;
      await prefs.setString(_reminderKey, now.toIso8601String());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> dump() async => {
    'version': kBackupVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'institutions': (await _db.select(_db.institutions).get()).map((e) => e.toJson()).toList(),
    'categories': (await _db.select(_db.categories).get()).map((e) => e.toJson()).toList(),
    'accounts': (await _db.select(_db.accounts).get()).map((e) => e.toJson()).toList(),
    'transactions': (await _db.select(_db.transactions).get()).map((e) => e.toJson()).toList(),
    'budgets': (await _db.select(_db.budgets).get()).map((e) => e.toJson()).toList(),
    'debts': (await _db.select(_db.debts).get()).map((e) => e.toJson()).toList(),
    'recurringRules': (await _db.select(_db.recurringRules).get()).map((e) => e.toJson()).toList(),
    'merchantHabits': (await _db.select(_db.merchantHabits).get()).map((e) => e.toJson()).toList(),
  };

  Future<File> exportFile({String? passphrase}) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final payload = await dump();
    final data = (passphrase == null || passphrase.isEmpty)
        ? payload
        : await encryptBackup(payload, passphrase);
    final file = File('${dir.path}/elutung-backup-$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
    return file;
  }

  /// Ekspor lalu buka lembar berbagi sistem. true bila sheet terbuka.
  Future<bool> shareBackup({String? passphrase}) async {
    try {
      final f = await exportFile(passphrase: passphrase);
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
  ///
  /// Mengembalikan -1 (dibatalkan), -2 (butuh kata sandi), 0 (gagal), atau
  /// jumlah baris yang diimpor.
  ///
  /// Memilih dan membaca berkas cadangan **tanpa mengubah data apa pun**.
  ///
  /// Mengembalikan peta cadangan bila berhasil, atau kode galat yang sama
  /// dengan [importFile] (-1 dibatalkan, -2 butuh kata sandi, -3 versi lebih
  /// baru, 0 berkas tidak valid). Dipakai alur impor supaya dampaknya bisa
  /// ditunjukkan lebih dulu.
  Future<Object> bacaBerkas({String? passphrase}) async {
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
      var map = jsonDecode(raw) as Map<String, dynamic>;
      if (isEncryptedBackup(map)) {
        if (passphrase == null || passphrase.isEmpty) return -2;
        map = await decryptBackup(map, passphrase);
      }
      if (!isSupportedBackup(map)) return -3;
      return map;
    } catch (_) {
      return 0;
    }
  }

  Future<int> importFile({required bool replace, String? passphrase}) async {
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
      var map = jsonDecode(raw) as Map<String, dynamic>;
      if (isEncryptedBackup(map)) {
        if (passphrase == null || passphrase.isEmpty) return -2;
        map = await decryptBackup(map, passphrase);
      }
      if (!isSupportedBackup(map)) return -3;
      return await restore(map, replace: replace);
    } catch (_) {
      return 0;
    }
  }

  /// Ringkasan dampak pemulihan sebuah berkas, dihitung tanpa mengubah apa pun.
  ///
  /// Dipakai layar impor untuk memberi tahu lebih dulu apa yang akan terjadi,
  /// karena mode "Gabung" menimpa baris yang id-nya sama dan menghidupkan
  /// kembali yang sudah dihapus, sementara mode "Ganti" menghapus lebih dulu.
  Future<RestorePreview> previewRestore(
    Map<String, dynamic> map, {
    required bool replace,
  }) async {
    if (!isSupportedBackup(map)) {
      return RestorePreview(tambah: 0, timpa: 0, hidupkan: 0, dihapus: 0);
    }
    List<Map<String, dynamic>> rows(String key) =>
        ((map[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    var tambah = 0, timpa = 0, hidupkan = 0, dihapus = 0;

    /// [berkas] dan [lokal] memetakan id ke "masih hidup" (belum dihapus lunak).
    void hitung(Map<String, bool> berkas, Map<String, bool> lokal) {
      for (final e in berkas.entries) {
        final ada = lokal[e.key];
        if (ada == null) {
          tambah++;
          continue;
        }
        timpa++;
        // Di perangkat sudah dihapus, tetapi di berkas masih hidup: setelah
        // dipulihkan, barisnya muncul kembali.
        if (!ada && e.value) hidupkan++;
      }
      if (replace) {
        dihapus += lokal.keys.where((id) => !berkas.containsKey(id)).length;
      }
    }

    Map<String, bool> dariBerkas(String key) => {
      for (final m in rows(key))
        if (m['id'] is String) m['id'] as String: m['deletedAt'] == null,
    };

    hitung(dariBerkas('institutions'), {
      for (final r in await _db.select(_db.institutions).get())
        r.id: r.deletedAt == null,
    });
    hitung(dariBerkas('categories'), {
      for (final r in await _db.select(_db.categories).get())
        r.id: r.deletedAt == null,
    });
    hitung(dariBerkas('accounts'), {
      for (final r in await _db.select(_db.accounts).get())
        r.id: r.deletedAt == null,
    });
    hitung(dariBerkas('recurringRules'), {
      for (final r in await _db.select(_db.recurringRules).get())
        r.id: r.deletedAt == null,
    });
    hitung(dariBerkas('debts'), {
      for (final r in await _db.select(_db.debts).get())
        r.id: r.deletedAt == null,
    });
    hitung(dariBerkas('transactions'), {
      for (final r in await _db.select(_db.transactions).get())
        r.id: r.deletedAt == null,
    });
    hitung(dariBerkas('budgets'), {
      for (final r in await _db.select(_db.budgets).get())
        r.id: r.deletedAt == null,
    });

    // Kebiasaan pedagang tidak punya `deletedAt`; ia selalu dianggap hidup dan
    // tidak pernah "dihidupkan kembali". Kuncinya `pola`, bukan `id`.
    hitung(
      {
        for (final m in rows('merchantHabits'))
          if (m['pola'] is String) m['pola'] as String: true,
      },
      {
        for (final r in await _db.select(_db.merchantHabits).get())
          r.pola: true,
      },
    );

    return RestorePreview(
      tambah: tambah,
      timpa: timpa,
      hidupkan: hidupkan,
      dihapus: dihapus,
    );
  }

  Future<int> restore(
    Map<String, dynamic> map, {
    required bool replace,
  }) async {
    // Tolak berkas yang jelas bukan cadangan E-Lutung, supaya impor "replace"
    // tidak menghapus data master untuk berkas asing atau rusak.
    if (!isSupportedBackup(map) ||
        map['categories'] is! List ||
        map['transactions'] is! List) {
      return 0;
    }

    List<Map<String, dynamic>> rows(String key) =>
        ((map[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    var count = 0;
    await _db.transaction(() async {
      if (replace) {
        // Urutan hapus: anak dulu, induk terakhir (menghormati FK).
        await _db.delete(_db.transactions).go();
        await _db.delete(_db.budgets).go();
        await _db.delete(_db.recurringRules).go();
        await _db.delete(_db.debts).go();
        await _db.delete(_db.merchantHabits).go();
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
      // Kebiasaan pedagang menunjuk kategori & akun, jadi dimasukkan setelah
      // keduanya ada (FK).
      for (final m in rows('merchantHabits')) {
        await _db.into(_db.merchantHabits).insertOnConflictUpdate(MerchantHabit.fromJson(m));
        count++;
      }
      for (final m in rows('recurringRules')) {
        await _db.into(_db.recurringRules).insertOnConflictUpdate(RecurringRule.fromJson(m));
        count++;
      }
      // Catatan utang lebih dulu daripada transaksi: transaksi pelunasan
      // menunjuk ke catatannya (FK).
      for (final m in rows('debts')) {
        await _db.into(_db.debts).insertOnConflictUpdate(Debt.fromJson(m));
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
  ///
  /// Foto struk ikut dihapus. Baris database-nya hilang saja, sementara
  /// berkasnya ada di dokumen aplikasi — tanpa pembersihan ini, "Hapus semua
  /// data" meninggalkan foto pengguna tetap tersimpan di HP tanpa jejak di
  /// aplikasi, dan tidak ada layar yang bisa menemukannya lagi.
  Future<void> wipeUserData() async {
    final paths = await (_db.selectOnly(_db.transactions)
          ..addColumns([_db.transactions.strukPath]))
        .map((row) => row.read(_db.transactions.strukPath))
        .get();

    await _db.transaction(() async {
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.recurringRules).go();
      await _db.delete(_db.merchantHabits).go();
      await _db.delete(_db.accounts).go();
    });

    await ReceiptStorage.hapusSemua(paths);
  }
}

/// Ringkasan dampak pemulihan, dihitung sebelum data apa pun diubah.
class RestorePreview {
  RestorePreview({
    required this.tambah,
    required this.timpa,
    required this.hidupkan,
    required this.dihapus,
  });

  /// Baris di berkas yang belum ada di perangkat ini.
  final int tambah;

  /// Baris yang id-nya sudah ada, sehingga nilainya ditimpa versi dari berkas.
  final int timpa;

  /// Baris yang di perangkat sudah dihapus tetapi di berkas masih hidup, jadi
  /// akan muncul kembali setelah dipulihkan.
  final int hidupkan;

  /// Baris di perangkat yang akan dihapus karena mode "Ganti".
  final int dihapus;

  bool get kosong =>
      tambah == 0 && timpa == 0 && hidupkan == 0 && dihapus == 0;
}

/// Nomor versi format cadangan yang ditulis sekarang. Naikkan bila bentuk
/// cadangannya berubah.
///
/// v2 menambahkan daftar catatan utang/piutang; v3 menambahkan kebiasaan
/// pedagang. Aplikasi versi lama menolak berkas yang lebih baru supaya data
/// yang belum dikenal itu tidak hilang diam-diam saat dipulihkan.
const int kBackupVersion = 3;

/// Apakah cadangan ini bisa dibaca versi aplikasi sekarang.
///
/// Impor menolak berkas dari versi yang lebih baru: kolom yang belum dikenal
/// akan hilang diam-diam, dan pemulihannya tampak berhasil padahal tidak utuh.
bool isSupportedBackup(Map<String, dynamic> map) {
  final version = map['version'];
  return version is int && version <= kBackupVersion;
}

// ---- Enkripsi cadangan (AES-GCM + PBKDF2) ---------------------------------

const String kEncryptedBackupMarker = 'elutungEncrypted';

/// Iterasi PBKDF2 untuk cadangan terkunci, mengikuti anjuran OWASP untuk
/// PBKDF2-HMAC-SHA256. Angka 120.000 adalah nilai lama, yang tetap dibaca
/// karena jumlah iterasinya tersimpan di dalam berkasnya.
const int kBackupIterations = 600000;
const int _kIterasiLama = 120000;

/// Apakah berkas cadangan ini terkunci kata sandi.
bool isEncryptedBackup(Map<String, dynamic> map) =>
    map[kEncryptedBackupMarker] == 1;

/// Membungkus payload cadangan dengan kata sandi pengguna.
Future<Map<String, dynamic>> encryptBackup(
  Map<String, dynamic> payload,
  String passphrase,
) async {
  const iterations = kBackupIterations;
  final salt = _randomBytes(16);
  final key = await _deriveKey(passphrase, salt, iterations);
  final nonce = _randomBytes(12);
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode(payload)),
    secretKey: key,
    nonce: nonce,
  );
  return {
    kEncryptedBackupMarker: 1,
    'kdf': 'pbkdf2-hmac-sha256',
    'iterations': iterations,
    'salt': base64.encode(salt),
    'nonce': base64.encode(nonce),
    'mac': base64.encode(box.mac.bytes),
    'cipher': base64.encode(box.cipherText),
  };
}

/// Membuka cadangan terkunci. Melempar bila kata sandinya salah.
Future<Map<String, dynamic>> decryptBackup(
  Map<String, dynamic> envelope,
  String passphrase,
) async {
  final salt = base64.decode(envelope['salt'] as String);
  final nonce = base64.decode(envelope['nonce'] as String);
  final mac = Mac(base64.decode(envelope['mac'] as String));
  final cipher = base64.decode(envelope['cipher'] as String);
  final iterations = (envelope['iterations'] as num?)?.toInt() ?? _kIterasiLama;
  final key = await _deriveKey(passphrase, salt, iterations);
  final clear = await AesGcm.with256bits().decrypt(
    SecretBox(cipher, nonce: nonce, mac: mac),
    secretKey: key,
  );
  return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
}

Future<SecretKey> _deriveKey(
  String passphrase,
  List<int> salt,
  int iterations,
) =>
    Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
        .deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);

List<int> _randomBytes(int n) {
  final r = Random.secure();
  return List<int>.generate(n, (_) => r.nextInt(256));
}
