# PRD — E-Lutung (Aplikasi Pencatat Keuangan, Flutter, Android, Local-only)

- **Nama aplikasi:** E-Lutung
- **Platform:** Android (Flutter)
- **Penyimpanan:** 100% lokal di perangkat (tanpa server, tanpa akun)
- **Mata uang:** Rupiah (IDR) saja
- **Status dokumen:** Final v1, diperbarui sampai v1.3 (v1.1 transaksi berulang & tema, v1.2 scan struk & gaya desain, v1.3 cadangan terkunci)
- **Tanggal:** 2026-10-07

---

## 1. Ringkasan Produk

Aplikasi mobile Android untuk mencatat **pemasukan**, **pengeluaran**, dan **transfer** harian, lalu merangkumnya **per bulan** dalam bentuk daftar rekap dan **grafik persentase per kategori** (makanan, belanja pribadi, transport, dll). Pengguna menetapkan **batas pengeluaran** (total bulanan dan per kategori); warna grafik bergerak dari **hijau → kuning → merah** saat anggaran makin terpakai. Sebuah **widget beranda Android** menampilkan aktivitas terbaru serta total pemasukan/pengeluaran bulan berjalan tanpa membuka aplikasi.

Semua data disimpan lokal di HP pengguna — aplikasi tidak butuh jaringan dan tidak mengirim data ke mana pun.

---

## 2. Tujuan

1. Mencatat transaksi keuangan dalam < 10 detik per transaksi.
2. Menjawab "bulan ini aku habis berapa, untuk apa?" dalam satu layar.
3. Memberi umpan balik visual instan soal kesehatan anggaran (hijau → merah).
4. Menampilkan ringkasan sekilas di beranda HP lewat widget.
5. Menjaga data tetap milik pengguna (offline, lokal, bisa diekspor).

## 3. Non-Tujuan (Out of Scope v1)

- Sinkronisasi cloud / multi-perangkat / login.
- Multi-mata uang dan kurs.
- Pembukuan bisnis, pajak, akuntansi double-entry.
- Integrasi otomatis ke bank/e-wallet (tidak ada penarikan otomatis maupun scraping data bank).
- Utang/piutang, aset/investasi, cicilan dengan bunga (kandidat v2).
- Widget iOS (aplikasi Android-only).
- Perhitungan bunga/administrasi otomatis dari pihak ketiga.

---

## 4. Pengguna Sasaran

| Persona | Kebutuhan utama |
|---|---|
| Pekerja/karyawan | Tahu kemana uang bulanan pergi; kontrol jajan & belanja |
| Mahasiswa | Batas pengeluaran harian/bulanan; lihat sisa uang |
| Freelancer | Pemasukan tidak tetap; rekap bulanan pemasukan vs pengeluaran |

Konteks pemakaian: pencatatan cepat sambil jalan (satu tangan), cek sekilas lewat widget, evaluasi di akhir bulan.

---

## 5. Ruang Lingkup

**Masuk (In):** pencatatan pemasukan/pengeluaran/transfer, master institusi (bank/e-wallet/tunai) & akun yang bisa diatur, kategori yang bisa dikelola (CRUD), rekap bulanan, grafik persentase per kategori, grafik pemasukan vs pengeluaran per bulan, batas anggaran (total + per kategori) dengan rentang tanggal & warna, transaksi berulang otomatis (v1.1), tema & gaya desain yang bisa dipilih (v1.1 & v1.2), scan struk lewat OCR di perangkat (v1.2), widget beranda, ekspor/impor cadangan termasuk yang dikunci kata sandi (v1.3).

**Keluar (Out):** semua pada Bagian 3.

---

## 6. Keputusan Teknis Kunci

| Aspek | Keputusan | Alasan |
|---|---|---|
| Framework | Flutter (channel stable) | Permintaan pengguna; satu basis kode |
| Gaya desain | **Neobrutalism** (lihat Bagian 6b) | Arah visual pilihan pengguna |
| Penyimpanan | **SQLite via Drift** (bukan Hive) | Rekap butuh agregasi (`SUM … GROUP BY kategori/bulan`); SQL jauh lebih ringkas & cepat daripada fold manual |
| Nominal uang | **Integer rupiah** (bukan double) | IDR tak berdesimal; menghindari galat pembulatan floating point |
| Grafik | `fl_chart` | Donut, bar, line dalam satu paket |
| Widget Android | paket `home_widget` + provider native **RemoteViews** | Flutter tak bisa merender widget beranda; wajib native |
| Kategori | Tabel `Category` yang bisa di-CRUD (tanpa field `jenis` & `archived`) | Pengguna mengelola kategorinya; grafik per kategori tetap konsisten |
| Update widget | `home_widget` saat data berubah + `workmanager` periodik (min 15 mnt) | AppWidget `updatePeriodMillis` minimum 30 mnt dan tidak realtime |
| State management | Riverpod (atau Provider) | Ringan, mudah diuji |
| Format | `intl` (locale `id_ID`) | `Rp1.250.000`, `Sep 2026` |
| Zona waktu | Zona lokal perangkat; periode bulan = 00:00 tgl 1 s/d 23:59 akhir bulan | Sesuai persepsi pengguna |
| ID | `uuid` v4 | Tidak bergantung auto-increment saat impor/merge |
| Target Android | `minSdk 26` (Android 8.0) | Cakupan perangkat luas; memadai untuk AppWidget/RemoteViews |
| Provider widget | **RemoteViews** (bukan Jetpack Glance) | Tanpa dependensi Compose → APK lebih ramping & kompatibel `minSdk 26` |

> Catatan migrasi: aplikasi ini terpisah dari project Lokasa; keputusan `Drift` di sini **tidak** menyamai pilihan Hive di Lokasa karena kebutuhan utamanya berbeda (agregasi laporan).

---

## 6b. Desain & UX — Neobrutalism

**Gaya visual: Neobrutalism.** Ciri yang dipakai konsisten di seluruh aplikasi:
- Warna **blok solid** & kontras tinggi, **tanpa gradien**.
- **Border tebal hitam** (2–3px) pada kartu, tombol, input, dan chart.
- **Bayangan keras** tanpa blur (offset 3–4px) sebagai pengganti elevation Material.
- Sudut minimal (radius kecil 4–10px; banyak elemen 0).
- Tipografi tebal (weight 700–800), judul besar/kapital; **angka nominal jadi fokus utama**.
- Ikon garis tebal (outline ~2px) kontras tinggi.
- Komponen "press": saat ditekan elemen bergeser ke arah bayangan 1–2px, durasi 80–120ms.

**Token warna (usulan, dapat disetel):**

