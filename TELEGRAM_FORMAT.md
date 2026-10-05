# Format Pesan untuk Telegram

Aturan agar keluaran enak dibaca di layar HP.

## Gaya penulisan (utama)

- Kalimat pendek. Satu ide per baris.
- Beri satu baris kosong antarpoin.
- Hindari tebal berlebihan; tebal hanya untuk istilah kunci.
- Jangan selipkan rujukan file/baris di tengah kalimat — taruh terpisah bila perlu.
- Jaga pesan tetap ringkas; sisanya tahan atau ringkas jadi poin.
- Jangan pakai tabel, heading `#`, atau garis `---`.

## Daftar

- Pakai `1.` untuk langkah berurutan, `-` atau `•` untuk poin biasa.
- Jangan bersarang lebih dari satu tingkat.

## Penekanan

- Tebal: `*teks*` (satu bintang, bukan `**teks**`).
- Miring: `_teks_`.
- Kode: `` `teks` ``. Blok kode: tiga backtick.

## Yang tidak didukung Telegram

- `#` heading
- tabel markdown
- garis pemisah `---`
- `[teks](url)` bila ragu — cukup tulis URL mentah

## Tergantung `parse_mode` bot pengirim

- `Markdown` — aturan di atas sudah cukup.
- `MarkdownV2` — karakter `. ! - ( ) # + = | { } ~` wajib di-escape dengan `\` di luar code.
- `HTML` — lebih toleran: `<b>teks</b>`, `<i>`, `<code>`.
- `parse_mode` dimatikan — tebal mustahil; harus diaktifkan di sisi bot.
