# E-Lutung

Aplikasi pencatat keuangan Android: pemasukan, pengeluaran, dan transfer, lengkap dengan
rekap bulanan, grafik per kategori, batas anggaran berwarna (hijau sampai merah), transaksi
berulang otomatis untuk gaji dan langganan, tema yang bisa kamu sesuaikan sendiri, dan widget
beranda. **100% lokal** — tanpa server, tanpa akun, dan build rilis tidak meminta izin
internet.

Spesifikasi produk final ada di [PRD.md](PRD.md) (versi cetak: [PRD.pdf](PRD.pdf)). Catatan
teknis, keputusan desain, dan jebakan yang perlu dihindari ada di [AGENTS.md](AGENTS.md).

## Kebutuhan

- Flutter stable (diuji dengan 3.47.5, Dart 3.13)
- JDK 17
- Android SDK dengan **minSdk 26**; lisensi SDK sudah disetujui
- Perangkat atau emulator Android 8.0 atau lebih baru

Periksa lingkunganmu dulu:

```bash
flutter doctor -v
```

Bila lisensi Android SDK belum disetujui, jalankan `flutter doctor --android-licenses`.

## Menjalankan

```bash
cd app
flutter pub get
flutter run
```

## Memeriksa dan menguji

```bash
cd app
flutter analyze   # harus 0 issue
flutter test      # 205 test
```

## Membangun APK dan AAB

```bash
cd app
flutter build apk --release                     # satu APK
flutter build appbundle --release               # untuk Play Store
flutter build apk --release --split-per-abi     # APK per arsitektur
```

Hasilnya ada di `app/build/app/outputs/`.

Konfigurasi rilis saat ini memakai **debug signing key** (lihat `app/android/app/build.gradle.kts`)
supaya siapa pun bisa membangun tanpa keystore sendiri. Untuk dipublikasikan ke Play Store,
ganti dengan keystore milikmu lewat `app/android/key.properties` — berkas itu, `*.jks`, dan
`*.keystore` sudah di-ignore oleh git.

## Mengubah skema basis data

`lib/data/database.g.dart` ikut di-commit, jadi hasil clone bersih tidak perlu menjalankan
code generator. Jalankan hanya setelah mengubah tabel Drift:

```bash
cd app
dart run build_runner build
```

Sesudah itu naikkan `schemaVersion` di `lib/data/database.dart` dan tulis langkah migrasinya
di `onUpgrade`. Contoh nyatanya ada di migrasi v1 ke v2 pada berkas yang sama, dan diuji di
`test/migration_test.dart`.

## Struktur

```
PRD.md                  spesifikasi produk final (Bagian 1 sampai 19)
PRD.pdf                 versi cetak dari PRD
AGENTS.md               catatan teknis untuk kontributor dan agen
app/                    proyek Flutter (Android saja)
  lib/data/             skema Drift, repositori, dan logika uang yang murni
  lib/features/         layar per fitur
  lib/services/         kunci aplikasi dan sinkronisasi widget
  lib/widgets/          komponen neobrutalism dan grafik
  test/                 205 test
  android/              proyek Android beserta widget beranda (RemoteViews)
```

## Catatan implementasi

- Nominal uang disimpan sebagai **int rupiah**, bukan pecahan, supaya tidak ada galat
  pembulatan.
- Aturan transfer ada di `lib/data/finance.dart`. Transfer antar akun sendiri bukan
  pengeluaran; yang dicatat hanya biaya adminnya, dan biaya itu masuk kategori
  "Transfer & Admin".
- Rekap bulanan dihitung di SQL, bukan dengan memuat semua transaksi ke memori, dan dijaga
  tetap setara dengan logika murni di Dart oleh `test/sql_aggregate_test.dart`.
- Transaksi berulang dibangkitkan saat aplikasi dibuka dan oleh tugas WorkManager, lalu
  ditandai "dari jadwal" di riwayat. Satu periode tidak pernah tercatat dua kali, dijaga
  indeks unik pada pasangan aturan dan tanggal.
- Tema bisa disesuaikan lewat Pengaturan: pilih preset, lalu setel latar, kartu, border/teks,
  bilah atas, dan aksen secara terpisah untuk mode terang dan gelap. Warna semantik
  (pemasukan, pengeluaran, transfer) sengaja tidak bisa diubah, dan aplikasi menampilkan
  peringatan bila pilihanmu berkontras rendah atau terlalu mirip warna makna.
- Hapus data selalu berupa soft delete ke layar Sampah, jadi masih bisa dipulihkan.
- Build rilis tidak meminta izin `INTERNET`. Varian debug dan profil memintanya karena
  kebutuhan hot reload.