| Token | Light | Dark | Catatan |
|---|---|---|---|
| `bg` | #FBFBF4 (krem) | #111111 | Latar layar |
| `surface` | #FFFFFF | #1C1C1C | Kartu/panel |
| `ink` | #000000 | #F5F5F5 | Border & teks utama |
| `accent` dekoratif | #FFD400 (kuning), #FF6EC7 (pink), #38D9F5 (cyan), #B7F34A (lime) | idem (tetap cerah) | Untuk elemen non-semantik |
| **Pemasukan** | #16A34A | idem | Semantik |
| **Pengeluaran** | #DC2626 | idem | Semantik |
| **Transfer** | #4F46E5 | idem | Semantik |

> Aturan penting: karena neobrutalism gemar memakai hijau/merah sebagai aksen dekoratif, **aksen dekoratif dilarang memakai hijau & merah** agar tidak rancu dengan makna pemasukan/pengeluaran. Aturan ini mengikat **palet bawaan**; pengguna boleh menyimpanginya lewat tema yang dapat disesuaikan (Bagian 6c), dan aplikasi memberi peringatan saat pilihannya berisiko.

**Makna & aksesibilitas (wajib):**
- **Warna bukan satu-satunya penanda:** nominal pemasukan selalu bertanda `+`, pengeluaran `−`, dengan ikon/arah berbeda (ramah buta warna).
- Kontras teks ≥ WCAG AA; target sentuh ≥48dp; teks widget ≥12sp; dukung pembesaran font.
- Border tebal & bayangan keras tidak boleh mengurangi area sentuh minimum.
- Warna anggaran mengikuti Bagian 8.2 (hijau → kuning → oranye → merah).

**Tipografi:** default platform (Roboto) bobot 700/800 + judul kapital. Font display kustom (mis. Space Grotesk) ditunda agar APK tetap ramping (lihat Bagian 19).

**Token layout:** spacing 4/8/12/16/24; radius 0/6/10; border 2px (3px saat fokus); shadow keras 4px.

**Komponen kunci (satu bahasa visual):** kartu ringkasan, chip kategori, tombol primer/sekunder, input nominal, kartu transaksi, progress bar anggaran, donut & bar chart.

**Grafik (fl_chart) gaya neobrutalism:** potongan donut berwarna blok dengan garis tepi hitam tebal, label persen tebal; bar dengan border hitam & bayangan keras; hindari gradien.

**Widget beranda:** latar solid + border hitam tebal + bayangan keras; teks tebal; indikator anggaran memakai warna Bagian 8.2.

**Mode gelap:** versi neobrutalism gelap — latar hampir hitam, `surface` #1C1C1C, border terang, aksen tetap cerah; kontras dijaga AA.

**Navigasi (ditetapkan):** **bottom navigation 4 tab** — Dashboard, Riwayat, Rekap, Anggaran; **Pengaturan** lewat ikon di AppBar; tombol tambah transaksi sebagai **FAB** menonjol bergaya neobrutalism.

**Empty / loading / error state:** kartu bergaya sama dengan ikon garis tebal; skeleton shimmer diganti **blok warna keras** sesuai gaya.

**Onboarding:** 2–3 kartu singkat bergaya neobrutalism (cara mencatat, grafik, widget), bisa dilewati.

**Risiko desain:** neobrutalism mengutamakan estetika di atas kepadatan data. Untuk aplikasi keuangan, **keterbacaan angka diprioritaskan**: jangan menaruh teks di atas aksen cerah tanpa kontras cukup, dan chart harus tetap jelas meski bergaya.

---

## 6c. Tema yang Dapat Disesuaikan (v1.1)

Pengguna boleh mengganti warna tampilan, tidak lagi terpaku pada palet Bagian 6b.

**Token yang bisa diubah** (masing-masing **terpisah untuk mode terang dan mode gelap**):

| Token | Memengaruhi |
|---|---|
| `bg` | Latar tiap layar |
| `surface` | Kartu, panel, dialog |
| `ink` | Border tebal dan teks utama |
| `appBar` | Bilah atas di semua layar |
| `accent` | Tombol, chip terpilih, indikator navigasi bawah |

**Yang tidak bisa diubah dan tidak boleh diserahkan ke pengguna:**

- `income`, `expense`, dan `transfer` tetap **terkunci**. Ketiganya pembawa makna, dan membiarkannya diubah membuat warna berhenti bisa dipercaya.
- `muted` (teks sekunder) **diturunkan** dari `ink` dan `bg` dengan transparansi, bukan token tersendiri, supaya selalu ikut menyesuaikan dan tidak bisa jadi tak terbaca.

**Preset dan penyesuaian.** Tersedia delapan palet bawaan sebagai titik awal — Krem (bawaan), Biru Langit, Ungu Lembut, Teal Tenang, Abu Netral, Malam Hangat, Grafit Sejuk, dan Tinta Lembut — masing-masing dengan pasangan terang dan gelap. Setelah memilih preset, tiap token di atas masih bisa disetel sendiri. Satu tombol mengembalikan mode yang sedang disunting ke preset-nya.

**Kenyamanan mode gelap.** Varian gelap sengaja tidak memakai latar hitam pekat berpasangan dengan teks putih murni: pasangan itu menghasilkan kontras di atas 13:1 dan melelahkan mata pada pemakaian lama. Kontras teksnya ditahan sekitar 8-10:1, latarnya dinaikkan sedikit dari hitam, dan aksennya dijinakkan (kejenuhan serta kecerahannya diturunkan) supaya tidak menyala. Batas nyaman ini dikunci `test/contrast_test.dart`.

**Pengaman (wajib):**

1. Teks di atas `accent` dan `appBar` **dijamin** terbaca: aplikasi memilih sendiri antara teks gelap dan terang sesuai kontras latarnya, tidak memakai `ink` mentah. Karena sudah dijamin, pasangan ini tidak perlu diperingatkan.
2. Untuk pasangan yang tetap ditentukan pengguna, aplikasi menghitung rasio kontras WCAG dan menampilkan peringatan bila di bawah ambang AA — yaitu `ink` terhadap `bg` dan `ink` terhadap `surface`.
3. Aplikasi memperingatkan bila `accent` atau `ink` yang dipilih terlalu mirip **rona** dan kecerahannya dengan warna semantik pemasukan, pengeluaran, atau transfer, karena itu mengembalikan kekacauan makna yang dicegah Bagian 6b. Perbandingannya memakai rona, bukan jarak RGB, supaya arang netral tidak salah dianggap menyerupai hijau.
4. Peringatan bersifat **tidak memblokir**: pengguna tetap boleh menyimpan pilihannya. Aplikasi menyarankan, bukan melarang.

> Alasan pelonggaran: Bagian 6b mengunci palet demi konsistensi dan keterbacaan. Permintaan pengguna untuk bisa mengatur tampilan sendiri lebih kuat daripada kekakuan itu, jadi yang dipertahankan bukan larangannya melainkan **safeguard**-nya: makna warna tetap dijaga, keterbacaan tetap diperiksa, dan pengguna tetap diberi tahu saat pilihannya berisiko.

