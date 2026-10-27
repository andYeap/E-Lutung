import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/receipt.dart';
import '../data/receipt_layout.dart';
import '../data/receipt_score.dart';
import 'receipt_preprocess.dart';

/// Hasil satu kali pindai: teks pemenang, draft-nya, dan dari mana asalnya.
class HasilScan {
  const HasilScan({
    required this.teks,
    required this.draft,
    required this.varian,
    required this.garis,
  });

  final String teks;
  final ReceiptDraft draft;

  /// Nama varian pemenang (`asli`/`kontras`/`biner`/`putar-90`...).
  final String varian;

  /// Geometri baris OCR pemenang (untuk diagnostik layar uji).
  final List<BarisOcr> garis;
}

/// Membaca teks dari foto struk **di perangkat** (offline) memakai ML Kit.
///
/// Tidak ada gambar yang dikirim keluar. Bila perangkat tidak punya layanan
/// yang dibutuhkan ML Kit, pemanggil menangkap galat dan pengguna mengisi
/// nominalnya secara manual.
class ReceiptScanner {
  ReceiptScanner._();

  /// Batas total satu kali pindai (Fase 1): ±3 detik sesuai keputusan.
  /// Varian diproses berurutan dan berhenti lebih awal bila waktu habis;
  /// yang sudah selesai tetap dipilih pemenangnya.
  static const batasPindai = Duration(seconds: 3);

  static Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  /// Pindai multi-varian: pra-proses → OCR tiap varian → pilih parse terbaik.
  ///
  /// Urutan varian: asli dulu (indeks 0 = tie-break), lalu kontras, biner.
  /// Bila tidak ada yang `yakin` dan waktu masih ada, coba putar 90/180/270
  /// satu per satu sampai ada yang yakin atau waktu habis.
  static Future<HasilScan> scanTerbaik(
    String imagePath, {
    Duration batas = batasPindai,
  }) async {
    final tenggat = DateTime.now().add(batas);
    var varianPaths = [imagePath];
    try {
      varianPaths = await ReceiptPreprocess.buatVarian(imagePath)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      varianPaths = [imagePath];
    }
    const namaVarian = [
      ReceiptPreprocess.varianAsli,
      ReceiptPreprocess.varianKontras,
      ReceiptPreprocess.varianBiner,
    ];

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    HasilScan? terbaik;
    var skorTerbaik = -1;
    try {
      for (var i = 0; i < varianPaths.length; i++) {
        if (DateTime.now().isAfter(tenggat)) break;
        final hasil = await _pindaiSatu(recognizer, varianPaths[i]);
        if (hasil == null) continue;
        final nama = i < namaVarian.length ? namaVarian[i] : 'varian-$i';
        final skor = skorDraft(hasil.draft);
        if (skor > skorTerbaik) {
          skorTerbaik = skor;
          terbaik = HasilScan(
            teks: hasil.teks,
            draft: hasil.draft,
            varian: nama,
            garis: hasil.garis,
          );
          if (hasil.draft.yakin && i == 0) break; // asli langsung yakin: selesai.
        }
      }
      // Cadangan kondisional: rotasi hanya bila belum ada yang yakin.
      if ((terbaik == null || !terbaik.draft.yakin) &&
          DateTime.now().isBefore(tenggat)) {
        for (final derajat in const [90, 180, 270]) {
          if (DateTime.now().isAfter(tenggat)) break;
          String? putar;
          try {
            putar = await ReceiptPreprocess.putar(imagePath, derajat)
                .timeout(const Duration(seconds: 5));
          } catch (_) {
            putar = null;
          }
          if (putar == null) continue;
          final hasil = await _pindaiSatu(recognizer, putar);
          if (hasil == null) continue;
          final skor = skorDraft(hasil.draft);
          if (skor > skorTerbaik) {
            skorTerbaik = skor;
            terbaik = HasilScan(
              teks: hasil.teks,
              draft: hasil.draft,
              varian: 'putar-$derajat',
              garis: hasil.garis,
            );
            if (hasil.draft.yakin) break;
          }
        }
      }
    } finally {
      await recognizer.close();
    }
    if (terbaik != null) return terbaik;
    // Seluruh OCR gagal (mis. ML Kit tidak ada): kembalikan kosong, bukan galat,
    // supaya layar menampilkan quality gate, bukan snackbar merah.
    return const HasilScan(teks: '', draft: ReceiptDraft(), varian: 'asli', garis: []);
  }

  /// OCR satu berkas + parse ganda (mentah vs gabung-dua-kolom), ambil yang
  /// skornya lebih tinggi. Null bila OCR-nya sendiri gagal.
  static Future<HasilScan?> _pindaiSatu(
    TextRecognizer recognizer,
    String path,
  ) async {
    try {
      final input = InputImage.fromFilePath(path);
      final result = await recognizer.processImage(input);
      final garis = _keBarisOcr(result);
      final mentah = result.text;
      final gabung = gabungDuaKolom(mentah, garis);
      final d1 = parseReceipt(mentah);
      final d2 = gabung == mentah ? d1 : parseReceipt(gabung);
      if (skorDraft(d2) > skorDraft(d1)) {
        return HasilScan(teks: gabung, draft: d2, varian: '', garis: garis);
      }
      return HasilScan(teks: mentah, draft: d1, varian: '', garis: garis);
    } catch (_) {
      return null;
    }
  }

  /// Ubah `lines` ML Kit menjadi [BarisOcr] murni (tanpa Flutter di hilir).
  static List<BarisOcr> _keBarisOcr(RecognizedText hasil) {
    final keluar = <BarisOcr>[];
    for (final blok in hasil.blocks) {
      for (final baris in blok.lines) {
        final r = baris.boundingBox;
        keluar.add(
          BarisOcr(
            teks: baris.text,
            kiri: r.left.toDouble(),
            atas: r.top.toDouble(),
            kanan: r.right.toDouble(),
            bawah: r.bottom.toDouble(),
          ),
        );
      }
    }
    return keluar;
  }
}
