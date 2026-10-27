package com.elutung.elutung

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FragmentActivity tidak lagi diperlukan sejak fitur kunci aplikasi (local_auth)
// dihapus atas permintaan pengguna. Bila suatu saat menambah plugin yang
// membutuhkannya, ubah kembali ke FlutterFragmentActivity.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Pra-pemrosesan gambar struk (Fase 1): varian kontras/biner + putar
        // cadangan. Murni android.graphics, tanpa dependensi baru.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "elutung/receipt_preprocess",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "varian" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("ARG", "path wajib diisi", null)
                    } else {
                        try {
                            result.success(ReceiptPreprocessor.varian(this, path))
                        } catch (e: Exception) {
                            result.success(listOf(path))
                        }
                    }
                }
                "putar" -> {
                    val path = call.argument<String>("path")
                    val derajat = (call.argument<Int>("derajat") ?: 0)
                    if (path == null) {
                        result.error("ARG", "path wajib diisi", null)
                    } else {
                        try {
                            val keluar = ReceiptPreprocessor.putar(this, path, derajat)
                            if (keluar == null) {
                                result.error("GAGAL", "putar gagal", null)
                            } else {
                                result.success(keluar)
                            }
                        } catch (e: Exception) {
                            result.error("GAGAL", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