---

## 7. Model Data

Semua nominal `int` (rupiah). Semua entitas punya `id` (uuid), `createdAt`, `updatedAt`, `deletedAt` (soft delete, null = aktif).

### 7.1 Institution (Master Institusi) — tabel baru

Satu tabel untuk semua jenis penyedia: bank, e-wallet, tunai, lain-lain. Dibedakan lewat kolom `tipe` (enum) supaya saat input akun/transfer pengguna **tinggal memilih dari daftar**. Diisi data awal (seed) institusi umum di Indonesia dan pengguna boleh menambah.

| Field | Tipe | Keterangan |
|---|---|---|
| id | text | PK |
| nama | text | "BCA", "Mandiri", "OVO", "GoPay", "Dana", "Tunai", … |
| tipe | enum | `bank` \| `ewallet` \| `tunai` \| `lain` |
| aktif | bool | Nonaktifkan tanpa hapus |

### 7.2 Category (Kategori)

Kategori **dipulihkan sebagai tabel** (dikelola pengguna). Dua field dari versi awal **dihapus** karena tidak dipakai atau sudah diwakili field lain:

- **`jenis` dihapus** — penanda pemasukan/pengeluaran sudah dibawa `Transaction.tipe`.
- **`archived` dihapus** — keadaan "tidak aktif" sudah diwakili `deletedAt` (soft delete). Memelihara `archived` berarti dua sumber kebenaran untuk satu keadaan nonaktif; lihat FR-8.2.

| Field | Tipe | Keterangan |
|---|---|---|
| id | text | PK |
| nama | text | "Makanan & Minuman", "Belanja Kebutuhan Pribadi", "Transport", "Gaji", … |
| ikon | text | Nama ikon (tampilan) |
| warna | text | Warna hex (tampilan; dipakai konsisten di grafik — FR-5.4) |

> **Menjaga label historis:** kategori yang sudah dihapus tetap dipakai untuk menerjemahkan `kategoriId` transaksi lama di riwayat/rekap/grafik, supaya nominal lama tidak jatuh ke "Tanpa kategori" dan warnanya tidak bergeser. Hapus kategori yang masih dipakai transaksi ditolak (FR-8.2).

Data awal (seed): Makanan & Minuman, Belanja Kebutuhan Pribadi, Transport, Tagihan & Utilitas, Kesehatan, Hiburan, Pendidikan, Transfer & Admin, Gaji, Bonus, Usaha, Bunga/Hadiah, Lain-lain.

> **Alasan `jenis` dihapus:** penanda pemasukan/pengeluaran sudah dibawa oleh `Transaction.tipe` (Bagian 7.4), jadi kategori tidak perlu menduplikasinya — kategori cukup menjadi label. Konsekuensi: kategori bersifat **umum** (satu kategori bisa dipakai untuk pemasukan maupun pengeluaran) dan pemilih kategori tidak dipisah per jenis. Agregasi grafik tetap benar karena disaring dulu berdasarkan `Transaction.tipe` — mis. donut pengeluaran = transaksi bertipe `pengeluaran` yang dikelompokkan per `kategoriId`.

### 7.3 Account (Akun/Dompet)

Nama akun **direlasikan** ke `Institution` (tidak lagi menyimpan nama bebas). Field `ikon` dan `warna` **dihapus** karena tidak dipakai. Tanpa `label` pembeda (satu institusi = satu akun).

| Field | Tipe | Keterangan |
|---|---|---|
| id | text | PK |
| institusiId | text | FK → Institution (wajib) |
| milikSendiri | bool | `true` = akun pengguna; `false` = tujuan pihak lain/eksternal |
| saldoAwal | int | Saldo awal (opsional) |
| aktif | bool | Nonaktifkan tanpa hapus |

### 7.4 Transaction (Transaksi)

| Field | Tipe | Keterangan |
|---|---|---|
| id | text | PK |
| tipe | enum | `pemasukan` \| `pengeluaran` \| `transfer` |
| nominal | int | Jumlah uang yang berpindah |
| tanggal | datetime | Kapan terjadi |
| kategoriId | text? | FK → Category. Wajib untuk pemasukan/pengeluaran; opsional untuk transfer |
| akunId | text? | FK → Account (akun sumber; untuk pemasukan: akun tujuan). **Wajib diisi lewat form** pada pemasukan/pengeluaran; transfer memakai akunAsalId/akunTujuanId |
| catatan | text? | Note bebas |
| — khusus transfer — | | |
| akunAsalId | text? | FK → Account ("dari mana") |
| akunTujuanId | text? | FK → Account ("ke mana") |
| biayaAdmin | int | Default 0 |
| recurringRuleId | text? | FK → RecurringRule. Terisi bila transaksi dibuat otomatis dari jadwal (Bagian 7.6) |

> Implementasi: bisa satu tabel `transactions` dengan kolom transfer nullable, atau tabel terpisah `transfer_details` (1:1). PRD ini tidak mengikat; pilih yang paling mudah diquery untuk rekap.

### 7.5 Budget (Batas Anggaran)

Periode memakai **rentang tanggal eksplisit dan sekali pakai** — mis. membatasi pengeluaran dari tanggal 5 sampai 10.

| Field | Tipe | Keterangan |
|---|---|---|
| id | text | PK |
| lingkup | enum | `total` \| `kategori` |
| kategoriId | text? | FK → Category; wajib bila lingkup `kategori` |
| periodeMulai | date | Tanggal awal berlakunya batas |
| periodeSelesai | date | Tanggal akhir berlakunya batas |
| nominal | int | Batas maksimum |
| aktif | bool | |

Anggaran berlaku bila tanggal transaksi berada dalam rentang `[periodeMulai, periodeSelesai]`. **Tidak ada reset otomatis bulanan** — pengguna menentukan rentangnya sendiri. Untuk warna chart utama, dipakai anggaran `lingkup = total` yang periodenya mencakup tanggal hari ini.

### 7.6 RecurringRule (Transaksi Berulang) — v1.1

Aturan transaksi yang dibuat otomatis saat jatuh tempo. Hanya untuk **pemasukan** dan **pengeluaran**, bukan transfer, supaya tidak perlu menyimpan akun asal dan tujuan.

| Field | Tipe | Keterangan |
|---|---|---|
| id | text | PK |
| tipe | enum | `pemasukan` \| `pengeluaran` |
| nominal | int | Nominal tiap kemunculan |
| kategoriId | text? | FK → Category (wajib diisi lewat form) |
| akunId | text? | FK → Account (**wajib diisi lewat form**, sama seperti transaksi biasa) |
| catatan | text? | Note bebas |
| frekuensi | enum | `harian` \| `mingguan` \| `bulanan` \| `tahunan` |
| mulai | date | Jatuh tempo pertama, sekaligus tanggal acuan untuk frekuensi bulanan dan tahunan |
| sampai | date? | Batas akhir inklusif; null berarti tanpa batas |
| terakhirDibuat | date? | Jatuh tempo terakhir yang sudah dibuatkan transaksi (null = belum pernah) |
| aktif | bool | Nonaktifkan tanpa hapus |

