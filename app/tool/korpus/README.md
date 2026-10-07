# Korpus struk

Tujuan: mengukur ketepatan `parseReceipt` (`lib/data/receipt.dart`) pada struk **nyata**,
bukan pada teks contoh yang sudah dipakai menulis aturannya sendiri.

## Kenapa teksnya harus datang dari HP

Mesin OCR (ML Kit) hanya berjalan di perangkat Android. Teks hasil scan tidak bisa dihasilkan
dari mesin pengembang, jadi berkas di `teks/` harus berasal dari hasil scan di HP.

## Cara mengumpulkan teks

Ada dua jalur. Yang dipakai: **kirim lewat Telegram** (tanpa kabel, tanpa membangun fitur
ekspor lebih dulu).

### Jalur Telegram (dipakai)

Tidak perlu membuat berkas. Pesan biasa sudah cukup, dan beberapa struk boleh dikirim dalam
satu pesan selama masing-masing didahului satu baris nama.

1. Buka layar **Scan struk** di HP dan pilih fotonya.
2. Buka panel **"Lihat teks hasil scan"**.
3. Kirim ke bot Telegram proyek ini sebagai pesan biasa, dengan bentuk:

   ```
   ### alfamart-01
   (teks OCR apa adanya, sebanyak apa pun barisnya)

   ### indomaret-02
   (teks OCR apa adanya)
   ```

   Baris `### nama` menjadi kunci di `harapan.json` dan nama berkas di `teks/`. Nama harus
   unik, tapi tidak harus cocok dengan nama berkas foto — asisten mencocokkan teks ke foto di
   `~/E-Lutung/Sampel-Struk/` berdasarkan isinya.

4. Satu pesan Telegram dipotong di 4096 karakter, jadi kirim beberapa pesan bila perlu, atau
   biarkan aplikasi Telegram memotongnya sendiri — pembatas `### nama` tetap membagi teks
   dengan benar.
5. Asisten mengambil kiriman itu lewat Telegram Bot API (`getUpdates`), memecahnya per baris
   nama, dan menyimpannya ke `teks/<nama>.txt`.

Jawaban benar di `harapan.json` boleh dari pengirim, boleh juga disusun asisten dengan
membaca foto di `~/E-Lutung/Sampel-Struk/` lalu diperiksa pengirim.

### Jalur salin manual (cadangan)

1. Buka layar **Scan struk** di HP dan pilih fotonya.
2. Buka panel **"Lihat teks hasil scan"**.
3. Salin seluruh teksnya, lalu simpan sebagai `teks/<nama>.txt` di folder ini.
4. Tambahkan harapannya di `harapan.json`.

### Jangan dirapikan

Teks yang masuk **harus apa adanya**, termasuk salah baca, huruf tertukar, label yang
terpisah dari angkanya, dan baris yang kacau. Justru kekacauan itulah yang hendak diukur.
Teks yang dirapikan lebih dulu membuat korpus tidak lagi mencerminkan struk nyata, dan
angkanya jadi menyesatkan.

Nama berkas sebaiknya menggambarkan sumbernya, misalnya `alfamart-01.txt`,
`indomaret-02.txt`, `warung-bu-ani.txt`.

## Format `harapan.json`

```json
{
  "alfamart-01": {
    "nominal": 110000,
    "tanggal": "2026-05-12",
    "merchant": "ALFAMART"
  },
  "restoran-03": {
    "nominal": null,
    "tanggal": null,
    "merchant": "RM SEDERHANA"
  }
}
```

Aturan penting:

- **`null` berarti "harus kosong"**, sengaja dibedakan dari salah. Parser memang dirancang
  mengosongkan nilai yang meragukan daripada menebak.
- Kunci JSON harus sama dengan nama berkas tanpa `.txt`.
- `tanggal` dalam bentuk `YYYY-MM-DD`. Gunakan `null` bila struknya memang tidak mencetak
  tanggal yang terbaca.
- `merchant`: tulis apa yang menurutmu wajar diharapkan, bukan harus sama persis dengan
  cetakan struk. Bila nama merchant di struk berupa badan hukum yang panjang, itu tetap
  dianggap benar.

## Aturan penilaian

- **Nominal salah = 0.** Ini syarat wajib. Dalam aplikasi uang, angka yang yakin tapi salah
  lebih berbahaya daripada kosong.
- **Kosong tidak dihitung salah**, tetapi jumlahnya dicatat sebagai angka acuan dan harus
  dibandingkan sebelum-sesudah setiap perubahan parser.
- Tanggal dan merchant dinilai terpisah dari nominal.

## Yang membuat korpus ini berguna

- Ambil struk dari **toko yang berbeda-beda**, bukan satu toko langganan terus, supaya
  aturannya tidak menjadi pas untuk satu format saja.
- Sertakan yang **sulit**: struk pudar, struk terlipat, struk minimarket dengan beberapa baris
  "Total", dan struk dengan diskon atau pajak.
- Setiap kali menemukan struk yang salah baca di HP, tambahkan teksnya ke sini supaya
  kesalahan itu tidak kembali lagi.
