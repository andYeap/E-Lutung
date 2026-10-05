# AGENTS.md — E-Lutung (Flutter, Android-only, 100% lokal)

Aplikasi pencatat keuangan (pemasukan/pengeluaran/transfer, rekap bulanan, grafik per
kategori, anggaran berwarna, widget beranda). **Sumber kebenaran = `./PRD.md`** (versi PDF di
`./PRD.pdf`); implementasi ada di `./app`.

## Structure

- `~/E-Lutung/PRD.md` — PRD final (Bagian 1–19). Semua keputusan desain mengacu ke sini.
- `~/E-Lutung/app/` — proyek Flutter (hanya Android).
  - `lib/main.dart` — bootstrap: `ensureIntlLocale()` → edge-to-edge → Workmanager init → `ThemeController.load()` → `Onboarding.load()` → `runApp`.
  - `lib/app.dart` — `MaterialApp` (+ delegate lokal `id`/`en`, clamp textScaler 0.8–1.4) → `OnboardingGate` → `ShellScreen`, dibungkus `AnnotatedRegion` untuk chrome sistem.
  - `lib/providers.dart` — Riverpod: `databaseProvider`, 6 repository, `*Provider` stream, `ownAccountIdsProvider`, `backupServiceProvider`, agregat rekap.
  - `lib/features/shell.dart` — juga pemilik **satu tombol tambah** (`_buildFab`) untuk Dashboard, Riwayat, dan Anggaran; Rekap tidak punya. Lihat gotcha 19.
  - `lib/data/database.dart` (+ `.g.dart`) — skema Drift + **seed** institusi & kategori di `onCreate`.
  - `lib/data/finance.dart` — logika **murni & teruji**: aturan transfer, `computeTotals`, `expenseByCategory`, `monthlySeries`, `accountBalance`, `budgetUsageOf`.
  - `lib/data/recurring.dart` — matematika jadwal berulang (murni, teruji): `occurrenceAt`, `occurrences`, `nextDue`, `daysInMonth`. Penjepitan akhir bulan selalu mengacu ke tanggal asli `mulai`, bukan hasil jepitan.
  - `lib/data/backup.dart` — ekspor/impor JSON, ekspor CSV, `wipeUserData`, pengingat cadangan.
  - `lib/theme/neo_palette.dart` — [NeoPalette] (bg/surface/ink/appBar/accent), `NeoToken`, preset bawaan, dan warna semantik yang terkunci (`kSemanticColors`).
  - `lib/util/contrast.dart` — rasio kontras WCAG, `readableOn` (memilih teks gelap/terang), `miripWarnaSemantik`, dan `paletteWarnings`.
  - `lib/data/repositories/*` — institution, category, account, transaction, budget, recurring. **Semua** punya `watchDeleted()` + `restore()` (soft delete).
  - `lib/features/*` — `shell.dart` (bottom nav 4 tab + Pengaturan + penanganan klik widget), `onboarding_screen.dart` (`OnboardingGate`, sekali saja), `dashboard_screen`, `transactions/*`, `recap/recap_screen`, `budget/budget_screen`, `recurring/recurring_screen`, `theme/theme_screen`, `institutions_screen`, `accounts_screen`, `categories_screen`, `trash_screen`.
  - `lib/widgets/neo.dart` — `NeoCard/NeoButton/NeoTextField` + `NeoLoading`/`NeoError` (keadaan memuat/gagal bergaya neobrutalism).
  - `lib/services/widget_sync.dart` — tulis data ke widget + `requestPin`.
  - `lib/services/recurring_runner.dart` — `RecurringRunner.runDue()`: bangkitkan transaksi dari aturan yang jatuh tempo. Dipanggil `ShellScreen` saat aplikasi dibuka dan `widgetCallbackDispatcher` (WorkManager).
  - `lib/theme/app_theme.dart` — token `Neo` (neobrutalism lembut) + `AppTheme.light()/dark()`.
  - `lib/util/` — `format.dart` (rupiah, `ThousandsInputFormatter`, `ensureIntlLocale`), `budget.dart` (level warna), `color.dart`, `labels.dart`.
  - `lib/widgets/neo.dart` — `NeoCard/NeoButton/NeoTextField`; `charts.dart` — `ExpenseDonut/MonthlyBars/NetTrendChart`.
  - `android/app/src/main/kotlin/com/elutung/elutung/` — `MainActivity.kt` (memakai `FlutterActivity`), `ElutungWidgetProvider.kt`.
  - `android/app/src/main/res/{layout/widget_elutung.xml, xml/widget_elutung_info.xml, drawable/widget_bg.xml}`.
  - `android/app/src/main/res/` juga memuat ikon aplikasi (`mipmap-*/ic_launcher.png` + `mipmap-anydpi-v26/ic_launcher.xml` adaptif, foreground di `drawable-*/ic_launcher_foreground.png`) dan warna splash di `values-v31/` serta `values-night-v31/`.