Aturan perhitungan tanggal:

- **Bulanan** memakai **tanggal acuan dari `mulai`**, bukan tanggal hasil jepitan. Bila tanggal acuan melebihi jumlah hari pada bulan itu, jatuh tempo dijepit ke hari terakhir (31 Januari menjadi 28 atau 29 Februari), dan bulan berikutnya **kembali ke tanggal acuan** (31 Maret). Ini mencegah jadwal bergeser permanen ke tanggal 28.
- **Tahunan** mengikuti aturan bulanan dengan langkah 12 bulan; 29 Februari menjadi 28 Februari pada tahun non-kabisat.
- `sampai` bersifat inklusif; setelah tanggal itu tidak ada transaksi baru.

> Alasan promosi: fitur ini semula ada di Backlog v2 (Bagian 19). Dinaikkan ke v1.1 karena pencatatan rutin (gaji, langganan) termasuk kebutuhan pokok, dan penjadwalannya bisa menumpang WorkManager yang sudah dipakai widget sehingga tidak menambah ketergantungan baru.

---

## 8. Aturan Bisnis

### 8.1 Perlakuan Transfer (keputusan penting)
Transfer dipecah menjadi dua makna agar rekap tidak salah:

1. **Transfer antar akun sendiri** (`akunAsal.milikSendiri == true` dan `akunTujuan.milikSendiri == true`):
   - **Bukan** pengeluaran dan **bukan** pemasukan (hanya memindah uang: saldo asal −nominal, saldo tujuan +nominal).
   - **`biayaAdmin` tetap dicatat sebagai pengeluaran** (kategori "Transfer & Admin").
2. **Transfer ke pihak lain** (`akunTujuan.milikSendiri == false`):
   - Dianggap **pengeluaran** sebesar `nominal + biayaAdmin` pada kategori yang dipilih.

Kedua kasus tetap muncul di riwayat transfer dengan detail dari→ke, nominal, kategori, admin, note.

> **Konsekuensi pembukuan:** untuk transfer antar akun sendiri, satu-satunya pengeluaran adalah biaya admin, dan biaya itu **selalu** dibukukan ke kategori "Transfer & Admin" — kategori yang dipilih di form hanya tersimpan sebagai catatan, bukan tempat pengeluarannya. Kalau kategori "Transfer & Admin" dihapus, transaksi lama tetap terbaca karena label historis tetap dipakai (Bagian 7.2).

### 8.2 Warna Anggaran (hijau → merah)
Dasar warna = **persentase terpakai** = `pengeluaran_periode / nominal_budget`.

| Terpakai | Warna | Makna |
|---|---|---|
| 0–59% | Hijau | Aman |
| 60–84% | Kuning/Amber | Waspada |
| 85–99% | Oranye | Menipis |
| ≥100% | Merah | Lewat batas |

- Warna ini dipakai pada: donut/chart anggaran, progress bar per kategori, kartu rekap bulanan, **dan widget beranda** (indikator sisa anggaran).
- Bila budget belum disetel, warna netral (abu) dan muncul ajakan "Setel batas bulanan".
- Ambang batas sebaiknya jadi konstanta yang mudah diubah (bukan hardcode tersebar).

### 8.3 Periode
- "Bulan ini" = tanggal 1 s/d akhir bulan berjalan menurut zona waktu perangkat.
- Rekap & grafik default ke bulan berjalan; pengguna bisa berpindah bulan (minimal 12 bulan ke belakang).

---

## 9. Fitur & Kebutuhan Fungsional

### FR-1 Dashboard (Beranda aplikasi)
- FR-1.1 Menampilkan kartu ringkas bulan berjalan: **total pemasukan**, **total pengeluaran**, **selisih**, dan **sisa uang** (rincian tiap petak di FR-1.6).
- FR-1.2 Menampilkan daftar 5 transaksi terbaru (ikon kategori, nama, nominal berwarna, waktu relatif).
- FR-1.3 Tombol tambah transaksi (FAB) dengan pilihan cepat: Pemasukan / Pengeluaran / Transfer.
- FR-1.4 Menampilkan donut persentase pengeluaran per kategori bulan berjalan.
- FR-1.5 Pemilih bulan yang memengaruhi seluruh kartu & grafik di halaman ini.
- FR-1.6 Kartu ringkas menampilkan empat petak: **pemasukan**, **pengeluaran**, **selisih** (arus bulan itu), dan **sisa** (uang yang tersisa sampai akhir bulan itu, dari saldo seluruh akun milik sendiri). Untuk bulan yang sudah lewat, angkanya adalah sisa saat bulan itu berakhir.
- FR-1.7 Kartu anggaran hanya menampilkan anggaran yang **sudah terpakai**, diurutkan dari persentase terpakai tertinggi, maksimal tiga baris; sisanya diringkas jadi satu catatan. Anggaran yang belum tersentuh tidak ditampilkan, hanya jumlahnya yang disebut.

### FR-2 Catat Transaksi
- FR-2.1 Form pengeluaran: nominal, kategori (wajib), **akun (wajib)**, tanggal/waktu (default sekarang), catatan; validasi nominal > 0.
- FR-2.2 Form pemasukan: nominal, kategori pemasukan (wajib), **akun tujuan (wajib)**, tanggal, catatan.
- FR-2.3 Form transfer: nominal, kategori (opsional), **dari akun** (wajib), **ke akun** (wajib), **biaya admin** (default 0), tanggal, note; menerapkan Bagian 8.1.
- FR-2.4 Simpan cepat: setelah simpan, form reset dan siap untuk input berikutnya; opsi "Simpan & tambah lagi".
- FR-2.5 Edit & hapus (soft delete) transaksi dari riwayat dan dari detail.
- FR-2.6 Nominal diinput dengan format ribuan Indonesia (`Rp` dan pemisah titik).
- FR-2.7 Akun wajib dipilih pada transaksi baru: uang tanpa akun tidak punya asal, dan membuat saldo akun tidak bisa dicocokkan dengan total bulanan. Transaksi lama yang belum berakun tetap dibiarkan apa adanya.

### FR-3 Riwayat Transaksi
- FR-3.1 Daftar transaksi dikelompokkan per tanggal, urut terbaru.
- FR-3.2 Filter: rentang tanggal, tipe (pemasukan/pengeluaran/transfer), kategori, akun.
- FR-3.3 Pencarian teks pada catatan/kategori.
- FR-3.4 Menampilkan subtotal per kelompok tanggal dan total periode.

