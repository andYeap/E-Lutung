package com.elutung.elutung

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import java.io.File
import java.io.FileOutputStream

/**
 * Pra-pemrosesan gambar struk sebelum OCR (Fase 1, offline).
 *
 * Sengaja hanya memakai `android.graphics` tanpa dependensi baru:
 * - downscale ke sisi panjang 1600 px (ML Kit tidak butuh 12 MP; piksel
 *   ekstra hanya memperlambat dan menambah noise),
 * - varian kontras: grayscale + rentang auto (peregangan min-max),
 * - varian biner: ambang Otsu atas grayscale (struk termal kontras tipis).
 *
 * Semua keluaran ditulis ke `cacheDir/receipt_varian/` sebagai JPEG dan
 * dihapus setiap pemanggilan `varian()`, jadi tidak menumpuk.
 */
object ReceiptPreprocessor {
    private const val SISI_PANJANG = 1600

    fun varian(context: Context, sumberPath: String): List<String> {
        val folder = File(context.cacheDir, "receipt_varian")
        folder.listFiles()?.forEach { it.delete() }
        folder.mkdirs()
        val asli = BitmapFactory.decodeFile(sumberPath) ?: return listOf(sumberPath)
        val kecil = kecilkan(asli)
        if (kecil !== asli) asli.recycle()

        val keluar = mutableListOf(sumberPath)
        try {
            val kontras = kontrasOtomatis(kecil)
            val fKontras = File(folder, "kontras.jpg")
            simpan(kontras, fKontras)
            kontras.recycle()
            keluar.add(fKontras.absolutePath)

            val biner = binarisasiOtsu(kecil)
            val fBiner = File(folder, "biner.jpg")
            simpan(biner, fBiner)
            biner.recycle()
            keluar.add(fBiner.absolutePath)
        } catch (_: Exception) {
            // Sebagian gagal: kembalikan yang berhasil saja.
        } finally {
            kecil.recycle()
        }
        return keluar
    }

    fun putar(context: Context, sumberPath: String, derajat: Int): String? {
        return try {
            val bmp = BitmapFactory.decodeFile(sumberPath) ?: return null
            val m = Matrix()
            m.postRotate(derajat.toFloat())
            val hasil = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
            bmp.recycle()
            val folder = File(context.cacheDir, "receipt_varian")
            folder.mkdirs()
            val f = File(folder, "putar-$derajat.jpg")
            simpan(hasil, f)
            hasil.recycle()
            f.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun kecilkan(bmp: Bitmap): Bitmap {
        val panjang = maxOf(bmp.width, bmp.height)
        if (panjang <= SISI_PANJANG) return bmp
        val skala = SISI_PANJANG.toFloat() / panjang
        val w = (bmp.width * skala).toInt().coerceAtLeast(1)
        val h = (bmp.height * skala).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bmp, w, h, true)
    }

    /** Grayscale + peregangan rentang ke 0..255 (auto-kontras). */
    private fun kontrasOtomatis(bmp: Bitmap): Bitmap {
        val w = bmp.width
        val h = bmp.height
        val px = IntArray(w * h)
        bmp.getPixels(px, 0, w, 0, 0, w, h)
        val abu = IntArray(w * h)
        var min = 255
        var maks = 0
        for (i in px.indices) {
            val p = px[i]
            val r = (p shr 16) and 0xFF
            val g = (p shr 8) and 0xFF
            val b = p and 0xFF
            val y = ((r * 299 + g * 587 + b * 114) / 1000).coerceIn(0, 255)
            abu[i] = y
            if (y < min) min = y
            if (y > maks) maks = y
        }
        val rentang = (maks - min).coerceAtLeast(1)
        for (i in px.indices) {
            val y = ((abu[i] - min) * 255 / rentang).coerceIn(0, 255)
            px[i] = (0xFF shl 24) or (y shl 16) or (y shl 8) or y
        }
        val keluar = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        keluar.setPixels(px, 0, w, 0, 0, w, h)
        return keluar
    }

    /** Ambang Otsu: memisahkan tinta struk dari kertas secara adaptif. */
    private fun binarisasiOtsu(bmp: Bitmap): Bitmap {
        val w = bmp.width
        val h = bmp.height
        val px = IntArray(w * h)
        bmp.getPixels(px, 0, w, 0, 0, w, h)
        val abu = IntArray(w * h)
        val hist = IntArray(256)
        for (i in px.indices) {
            val p = px[i]
            val r = (p shr 16) and 0xFF
            val g = (p shr 8) and 0xFF
            val b = p and 0xFF
            val y = ((r * 299 + g * 587 + b * 114) / 1000).coerceIn(0, 255)
            abu[i] = y
            hist[y]++
        }
        val total = (w * h).toDouble()
        var sumSemua = 0.0
        for (t in 0..255) sumSemua += t * hist[t]
        var sumLatar = 0.0
        var hitungLatar = 0
        var ragamMaks = 0.0
        var ambang = 128
        for (t in 0..255) {
            hitungLatar += hist[t]
            if (hitungLatar == 0) continue
            val hitungDepan = w * h - hitungLatar
            if (hitungDepan == 0) break
            sumLatar += t * hist[t]
            val rerataLatar = sumLatar / hitungLatar
            val rerataDepan = (sumSemua - sumLatar) / hitungDepan
            val ragam = hitungLatar * hitungDepan * (rerataLatar - rerataDepan) * (rerataLatar - rerataDepan)
            if (ragam > ragamMaks) {
                ragamMaks = ragam
                ambang = t
            }
        }
        for (i in px.indices) {
            val y = if (abu[i] > ambang) 255 else 0
            px[i] = (0xFF shl 24) or (y shl 16) or (y shl 8) or y
        }
        val keluar = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        keluar.setPixels(px, 0, w, 0, 0, w, h)
        return keluar
    }

    private fun simpan(bmp: Bitmap, tujuan: File) {
        FileOutputStream(tujuan).use { out ->
            bmp.compress(Bitmap.CompressFormat.JPEG, 95, out)
        }
    }
}