## Keputusan teknis (Bagian 6 PRD)

- Flutter stable, Android-only. `applicationId = com.elutung.app`, `minSdk = 26`; **namespace/Kotlin package = `com.elutung.elutung`** (sengaja beda dari applicationId).
- Penyimpanan **Drift/SQLite** (bukan Hive) karena rekap butuh agregasi SQL. Nominal = **int rupiah** (tanpa desimal).
- `fl_chart` untuk grafik, `home_widget` + `workmanager` (provider native **RemoteViews**), `flutter_riverpod` (v3), `intl` (locale `id_ID`), `uuid`, `share_plus`, `file_picker`, `path_provider`, `shared_preferences`.
- Gaya visual **neobrutalism lembut** (border tebal + sudut kecil, tapi warna muted).

## Model data & aturan bisnis (Bagian 7–8)

- Tabel: `institutions`, `categories`, `accounts`, `transactions`, `budgets`, `recurring_rules`. Semua entitas: `id` (uuid), `createdAt`, `updatedAt`, `deletedAt` (**soft delete**).
- `categories` **tanpa** field `jenis` (tipe dibawa `transactions.tipe`) dan **tanpa** `archived` (keadaan nonaktif = `deletedAt`). Kategori bersifat umum (dipakai masuk maupun keluar).
- `accounts` = relasi ke `institutions` (tanpa nama/ikon/warna/label).
- `budgets` = rentang tanggal eksplisit (`periodeMulai`/`periodeSelesai`), sekali pakai; `lingkup` total|kategori.
- **Transfer (Bagian 8.1):** ke akun sendiri → **bukan** pengeluaran (hanya `biayaAdmin`); ke pihak lain → `nominal + biayaAdmin` jadi pengeluaran.
- **Kategori pembukuan pengeluaran** = `finance.expenseCategoryId()`, bukan selalu `Transaction.kategoriId`: biaya admin transfer antar akun sendiri selalu masuk kategori `transfer_admin` ("Transfer & Admin"). Dipakai konsisten di `expenseByCategory`, `budgetUsageOf`, dan ekspresi SQL `_expenseCategoryExpr()` — termasuk saat **memfilter** kategori, supaya kartu total, tabel, dan grafik tidak berbeda.
- **Grafik donut** menggabungkan kategori kecil (<3% dari total) jadi satu potongan "Lainnya" lewat `buildChartSlices()` di `widgets/charts.dart` (mitigasi Bagian 16); jumlah potongan tetap sama dengan total.
- **Tema kustom (v1.1)** — `ThemeController` menyimpan mode, preset, dan penyesuaian warna **terpisah per mode** (terang/gelap) di SharedPreferences. `Neo` dulu menyimpan warna sebagai field mutable; sekarang ia hanya *getter* dari satu `NeoPalette` yang diisi `Neo.apply()` di `ElutungApp.build`. `AppTheme.light()/dark()` menerima palet sebagai argumen supaya `theme` dan `darkTheme` bisa dibangun berdampingan tanpa tertukar. Warna semantik tidak ikut berubah.
- **Warna anggaran (Bagian 8.2):** <60% aman, 60–85% waspada, 85–100% menipis, ≥100% lewat batas (`util/budget.dart`).
- Seed institusi/kategori hanya ditulis saat DB **dibuat** (`onCreate`).
- **Pengingat cadangan (FR-10.4) tidak boleh menagih.** `BackupService.shouldRemindBackup({hasData})` hanya berbunyi bila sudah ada data, tidak diulang dalam 7 hari (waktu pengingat dicatat di `last_backup_reminder_at`), dan hanya bila belum pernah mencadangkan atau sudah lewat 30 hari. Dulu ia berbunyi di setiap pembukaan selama pengguna belum pernah ekspor.
- **Skema v3** — v2 membuang `categories.archived`; v3 menambah tabel `recurring_rules` dan kolom `transactions.recurring_rule_id`. `onUpgrade` memakai `m.dropColumn`, `m.createTable`, dan `m.addColumn`, lalu `_createIndexes()`. Uji migrasi nyata (v1 ke v4 dan v2 ke v4, plus indeks unik menolak periode ganda) ada di `test/migration_test.dart`. v4 menambah kolom `transactions.struk_path` (foto struk).
- **Transaksi berulang (v1.1)** — aturan di `recurring_rules`; transaksi hasilnya ditandai `recurringRuleId`. Hanya pemasukan/pengeluaran, frekuensi harian/mingguan/bulanan/tahunan. Dibangkitkan otomatis saat aplikasi dibuka dan oleh WorkManager, maksimal 100 per aturan per jalan (sisanya menyusul). Aturan ikut terekspor di cadangan JSON dan ada di layar Sampah.
- **Scan struk (v1.2)** — foto struk dibaca OCR **di perangkat** (ML Kit, offline) lewat `services/receipt_scanner.dart`, lalu diurai `data/receipt.dart` (nominal/tanggal/merchant). Hasilnya selalu lewat form review (`features/transactions/scan_receipt_screen.dart`), kategori dipilih manual, dan keterangan opsional diisi otomatis dari merchant. Foto boleh disimpan (`services/receipt_storage.dart`, di dokumen aplikasi) atau dibuang; gambar tidak ikut cadangan JSON.
- **Cadangan bisa dikunci (v1.3)** — ekspor/impor JSON memakai kata sandi opsional (AES-GCM + PBKDF2, `data/backup.dart`). Berkas terkunci ditandai `elutungEncrypted`; tanpa kata sandi, impor mengembalikan `-2`.
- **Signing rilis & CI** — kredensial rilis dari `android/key.properties` (tidak di-commit; `android/app/release-key.jks`); bila tidak ada, build jatuh ke debug. R8 butuh `android/app/proguard-rules.pro` (ML Kit). CI ada di `.github/workflows/ci.yml` (analyze + test).
- **Enkripsi basis data belum diterapkan** — paket `sqlcipher_flutter_libs` sudah EOL, jadi enkripsi DB menunggu jalur `sqlite3` 3.x dan uji perangkat. Jangan menebak-nebak.
- Kategori yang sudah dihapus tetap dipakai untuk **label & warna** transaksi lama lewat `allCategoriesProvider`; `categoriesProvider` (aktif saja) hanya untuk pemilih/filter. Hapus kategori yang masih dipakai transaksi **ditolak** (`CategoryRepository.usedByTransactions`).
- **Agregasi rekap di SQL** (`watchMonthTotals`, `watchMonthExpenseByCategory`, `watchMonthlySeries`) lewat `CaseWhenExpression` + `SUM`/`GROUP BY`; dipakai layar Rekap via `monthTotalsProvider`/`monthExpenseByCategoryProvider`/`monthlySeriesProvider`. Padanan aturan transfer ada di SQL **dan** `finance.dart` — kesetaraannya dijaga `test/sql_aggregate_test.dart`. Jalur yang butuh data per baris (anggaran, saldo akun, widget) tetap memakai `allTransactionsProvider`. Pengelompokan bulan memakai `modify(DateTimeModifier.localTime())` — jangan pakai `strftime` polos (UTC → geser batas bulan).