### FR-4 Rekap Bulanan (per bulan)
- FR-4.1 Ringkasan bulan terpilih: total pemasukan, total pengeluaran, selisih, jumlah transaksi.
- FR-4.2 **Tabel rekap per kategori** (default: dikelompokkan per kategori) berisi nominal dan **persentase** terhadap total pengeluaran bulan itu.
- FR-4.3 **Filter kategori**: bisa disorot/difilter ke satu kategori tertentu; saat "Semua" dipilih, tampil semua kategori urut nominal terbesar.
- FR-4.4 Grafik batang **pemasukan vs pengeluaran** untuk 12 bulan terakhir (atau minimal 6).
- FR-4.5 Bisa berpindah bulan dan membandingkan dengan bulan sebelumnya (delta %).

### FR-5 Grafik
- FR-5.1 **Donut** persentase pengeluaran per kategori (bulan terpilih), label persen + legend.
- FR-5.2 **Bar** pemasukan vs pengeluaran per bulan.
- FR-5.3 (Opsional v1.1) **Line** tren sisa/saldo kumulatif bulanan.
- FR-5.4 Warna kategori konsisten di seluruh grafik & daftar.
- FR-5.5 Grafik dapat difilter mengikuti filter kategori yang sama dengan FR-4.3.

### FR-6 Anggaran (Budget)
- FR-6.1 Setel **batas total bulanan**.
- FR-6.2 Setel **batas per kategori** dengan rentang tanggal **periodeMulai–periodeSelesai** (mis. 5–10), berlaku sekali pakai untuk rentang itu.
- FR-6.3 Tampilkan progress bar per kategori dan total, dengan warna Bagian 8.2 dan teks "sisa Rp… / Rp… (...%)".
- FR-6.4 Peringatan non-blokir saat transaksi membuat anggaran terlewati (SnackBar/banner).
- FR-6.5 Halaman anggaran bisa difilter per kategori (konsisten dengan FR-4.3).
- FR-6.6 Dua kartu ringkasan di atas daftar, di luar saringan: **Sisa periode lalu** (uang yang dibawa masuk ke bulan ini, yaitu saldo akhir bulan lalu) dan **Total anggaran** (anggaran lingkup total bila ada; bila belum disetel, jumlah anggaran kategori yang berlaku). Keduanya bicara uang dan jatah keseluruhan, jadi tidak ikut berubah saat disaring.

### FR-7 Institusi & Akun (Dompet)
- FR-7.1 CRUD **Institusi**: nama + tipe (enum `bank`/`ewallet`/`tunai`/`lain`); seed institusi umum (BCA, Mandiri, OVO, GoPay, Dana, Tunai, …).
- FR-7.2 CRUD **Akun**: institusi (wajib), **nama bebas (opsional** — kosong berarti memakai nama institusi), tanda "milik saya"/"pihak lain", saldo awal. Tanpa ikon dan warna. **Saldo awal** diisi saldo sebelum transaksi pertama yang dicatat, karena saldo berjalan dihitung dari angka itu ditambah seluruh transaksi.
- FR-7.3 Menampilkan saldo berjalan per akun (saldo awal + pemasukan − pengeluaran ± transfer).
- FR-7.4 Institusi/akun nonaktif tidak muncul di pilihan form baru, tapi tetap tampil di riwayat lama.
- FR-7.5 Label akun memakai **nama yang diisi pengguna** bila ada, kalau tidak nama institusinya. Nomor urut ditambahkan **hanya bila labelnya tetap sama** dengan akun lain (dua akun di institusi yang sama, atau dua nama yang sama), mis. "BCA (2)". Dihitung dari daftar akun yang lengkap supaya nomornya sama di setiap layar; tanpa ini akun yang tampil identik bisa dibaca atau dipilih secara keliru.

### FR-8 Kategori
- FR-8.1 CRUD kategori: nama, ikon, warna (tanpa field `jenis`).
- FR-8.2 Kategori yang masih dipakai transaksi **tidak boleh dihapus** (ditolak dengan pesan; pindahkan dulu transaksinya). Kategori yang tidak dipakai lagi → soft delete ke Sampah (`deletedAt`), dapat dipulihkan. Nama & warna kategori yang sudah dihapus tetap ditampilkan pada transaksi lama agar label historis tidak hilang.
- FR-8.3 Kategori bersifat umum: dapat dipakai untuk pemasukan maupun pengeluaran.

### FR-9 Widget Beranda (Android)
- FR-9.1 Menampilkan **aktivitas terbaru** (1–3 transaksi terakhir): nama kategori/deskripsi, nominal, waktu.
- FR-9.2 Menampilkan **total pemasukan & pengeluaran bulan berjalan**.
- FR-9.3 Menampilkan **indikator sisa anggaran bulanan** dengan warna Bagian 8.2.
- FR-9.4 Ukuran widget mendukung minimal 2×2 dan 4×2; teks tetap terbaca (ukuran font minimum 12sp).
- FR-9.5 Diperbarui saat data berubah (tambah/edit/hapus) dan minimal periodik tiap 15–30 menit.
- FR-9.6 Mengetuk widget membuka aplikasi (ideal: langsung ke Dashboard; ideal+ ke detail transaksi terbaru).
- FR-9.7 Bila belum ada data/budget: tampilkan keadaan kosong yang ramah ("Belum ada transaksi bulan ini").

### FR-10 Cadangan & Pemulihan (penting karena lokal)
- FR-10.1 Ekspor seluruh data ke satu file (JSON/CSV) yang bisa disimpan/dibagikan pengguna.
- FR-10.2 Impor dari file ekspor dengan mode **ganti** atau **gabung** (dedup berdasarkan id).
- FR-10.3 (Opsional) Ekspor CSV khusus untuk spreadsheet.
- FR-10.4 Pengingat lembut berkala untuk mencadangkan (mis. tiap akhir bulan).

### FR-11 Pengaturan
- FR-11.1 Setel batas anggaran (pintasan ke FR-6).
- FR-11.2 Format & lokalisasi (IDR, `id_ID`).
- FR-11.3 Kunci aplikasi (PIN/biometrik): **dihapus** atas permintaan pengguna (v1.1). Aplikasi tidak lagi meminta autentikasi saat dibuka, dan kebergantungan `local_auth` ikut dibuang.
- FR-11.4 Hapus semua data (dengan konfirmasi ganda).
- FR-11.5 Tema terang/gelap/mengikuti sistem.
- FR-11.6 Tema yang dapat disesuaikan (Bagian 6c): pilih preset palet, lalu setel latar, permukaan, border/teks, bilah atas, dan aksen secara terpisah untuk mode terang dan gelap; warna semantik terkunci; ada peringatan kontras dan peringatan warna yang terlalu mirip makna pemasukan/pengeluaran; ada tombol kembali ke preset.

