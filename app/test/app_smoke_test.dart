import 'package:drift/native.dart';
import 'package:elutung/app.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/theme/app_theme.dart';
import 'package:elutung/theme/neo_palette.dart';
import 'package:elutung/theme/theme_controller.dart';
import 'package:elutung/util/contrast.dart';
import 'package:elutung/util/format.dart';
import 'package:elutung/widgets/neo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uji nyala: aplikasi dibangun utuh (onboarding, gerbang kunci, shell, empat
/// tab, dan Pengaturan) di atas basis data kosong, lalu dipastikan tidak ada
/// galat. Ini menangkap kegagalan "aplikasi tidak bisa dibuka" yang tidak
/// terlihat oleh test satuan.
void main() {
  setUpAll(() async => ensureIntlLocale());

  late AppDatabase db;
  late ThemeController theme;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    theme = ThemeController();
    await theme.load();
  });
  tearDown(() => db.close());

  /// Beberapa putaran pump supaya stream drift sempat mengirim data pertama.
  Future<void> pumpBeberapaKali(WidgetTester tester, [int kali = 12]) async {
    for (var i = 0; i < kali; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> nyalakan(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: ElutungApp(themeController: theme),
      ),
    );
    await pumpBeberapaKali(tester);
  }

  /// Onboarding hanya tampil pada test pertama, karena penandanya statis.
  Future<void> lolosOnboarding(WidgetTester tester) async {
    if (find.text('Lewati').evaluate().isEmpty) return;
    await tester.tap(find.text('Lewati'));
    await pumpBeberapaKali(tester);
  }

  Future<void> bukaTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await pumpBeberapaKali(tester);
  }

  Future<void> bereskan(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('menyala: onboarding bisa dilewati, lalu shell muncul', (
    tester,
  ) async {
    await nyalakan(tester);
    expect(tester.takeException(), isNull);

    // Onboarding tampil lebih dulu dan punya tombol lewati.
    expect(find.text('Lewati'), findsOneWidget);
    await lolosOnboarding(tester);
    expect(tester.takeException(), isNull);

    // Shell: judul, empat tab, dan tombol tambah.
    expect(find.text('E-Lutung — Dashboard'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(NavigationDestination),
      ),
      findsNWidgets(4),
    );
    expect(find.text('Data belum ada'), findsOneWidget);

    await bereskan(tester);
  });

  testWidgets('semua tab bisa dibuka tanpa galat', (tester) async {
    await nyalakan(tester);
    await lolosOnboarding(tester);

    for (final label in ['Riwayat', 'Rekap', 'Anggaran', 'Dashboard']) {
      await bukaTab(tester, label);
      expect(tester.takeException(), isNull, reason: 'tab $label');
      expect(find.text('E-Lutung — $label'), findsOneWidget);
    }

    await bereskan(tester);
  });

  testWidgets('Pengaturan dan layar Tema bisa dibuka', (tester) async {
    await nyalakan(tester);
    await lolosOnboarding(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await pumpBeberapaKali(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Tema & warna'), findsOneWidget);
    expect(find.text('Transaksi berulang'), findsOneWidget);
    expect(find.text('Sampah'), findsOneWidget);

    await tester.tap(find.text('Tema & warna'));
    await pumpBeberapaKali(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Krem'), findsOneWidget);
    expect(find.text('Warna terang'), findsOneWidget);

    await bereskan(tester);
  });

  testWidgets('mode gelap benar-benar terpasang pada tema', (tester) async {
    await theme.setMode(ThemeMode.dark);
    await nyalakan(tester);

    final ctx = tester.element(find.byType(NavigationBar));
    final aktif = Theme.of(ctx);
    final gelap = theme.paletteFor(Brightness.dark);

    expect(aktif.brightness, Brightness.dark);
    expect(aktif.appBarTheme.backgroundColor, gelap.appBar);
    expect(aktif.scaffoldBackgroundColor, gelap.bg);
    // Label di atas aksen harus terbaca, termasuk di mode gelap.
    expect(
      contrastRatio(aktif.colorScheme.onPrimary, aktif.colorScheme.primary),
      greaterThanOrEqualTo(3.0),
    );
    expect(tester.takeException(), isNull);

    await bereskan(tester);
  });

  testWidgets('NeoButton: label selalu terbaca di atas latarnya', (tester) async {
    // Penjaga regresi: dulu label memakai Neo.ink, dan di mode gelap itu berarti
    // teks terang di atas aksen kuning terang (kontras 1.2:1).
    for (final palet in [presetById('krem').light, presetById('krem').dark]) {
      Neo.apply(palet);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NeoButton(label: 'Simpan', onPressed: () {}),
          ),
        ),
      );
      await tester.pump();

      final teks = tester.widget<Text>(find.text('Simpan'));
      expect(
        contrastRatio(teks.style!.color!, palet.accent),
        greaterThanOrEqualTo(3.0),
        reason: 'palet ${palet.bg}',
      );
    }
  });
}