## Commands

```bash
cd ~/E-Lutung/app
flutter pub get
dart run build_runner build        # WAJIB setelah mengubah skema Drift
flutter analyze                    # harus 0 issue
flutter test                       # 139 test
flutter run
flutter build apk --release
flutter build appbundle --release
flutter build apk --release --split-per-abi
```

## Gotchas (dari bug nyata — jangan diulang)

1. **Token `Neo` bersifat mutable.** `bg/surface/ink/muted` di-swap `applyBrightness()` saat tema berubah. JANGAN memakai `Neo.*` di dalam ekspresi `const` → `invalid_constant`. `NeoCard.color` default `null` (diselesaikan di build).
2. **Lokalisasi wajib di-init.** Panggil `ensureIntlLocale()` sebelum memakai `DateFormat(..., 'id_ID')`; tanpa itu `LocaleDataException` (dulu bikin tombol **+ di Anggaran tidak berfungsi**). Di widget test: `setUpAll(() async => ensureIntlLocale())`.
3. **Companion Drift bukan `const`** → daftar seed tidak boleh `const [...]`.
4. **Widget**: rujuk provider via `qualifiedAndroidName` (`com.elutung.elutung.ElutungWidgetProvider`) karena applicationId (`.app`) ≠ package kelas (`.elutung`).
5. **`MainActivity` memakai `FlutterActivity`.** Dulu `FlutterFragmentActivity` karena `local_auth`; fitur kunci aplikasi sudah **dihapus** (v1.1, permintaan pengguna), jadi kebergantungan itu ikut dibuang. Ubah kembali ke `FlutterFragmentActivity` hanya bila menambah plugin yang membutuhkannya (mis. mengembalikan `local_auth`).
6. **Hapus = soft delete** (`deletedAt`) → muncul di **Sampah** dan bisa dipulihkan. Jangan buat hard delete dan jangan hidupkan lagi kolom `archived`. Kategori yang masih dipakai transaksi **tidak boleh** dihapus (ditolak) — labelnya masih dibutuhkan riwayat/rekap.
7. **Widget test + Drift**: jangan `pumpAndSettle()` selama stream belum mengirim data pertama (dulu ada animasi tak berujung → menggantung). Bongkar tree (`pumpWidget(SizedBox())`) sebelum test selesai agar timer pembersihan Drift jalan (menghindari "Pending timers"). Jangan menutup DB saat stream masih aktif ("Cannot add event while adding stream").
8. **Uang selalu int rupiah**; input lewat `ThousandsInputFormatter` dan dibaca `parseRupiah` (tahan format "25.000"/"Rp 1.250.000").
9. **Palet harus tetap lembut** (permintaan pengguna). **Aksen dekoratif dilarang memakai hijau/merah** agar tidak bentrok dengan makna pemasukan/pengeluaran.
10. **Tema gelap**: AppBar memakai permukaan gelap, **bukan** kuning (kontras menyilaukan). Kuning lembut hanya di tema terang.
11. **Nama nilai enum** (`textEnum`) tersimpan sebagai teks di DB — mengubahnya butuh migrasi.
12. **Data widget** — key mengikuti Bagian 12 PRD: `widget_income_month`, `widget_expense_month`, `widget_budget_remaining`, `widget_budget_pct`, `widget_latest_1..3`, plus `widget_budget_color` (tambahan, indikator warna FR-9.3). Harus sinkron antara `widget_sync.dart`, `ElutungWidgetProvider.kt`, dan layout XML; kalau key berubah, ubah ketiganya.
13. Widget beranda **tidak muncul otomatis**; pengguna memasangnya (Pengaturan → "Pasang widget beranda"). Sejak Android 8, launcher menyembunyikan widget app yang belum pernah dijalankan.
14. **`m.createAll()` TIDAK idempotent untuk indeks** — DDL indeks yang dihasilkan Drift tidak memakai `IF NOT EXISTS`, jadi memanggilnya saat indeksnya sudah ada langsung gagal (`SqliteException: index ... already exists`). Di `onUpgrade` jangan pakai `createAll()`; gunakan `m.createTable`/`m.addColumn` untuk yang baru, lalu `_createIndexes()` yang memakai `CREATE INDEX IF NOT EXISTS`. Ini pernah membuat dua test migrasi merah.
15. **`@TableIndex` tidak bisa dipakai dua kali** pada satu kelas tabel (bukan anotasi `@Repeatable`), jadi indeks unik `idx_transactions_recurring_tanggal` dibuat lewat `customStatement`. Jangan "merapikan"-nya jadi anotasi kedua — tidak akan ter-compile.
16. `RecurringRunner.runDue()` dijalankan dari dua tempat (aplikasi dan isolate WorkManager) yang memakai koneksi DB berbeda. Keamanan ganda: pemeriksaan keberadaan per periode **dan** indeks unik; jangan hapus salah satunya.
17. **Jangan menggambar teks dengan `Neo.ink` di atas `accent` atau `appBar`.** Dulu `NeoButton` begitu, dan di mode gelap hasilnya teks terang di atas kuning terang — kontras 1.2:1, praktis tak terbaca. Sekarang teks di atas kedua token itu memakai `readableOn(latar)`, dan `ColorScheme.onPrimary` juga dihitung dari `readableOn(accent)`. Ini bug lama yang baru ketahuan saat fitur tema menambahkan pemeriksa kontras.
18. **Deteksi warna "mirip makna" memakai rona (hue), bukan jarak RGB.** Jarak RGB mentah menyesatkan: arang `#3A3934` dianggap dekat dengan hijau pemasukan. Lihat `miripWarnaSemantik`. Kalau preset baru ditambahkan, jalankan `test/contrast_test.dart` — ada test yang menuntut semua preset bawaan bebas peringatan.
19. **FAB dan SnackBar wajib satu Scaffold.** Flutter hanya menaruh SnackBar `floating` **di atas** FAB bila keduanya berada di Scaffold yang sama (`scaffold.dart`: `snackBarYOffsetBase = floatingActionButtonRect.top`). Kalau FAB ada di dalam Scaffold tab sementara SnackBar dimunculkan dari shell, SnackBar akan menutupi tombolnya — ini sudah pernah terjadi. Karena itu tombol tambah dimiliki `ShellScreen._buildFab()`, dan `test/budget_screen_test.dart` menguji lewat `ShellScreen`, bukan lewat layar Anggaran langsung.
20. **Grafik tanpa data jangan menggambar apa pun.** `MonthlyBars` dan `NetTrendChart` sama-sama memakai konstanta `kNoMonthlyData`; grafik tren pernah menggambar garis datar saat kosong sehingga terlihat seperti saldo nol yang nyata.
21. **Splash Android 12+ diambil dari ikon aplikasi**, bukan dari berkas terpisah: `windowSplashScreenAnimatedIcon` + `windowSplashScreenBackground` di `values-v31/styles.xml` dan `values-night-v31/styles.xml`. Karena itu ikon bawaan Flutter dulu ikut muncul di splash. Kalau ikon diganti, splash ikut berubah — jangan tambahkan gambar splash terpisah. Layer **foreground** ikon adaptif sebaiknya tanpa border: mask bulat peluncur akan memotong sudutnya.
22. **Chrome sistem diatur sekali di `app.dart`, bukan per layar.** `main.dart` mengaktifkan `SystemUiMode.edgeToEdge`, lalu `AnnotatedRegion<SystemUiOverlayStyle>` (dihitung dari palet aktif lewat `readableOn`) menentukan warna dan kecerahan ikon status bar serta bilah navigasi. Jangan menyetel `statusBarColor` buram di layar tertentu — layar tanpa AppBar (onboarding) akan kembali memunculkan pita warna jendela.