### FR-12 Transaksi Berulang (v1.1)
- FR-12.1 CRUD aturan berulang: tipe (pemasukan/pengeluaran), nominal, kategori, **akun (wajib)**, catatan, frekuensi (harian/mingguan/bulanan/tahunan), tanggal mulai, tanggal sampai (opsional), dan status aktif.
- FR-12.2 Transaksi dibuat **otomatis** saat jatuh tempo: dibangkitkan ketika aplikasi dibuka, dan tugas WorkManager yang sudah ada ikut menyusul periode yang terlewat. Tidak ada langkah persetujuan.
- FR-12.3 Satu periode tidak pernah tercatat dua kali (idempotent), termasuk bila aplikasi dan WorkManager berjalan bersamaan.
- FR-12.4 Transaksi hasil jadwal diberi penanda yang terlihat di riwayat, dan dapat diedit atau dihapus seperti transaksi biasa tanpa mengubah aturannya.
- FR-12.5 Aturan yang dinonaktifkan atau sudah melewati tanggal selesai berhenti menghasilkan transaksi; transaksi yang sudah ada tetap tersimpan.
- FR-12.6 Daftar aturan menampilkan jatuh tempo berikutnya serta bisa diaktifkan dan dinonaktifkan.
- FR-12.7 Pembangkitan dibatasi sejumlah catatan per aturan per jalan, agar aturan bertanggal mulai lama tidak membanjiri riwayat; sisanya dilanjutkan pada jalan berikutnya.

### FR-13 Scan Struk (v1.2)
- FR-13.1 Ambil foto dari kamera atau galeri, lalu teksnya dibaca **di perangkat** (ML Kit; modelnya ikut di dalam APK). Tidak ada jaringan yang dibutuhkan.
- FR-13.2 Hasil baca hanya **mengisi** form pengeluaran (nominal, tanggal, keterangan dari merchant) dan **tidak pernah tersimpan otomatis**: pengguna meninjau, memilih kategori dan akun, baru menyimpan. Kategori maupun akun tidak ditebak.
- FR-13.3 Foto boleh disimpan di dokumen aplikasi dengan pathnya dicatat pada transaksi (kolom `struk_path`). Layar **Foto struk** menampilkan jumlah dan ukuran foto, penampil, penghapus foto, serta pembersih path yang menunjuk berkas hilang.
- FR-13.4 Parser memilih total yang sah (bukan uang diterima, kembalian, atau baris diskon), tanggal yang wajar (menolak tanggal di masa depan), dan nama merchant. Struk dua kolom atau kolom tercampur diselesaikan lewat identitas `tunai − kembalian = total`, dan hanya bila label total memang ada.
- FR-13.5 **Hapus semua data** ikut menghapus berkas foto, supaya tidak tertinggal di dokumen aplikasi tanpa jejak di basis data.

### FR-14 Gaya Desain (v1.2)
- FR-14.1 Tujuh gaya visual: **Neobrutalism** (bawaan), Flat, Material, Neomorphism, Glass Morphism, Skeuomorphic, Minimalism. Gaya mengatur bentuk: border, sudut, bayangan, isian permukaan, efek tekan, penanda navigasi, dan kepadatan.
- FR-14.2 Gaya dan palet (Bagian 6c) berdiri sendiri-sendiri: gaya apa pun bisa dipasangkan dengan palet apa pun, memilih gaya tidak mengubah warna, dan gaya berlaku untuk mode terang maupun gelap sekaligus.
- FR-14.3 Pilihan gaya disimpan di perangkat dan bertahan setelah aplikasi ditutup. Bawaannya tetap Neobrutalism supaya tampilan pengguna lama tidak berubah setelah pembaruan.

### FR-15 Cadangan Terkunci (v1.3)
- FR-15.1 Ekspor cadangan JSON yang bisa **dikunci kata sandi** (opsional), dan impor dengan mode **Ganti** atau **Gabung**.
- FR-15.2 Terkunci berarti AES-256-GCM dengan kunci turunan PBKDF2-HMAC-SHA256; salt dan nonce acak untuk setiap ekspor, dan kata sandi **tidak pernah disimpan** di mana pun. Jumlah iterasi ikut tercatat di dalam berkasnya, jadi berkas lama tetap terbaca setelah angkanya dinaikkan.
- FR-15.3 Impor menolak berkas dari **versi format yang lebih baru**, dan menolak berkas asing atau rusak **tanpa menghapus** data yang sudah ada.
- FR-15.4 Foto struk tidak ikut di dalam cadangan (hanya pathnya), jadi setelah impor di perangkat lain fotonya ditandai hilang dan bisa dibersihkan.

---

## 10. Kebutuhan Non-Fungsional

- **Offline-first:** seluruh fitur inti tanpa jaringan; tidak ada izin internet wajib, tidak ada analitik/telemetri.
- **Performa:** cold start ke Dashboard < 2 detik (dataset normal ≤ 10.000 transaksi); scroll 60fps; query rekap bulanan < 100 ms.
- **Privasi:** data tak pernah keluar perangkat kecuali lewat ekspor manual pengguna.
- **Integritas:** nominal integer; transaksi tak bisa "setengah tersimpan" (operasi tulis atomik); soft delete agar salah hapus bisa dipulihkan (v1.1: layar Sampah).
- **Aksesibilitas:** label Semantics untuk tombol/grafik, target sentuh ≥48dp, kontras teks memenuhi WCAG AA, mendukung pembesaran font; **warna bukan satu-satunya penanda** (pemasukan `+`, pengeluaran `−` + ikon berbeda). Pembesaran font dibatasi sampai **1,4×** supaya tata letak tidak pecah pada setelan ekstrem; batas ini disengaja dan tercatat, bukan kelalaian. Bila nanti dibutuhkan batas yang lebih longgar, tata letak chip, kartu statistik, dan dialog perlu diuji ulang pada skala tersebut.
- **Ukuran & distribusi:** sediakan AAB untuk Play dan split-per-ABI untuk sideload.
- **Tanggal:** konsisten memakai zona lokal; hindari bug batas bulan (mis. 31 → pergantian bulan).

---

## 11. Alur Utama (ringkas)

1. **Catat kilat:** buka app → FAB → pilih Pengeluaran → nominal + kategori → Simpan. (≤10 detik)
2. **Transfer:** FAB → Transfer → nominal → dari akun → ke akun → biaya admin → note → Simpan (aturan Bagian 8.1 diterapkan otomatis).
3. **Cek bulan:** Dashboard → ganti bulan → lihat donut & rekap per kategori → filter kategori tertentu.
4. **Atur anggaran:** Pengaturan → set batas total & per kategori dengan rentang tanggal (mis. 5–10) → warna chart berubah sesuai pemakaian.
5. **Lihat sekilas:** pasang widget → tampil aktivitas terbaru + total bulan ini + indikator anggaran.

---

## 12. Widget Beranda — Detail Teknis

