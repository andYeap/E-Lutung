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
}