## Verifikasi sebelum mengirim

- `flutter analyze` **0 issue**, `flutter test` semua lolos, build APK/AAB sukses.
- **Pengujian di perangkat dilakukan pemilik proyek di HP-nya sendiri**, bukan oleh agen. Cukup pastikan tiga perintah di atas hijau, lalu serahkan `app/build/app/outputs/flutter-apk/app-release.apk` untuk diuji. Jangan menyalakan emulator untuk pengujian rutin — pemasangan emulator dan system image hanya membuang ruang dan waktunya.
- `test/app_smoke_test.dart` membangun aplikasi utuh dan menelusuri keempat tab serta Pengaturan; `test/core_flow_test.dart` menguji alur catat transaksi sampai tersimpan. Jalankan keduanya setiap kali menyentuh `app.dart`, `shell.dart`, atau tema.
- Dua jebakan saat menulis test widget aplikasi utuh: (1) form lebih panjang dari viewport uji, jadi ketuk tombol setelah `ensureVisible`; (2) **SnackBar mengantre** — pengingat cadangan dari shell bisa menutupi SnackBar yang sedang diuji, jadi setel `last_backup_at` di `SharedPreferences.setMockInitialValues`. Dan selalu bongkar tree (`pumpWidget(SizedBox())`) di blok `finally`, karena menutup basis data selagi stream hidup membuat test menggantung.
- Setelah ubah skema: jalankan `build_runner` dan pastikan `lib/data/database.g.dart` ikut diperbarui.
- Uji logika uang lewat `lib/data/finance.dart` (murni) — jangan menaruh rumus di widget.

## Di luar lingkup v1 (Bagian 3 & 19 PRD)

Utang/piutang, transaksi berulang otomatis, rollover anggaran, sinkronisasi antar-perangkat,
widget iOS, dan i18n penuh (v1 hanya locale `id`).