- Data widget disimpan sebagai nilai sederhana (SharedPreferences via `home_widget`) yang di-refresh setiap mutasi data: `widget_latest_*`, `widget_income_month`, `widget_expense_month`, `widget_budget_remaining`, `widget_budget_pct`, plus `widget_budget_color` (tambahan untuk indikator warna FR-9.3).
- Anggaran yang ditampilkan widget memakai **aturan yang sama dengan Dashboard**: anggaran yang periodenya beririsan dengan bulan berjalan, bukan hanya yang mencakup hari ini. Bila anggaran lingkup total belum disetel, dipakai jumlah anggaran kategori yang berlaku.
- Render oleh layout XML Android (RemoteViews). Jika memakai Jetpack Glance, logika tetap di sisi native; Dart hanya mengirim data.
- Pembaruan: (a) langsung saat mutasi (`HomeWidget.updateWidget`), (b) `WorkManager` task periodik min 15 menit untuk memastikan total bulan ikut berubah saat lewat tengah malam/bulan.
- Batasan yang harus diterima (jangan dijanjikan realtime): sistem Android dapat menunda pembaruan; widget bukan alat notifikasi.

---

## 13. Rumus & Definisi

- `totalPengeluaranBulan(YYYY-MM) = Σ nominal transaksi pengeluaran + Σ (nominal + biayaAdmin) untuk transfer ke pihak lain + Σ biayaAdmin transfer antar akun sendiri`.
- `totalPemasukanBulan = Σ nominal transaksi pemasukan`.
- `persentaseKategori = nominalKategori / totalPengeluaranBulan × 100`.
- `terpakaiAnggaran = totalPengeluaranDalamPeriode / nominalBudget` (periode = rentang `[periodeMulai, periodeSelesai]`).
- `saldoAkun = saldoAwal + Σ masuk − Σ keluar ± transferMasuk/Keluar`.
- Semua pembagian menangani pembagi nol (tampilkan "—", bukan NaN).

---

## 14. Kriteria Penerimaan (contoh, dapat diuji)

- [x] Menambah pengeluaran Rp25.000 kategori "Makanan" langsung muncul di daftar & mengubah total bulanan juga donut.
- [x] Rekap bulan menampilkan persentase per kategori yang bila dijumlahkan = 100% (±1% karena pembulatan).
- [x] Filter kategori pada rekap menyaring tabel **dan** grafik secara konsisten.
- [x] Transfer antar akun sendiri **tidak** menambah total pengeluaran, tetapi biaya adminnya menambah.
- [x] Transfer ke akun pihak lain menambah pengeluaran sebesar nominal + admin.
- [x] Anggaran 0–59% hijau; ≥100% merah, pada aplikasi dan widget.
- [ ] Widget menampilkan aktivitas terbaru + total bulan setelah transaksi ditambahkan (dalam ≤1 siklus refresh).
- [x] Ekspor → hapus data → impor menghasilkan data identik (jumlah & nominal cocok).
- [x] Aplikasi berjalan penuh dalam mode pesawat (airplane mode).
- [x] Batas bulan benar: transaksi 23:59 tgl terakhir bulan vs 00:00 tgl 1 bulan berikut jatuh ke periode masing-masing.
- [x] Transaksi berulang: aturan "bulanan tanggal 31" jatuh ke 28/29 Februari lalu kembali ke 31 Maret, dan satu periode tidak pernah tercatat dua kali.
- [x] Tema kustom: mengubah warna latar mode terang tidak mengubah mode gelap, pengaturan bertahan setelah aplikasi ditutup, warna semantik tetap tidak bisa diubah, dan kontras rendah memunculkan peringatan tanpa menghalangi penyimpanan.

Catatan bukti: kotak di atas ditandai hanya bila ada pemeriksaan otomatis yang menjalankannya.

- Persentase berjumlah 100% dan filter kategori: `test/sql_aggregate_test.dart`, `test/recap_screen_test.dart`.
- Aturan transfer (Bagian 8.1): `test/finance_test.dart`, `test/sql_aggregate_test.dart`, `test/budget_test.dart`.
- Ambang warna anggaran (Bagian 8.2): `test/budget_test.dart`; pemakaian warna yang sama di widget belum diuji di perangkat.
- Ekspor → impor: `test/backup_test.dart`.
- Mode pesawat: manifest rilis tidak meminta izin `INTERNET` (hanya varian debug/profil yang memintanya untuk hot reload).
- Batas bulan: `test/finance_test.dart` dan `test/sql_aggregate_test.dart` (dijalankan juga di tiga zona waktu berbeda).
- Transaksi berulang: `test/recurring_test.dart` (matematika jadwal, penjepitan akhir bulan, tahun kabisat), `test/recurring_runner_test.dart` (idempotensi termasuk dua pelari bersamaan, batas per jalan, tanggal selesai, aturan nonaktif), `test/migration_test.dart` (migrasi v1 dan v2 ke v3, indeks unik menolak periode ganda).
- Tema kustom: `test/theme_controller_test.dart` (pisahan terang/gelap, persistensi, pengaturan rusak tidak menggagalkan pemuatan, token semantik terkunci), `test/contrast_test.dart` (rasio WCAG, `readableOn` yang menyapu seluruh rentang kecerahan, semua preset bawaan bebas peringatan, deteksi rona yang menyerupai warna semantik), `test/theme_screen_test.dart` (layar tema).

- Alur catat transaksi lewat form sampai tampil di Dashboard: `test/core_flow_test.dart` (termasuk penolakan saat akun belum dipilih, dan `akunId` yang tersimpan). Sebelumnya ini hanya bisa diperiksa di perangkat.
- Scan struk: `test/receipt_test.dart` (parser: total yang sah, uang diterima dan kembalian ditolak, tanggal salah baca, merchant), `test/receipts_test.dart` (path foto, pembersih path hilang, hapus semua data ikut menghapus berkas), `test/migration_test.dart` (kolom `struk_path`).
- Gaya desain: `test/design_style_test.dart` (tujuh gaya, token Neo yang mengikuti gaya, tipografi yang dibekukan), `test/design_style_screen_test.dart`, dan `test/app_smoke_test.dart`.
- Cadangan terkunci: `test/backup_test.dart` (berkas tanpa nomor versi ditolak, versi lebih baru ditolak tanpa menghapus data, jumlah iterasi diambil dari berkasnya, sandi salah gagal membuka).
- Aturan akun wajib dan catatan lama tanpa akun: `test/core_flow_test.dart`, `test/repair_screen_test.dart`.
- Label akun sejenis: `test/accounts_test.dart`.
- Aturan periode anggaran dan sisa uang: `test/budget_test.dart`, `test/dashboard_budget_test.dart`, `test/sisa_uang_test.dart`.

Satu kotak yang masih kosong butuh perangkat: pembaruan widget beranda setelah transaksi ditambahkan.

