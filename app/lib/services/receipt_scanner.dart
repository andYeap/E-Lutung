import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Membaca teks dari foto struk **di perangkat** (offline) memakai ML Kit.
///
/// Tidak ada gambar yang dikirim keluar. Bila perangkat tidak punya layanan
/// yang dibutuhkan ML Kit, pemanggil menangkap galat dan pengguna mengisi
/// nominalnya secara manual.
class ReceiptScanner {
  ReceiptScanner._();

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
}
