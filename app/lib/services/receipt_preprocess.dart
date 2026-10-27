import 'package:flutter/services.dart';

/// Jembatan ke pra-pemrosesan gambar di Kotlin (Fase 1).
///
/// Semua pemrosesan piksel ada di `ReceiptPreprocessor.kt` memakai
/// `android.graphics` saja — tanpa dependensi baru, sesuai scope
/// Android-only. Dart hanya memanggil dan menerima path hasilnya.
///
/// Kontrak fallback (penting untuk test host & perangkat tanpa layanan):
/// setiap kegagalan — channel tidak ada, argumen ditolak, timeout —
/// mengembalikan gambar asli apa adanya, sehingga jalur scan hari ini
/// tetap berjalan utuh.
class ReceiptPreprocess {
  ReceiptPreprocess._();

  static const _ch = MethodChannel('elutung/receipt_preprocess');

  /// Nama varian searah dengan urutan daftar yang dikembalikan:
  /// indeks 0 selalu gambar asli (tie-break memilih tanpa distorsi).
  static const varianAsli = 'asli';
  static const varianKontras = 'kontras';
  static const varianBiner = 'biner';

  /// Buat varian gambar untuk OCR multi-varian. Mengembalikan daftar path
  /// dengan gambar asli di indeks 0; bila pra-proses gagal, hanya [sumber].
  static Future<List<String>> buatVarian(String sumber) async {
    try {
      final hasil = await _ch
          .invokeMethod<List<dynamic>>('varian', {'path': sumber})
          .timeout(const Duration(seconds: 5));
      if (hasil == null || hasil.isEmpty) return [sumber];
      final paths = hasil.whereType<String>().toList();
      if (paths.isEmpty) return [sumber];
      // Jaminan kontrak: asli selalu pertama walau Kotlin mengembalikan
      // urutan lain.
      paths.remove(sumber);
      return [sumber, ...paths];
    } catch (_) {
      return [sumber];
    }
  }

  /// Putar gambar [derajat] searah jarum jam (90/180/270). Dipakai sebagai
  /// cadangan kondisional bila tidak ada varian yang `yakin`.
  /// Mengembalikan path hasil atau null bila gagal.
  static Future<String?> putar(String sumber, int derajat) async {
    try {
      final hasil = await _ch
          .invokeMethod<String>('putar', {'path': sumber, 'derajat': derajat})
          .timeout(const Duration(seconds: 5));
      return hasil;
    } catch (_) {
      return null;
    }
  }
}