---

## 15. Rencana Rilis (milestone, tanpa estimasi waktu)

- **M1 — Fondasi:** proyek Flutter, Drift schema, CRUD Institusi & Akun (dengan seed institusi).
- **M2 — Transaksi:** form pemasukan/pengeluaran, riwayat, filter, pencarian.
- **M3 — Rekap & Grafik:** dashboard bulanan, donut per kategori, bar bulanan, filter kategori.
- **M4 — Anggaran:** budget total & per kategori dengan rentang tanggal, logika warna, peringatan.
- **M5 — Transfer:** model multi-akun, aturan Bagian 8.1, saldo per akun.
- **M6 — Widget:** provider native + `home_widget` + WorkManager + deep link.
- **M7 — Cadangan & Poles:** ekspor/impor, tema, aksesibilitas, build AAB/split.

**v1.1 (setelah v1):**

- **M8 — Transaksi Berulang:** aturan berulang harian/mingguan/bulanan/tahunan, pembangkitan otomatis saat jatuh tempo, dan penanda "dari jadwal" di riwayat.
- **M9 — Tema Kustom:** preset palet, penyesuaian warna per mode, warna semantik terkunci, dan peringatan kontras.

Setiap milestone harus lolos `flutter analyze` (0 issue) dan set test-nya sebelum lanjut.

---

## 16. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Data hilang (HP rusak/reset) karena lokal | Tinggi | Wajib ekspor/impor (FR-10) + pengingat berkala |
| Widget tak update sesuai harapan | Sedang | Set ekspektasi; update saat mutasi + WorkManager 15 mnt |
| Salah interpretasi transfer (dianggap pengeluaran) | Tinggi | Aturan Bagian 8.1 eksplisit + label jelas di UI |
| Floating point pada uang | Sedang | Simpan integer rupiah |
| Query rekap lambat saat data besar | Sedang | Index pada (tipe, tanggal, kategori); agregasi di SQL |
| Bug batas bulan/zona waktu | Sedang | Uji kasus batas bulan & DST/zona |
| Grafik ramai saat kategori banyak | Rendah | Limit legend + "Lainnya" untuk kategori kecil |

---

## 17. Keputusan Final

Pertanyaan terbuka sebelumnya sudah ditetapkan (boleh ditinjau ulang bila kebutuhan berubah):

1. **Nama & paket aplikasi:** E-Lutung, `com.elutung.app`.
2. **Transfer antar akun sendiri:** **tidak** dihitung sebagai pengeluaran/pemasukan; hanya `biayaAdmin` yang tercatat sebagai pengeluaran (lihat Bagian 8.1).
3. **Target Android:** `minSdk 26` (Android 8.0); `targetSdk` mengikuti versi terbaru yang didukung Flutter saat rilis.
4. **Widget:** provider **RemoteViews** (bukan Jetpack Glance) demi kompatibilitas & ukuran; mendukung ukuran 2×2 dan 4×2.
5. **Kunci aplikasi:** **dihapus** atas permintaan pengguna (v1.1). Sebelumnya disertakan di v1 dengan default nonaktif; perlindungan sekilas saat HP dipinjam dianggap tidak sepadan dengan tambahan friksi setiap kali membuka aplikasi.
6. **Periode anggaran:** memakai rentang tanggal eksplisit (`periodeMulai`–`periodeSelesai`) dan **sekali pakai**; tidak ada reset otomatis bulanan maupun rollover.
7. **Layar Sampah:** disertakan sejak v1 (soft delete sudah ada di data sejak awal, UI pemulihannya menyusul dan kini sudah tersedia).
8. **Mode gelap & kategori kustom:** keduanya masuk v1 — kategori berupa tabel yang bisa di-CRUD (ikon & warna disimpan per kategori).
9. **Gaya desain:** **Neobrutalism** (detail di Bagian 6b).
10. **Navigasi:** **bottom navigation 4 tab** (Dashboard, Riwayat, Rekap, Anggaran) + Pengaturan di AppBar — ditetapkan dan sudah dipakai.
11. **Transaksi berulang (v1.1):** dibuat **otomatis** saat jatuh tempo, bukan usulan yang perlu disetujui; dibangkitkan saat aplikasi dibuka dan oleh tugas WorkManager yang sudah ada; hanya untuk pemasukan dan pengeluaran; frekuensi harian, mingguan, bulanan, tahunan.
12. **Tema yang dapat disesuaikan (v1.1):** pengguna boleh mengubah `bg`, `surface`, `ink`, `appBar`, dan `accent`, terpisah untuk mode terang dan gelap; `income`, `expense`, dan `transfer` terkunci; peringatan kontras dan kemiripan makna bersifat tidak memblokir (Bagian 6c).

---

## 18. Dependensi yang Diusulkan (Flutter)

`drift` + `sqlite3_flutter_libs` + `drift_dev` (dev), `fl_chart`, `home_widget`, `workmanager`, `shared_preferences`, `uuid`, `intl`, `path_provider`, `share_plus` (ekspor), `file_picker` (pilih berkas cadangan), `riverpod`/`provider`, `flutter_lints`.

Ditambahkan sejak v1.2:

- `google_mlkit_text_recognition` — OCR di perangkat untuk scan struk (model dibundel di APK).
- `image_picker` — ambil foto dari kamera atau galeri.
- `cryptography` — AES-256-GCM dan PBKDF2 untuk cadangan terkunci.

---

## 19. Backlog v2 (sengaja ditunda)

Sudah dikerjakan lebih awal dari rencana:

- **Transaksi berulang otomatis** (langganan, gaji bulanan) — dinaikkan ke v1.1, spesifikasinya ada di Bagian 7.6 dan FR-12.
- **Cadangan terenkripsi** — dikerjakan di v1.3, spesifikasinya ada di FR-15. Yang masih ditunda hanyalah sinkronisasi antar-perangkat.
- Grafik garis tren saldo kumulatif — sudah ada di layar Rekap.
- Layar "Sampah" + pemulihan transaksi — sudah ada sejak v1.

Masih ditunda:

- Utang/piutang dan cicilan. Bentuknya sudah disepakati: **catatan sederhana** — siapa berutang kepada siapa, nominal, tenggat, dan pelunasan sebagian; pembayaran tetap dicatat sebagai transaksi biasa supaya tidak ada model uang kedua.
- Rollover anggaran (jatah anggaran yang belum terpakai dibawa ke periode berikutnya). Yang sudah ada hanyalah **sisa uang** dari bulan lalu (FR-6.6), dan itu bicara uang nyata, bukan jatah.
- Sinkronisasi opsional antar-perangkat.
- Widget iOS (bila aplikasi diperluas ke iOS).
- Font display kustom — **diputuskan tidak dikerjakan**: tipografinya sengaja dibekukan tanpa font kustom agar tetap nyaman dibaca.
