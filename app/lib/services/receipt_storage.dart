import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Menyimpan foto struk di dokumen aplikasi (privat, tidak ikut cadangan JSON).
class ReceiptStorage {
  ReceiptStorage._();

  static const _uuid = Uuid();

  /// Menyalin foto dari sumber sementara ke dokumen aplikasi, mengembalikan
  /// path salinannya.
  static Future<String> simpan(String sumberPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/struk');
    if (!await folder.exists()) await folder.create(recursive: true);
    final tujuan = '${folder.path}/${_uuid.v4()}${_ekstensi(sumberPath)}';
    await File(sumberPath).copy(tujuan);
    return tujuan;
  }

  /// Menghapus foto struk bila ada. Aman dipanggil dengan null.
  static Future<void> hapus(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Abaikan — foto mungkin sudah tidak ada.
    }
  }

  static String _ekstensi(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.jpg';
    final e = path.substring(dot).toLowerCase();
    return e.length <= 5 ? e : '.jpg';
  }

  /// Apakah file di [path] benar-benar ada.
  ///
  /// `strukPath` bisa menunjuk ke berkas yang sudah hilang: gambar tidak ikut
  /// cadangan JSON, jadi setelah ekspor lalu impor, path-nya masih ada tapi
  /// berkasnya tidak. Layar Foto struk memakai ini untuk membedakan "tidak ada
  /// struk" dari "struk hilang".
  static bool ada(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Ukuran berkas dalam byte, atau 0 bila tidak ada / tidak terbaca.
  static int ukuran(String? path) {
    if (!ada(path)) return 0;
    try {
      return File(path!).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  /// Jumlah seluruh foto struk, dalam byte.
  ///
  /// Dipakai untuk memberi tahu pengguna berapa ruang yang dipakai foto struk
  /// di Pengaturan — satu-satunya bagian aplikasi yang memang menyimpan berkas
  /// besar, dan tidak ikut dalam ekspor cadangan.
  ///
  /// Sinkron supaya bisa dipanggil langsung dari `build`. Jumlah berkas biasanya
  /// kecil (puluhan), jadi biayanya tidak terasa.
  static int totalUkuranSync(Iterable<String?> paths) {
    var total = 0;
    for (final p in paths) {
      total += ukuran(p);
    }
    return total;
  }

  /// Format ukuran berkas untuk ditampilkan ("1,2 MB").
  static String formatUkuran(int byte) {
    if (byte < 1024) return '$byte B';
    if (byte < 1024 * 1024) return '${(byte / 1024).toStringAsFixed(0)} KB';
    return '${(byte / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Menghapus banyak berkas sekaligus, mengabaikan yang sudah tidak ada.
  static Future<void> hapusSemua(Iterable<String?> paths) async {
    for (final p in paths) {
      await hapus(p);
    }
  }
}
