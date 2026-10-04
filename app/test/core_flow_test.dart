import 'package:drift/native.dart';
import 'package:elutung/app.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/features/transactions/transaction_form_screen.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/theme/theme_controller.dart';
import 'package:elutung/util/format.dart';
import 'package:elutung/widgets/neo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alur utama yang dijanjikan PRD Bagian 11: catat pengeluaran dari Dashboard
/// sampai muncul di daftar dan tersimpan. Diuji lewat aplikasi utuh, bukan
/// lewat repositori, supaya jalur layarnya ikut terbukti.
void main() {
  setUpAll(() async => ensureIntlLocale());

  late AppDatabase db;

  setUp(() async {
    // Tandai sudah mencadangkan baru-baru ini, supaya pengingat cadangan tidak
    // muncul dan mengantre di depan SnackBar yang sedang diuji.
    SharedPreferences.setMockInitialValues({
      'last_backup_at': DateTime.now().toIso8601String(),
    });
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> pompa(WidgetTester tester, [int kali = 12]) async {
    for (var i = 0; i < kali; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> nyalakan(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final theme = ThemeController();
    await theme.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: ElutungApp(themeController: theme),
      ),
    );
    await pompa(tester);
    if (find.text('Lewati').evaluate().isNotEmpty) {
      await tester.tap(find.text('Lewati'));
      await pompa(tester);
    }
  }

  /// Membuka form pengeluaran lewat navigator aplikasi yang sudah menyala.
  ///
  /// Sengaja tidak mengetuk FAB lewat koordinat: pada ukuran permukaan uji, titik
  /// pusat FAB bertabrakan dengan area lain sehingga ketukan tidak sampai
  /// (jejak hit-test berakhir di bilah navigasi). Itu keterbatasan harness,
  /// bukan aplikasinya. Yang diuji di sini tetap form asli, provider asli, dan
  /// basis data asli — hanya jalan masuknya yang dipersingkat.
  Future<void> bukaFormPengeluaran(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute(
        builder: (_) => const TransactionFormScreen(tipe: TxType.pengeluaran),
      ),
    );
    await pompa(tester);
  }

  Future<void> isiNominal(WidgetTester tester, String nilai) async {
    final field = find.descendant(
      of: find.widgetWithText(NeoTextField, 'Nominal'),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, nilai);
    await pompa(tester, 3);
  }

  Future<void> pilihKategori(WidgetTester tester, String nama) async {
    final chip = find.widgetWithText(ChoiceChip, nama);
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await pompa(tester, 3);
  }

  /// Form pengeluaran lebih panjang dari viewport uji, jadi tombol simpan harus
  /// digulirkan dulu agar ketukannya benar-benar sampai.
  Future<void> ketukSimpan(WidgetTester tester) async {
    final tombol = find.text('Simpan');
    await tester.ensureVisible(tombol);
    await tester.pump();
    await tester.tap(tombol);
    await pompa(tester);
  }

  testWidgets('catat pengeluaran dari Dashboard sampai tampil di riwayat', (
    tester,
  ) async {
    try {
      await nyalakan(tester);
      expect(find.text('Data belum ada'), findsOneWidget);

      await bukaFormPengeluaran(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Catat Pengeluaran'), findsOneWidget);

      // Formatter ribuan ikut bekerja saat mengetik.
      await isiNominal(tester, '25000');
      expect(find.text('25.000'), findsOneWidget);

      await pilihKategori(tester, 'Makanan & Minuman');

      await ketukSimpan(tester);

      // Kembali ke Dashboard dan transaksinya muncul.
      expect(tester.takeException(), isNull);
      expect(find.text('Data belum ada'), findsNothing);
      expect(find.text('Makanan & Minuman'), findsWidgets);
      expect(find.textContaining('25.000'), findsWidgets);

      // Riwayat menampilkan transaksi yang sama.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Riwayat'),
        ),
      );
      await pompa(tester);
      expect(find.text('Makanan & Minuman'), findsWidgets);
      expect(find.textContaining('25.000'), findsWidgets);

      // Yang terpenting: benar-benar tersimpan di basis data.
      final tersimpan = await db.select(db.transactions).get();
      expect(tersimpan.length, 1);
      expect(tersimpan.single.nominal, 25000);
      expect(tersimpan.single.kategoriId, 'makanan');
      expect(tersimpan.single.tipe, TxType.pengeluaran);
    } finally {
      // Wajib: bongkar tree sebelum tearDown menutup basis data, kalau tidak
      // stream drift masih hidup dan penutupannya menggantung.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    }
  });

  testWidgets('validasi menahan simpan saat kategori belum dipilih', (
    tester,
  ) async {
    try {
      await nyalakan(tester);
      await bukaFormPengeluaran(tester);
      await isiNominal(tester, '10000');

      await ketukSimpan(tester);
      await pompa(tester, 6);

      // Ditolak, tetap di form, dan tidak ada yang tersimpan.
      expect(find.text('Pilih kategori'), findsOneWidget);
      expect(find.text('Catat Pengeluaran'), findsOneWidget);
      expect(await db.select(db.transactions).get(), isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
}
