import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/account_repository.dart';
import 'package:elutung/data/repositories/recurring_repository.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:elutung/features/repair_screen.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/util/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layar "Perlu dibenahi": catatan lama yang belum punya akun, dikumpulkan
/// supaya bisa dibetulkan setelah akun diwajibkan pada transaksi baru.
void main() {
  setUpAll(() async => ensureIntlLocale());

  late AppDatabase db;
  late AccountRepository accounts;
  late TransactionRepository transactions;
  late RecurringRepository recurring;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(db);
    transactions = TransactionRepository(db);
    recurring = RecurringRepository(db);
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RepairScreen()),
      ),
    );
    await pompa(tester);
  }

  /// Wajib: bongkar tree sebelum tearDown menutup basis data, kalau tidak
  /// stream drift masih hidup dan penutupannya gagal.
  Future<void> bereskan(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<String> buatAkun(String institusi) => accounts.create(
    institusiId: institusi,
    milikSendiri: true,
    saldoAwal: 0,
  );

  testWidgets('transaksi tanpa akun terdaftar, transfer tidak dihitung', (
    tester,
  ) async {
    try {
      final now = DateTime.now();
      final asal = await buatAkun('tunai');
      final tujuan = await buatAkun('bca');
      await transactions.create(
        tipe: TxType.pengeluaran,
        nominal: 25000,
        tanggal: now,
        kategoriId: 'makanan',
      );
      // Transfer memang tidak memakai akunId, jadi bukan cacat.
      await transactions.create(
        tipe: TxType.transfer,
        nominal: 100000,
        tanggal: now,
        akunAsalId: asal,
        akunTujuanId: tujuan,
      );

      await nyalakan(tester);

      expect(find.text('Transaksi tanpa akun (1)'), findsOneWidget);
      expect(find.text('Makanan & Minuman'), findsOneWidget);
      expect(find.text('−Rp 25.000'), findsOneWidget);
      expect(find.text('−Rp 100.000'), findsNothing);
    } finally {
      await bereskan(tester);
    }
  });

  testWidgets('membetulkan transaksi dari layar ini', (tester) async {
    try {
      final now = DateTime.now();
      await buatAkun('tunai');
      await transactions.create(
        tipe: TxType.pengeluaran,
        nominal: 25000,
        tanggal: now,
        kategoriId: 'makanan',
      );

      await nyalakan(tester);
      expect(find.text('Transaksi tanpa akun (1)'), findsOneWidget);

      // Ketuk barisnya: form yang sama dengan pencatatan biasa terbuka.
      await tester.tap(find.text('Makanan & Minuman'));
      await pompa(tester);
      expect(tester.takeException(), isNull);
      // Menyunting transaksi lama, jadi judulnya "Ubah Transaksi".
      expect(find.text('Ubah Transaksi'), findsOneWidget);

      final chip = find.widgetWithText(ChoiceChip, 'Tunai');
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await pompa(tester, 3);

      final simpan = find.text('Simpan');
      await tester.ensureVisible(simpan);
      await tester.pump();
      await tester.tap(simpan);
      await pompa(tester);

      // Transaksinya sudah berakun, dan layarnya bersih.
      final tersimpan = await db.select(db.transactions).get();
      expect(tersimpan.single.akunId, isNotNull);
      expect(
        find.textContaining('Tidak ada yang perlu dibenahi'),
        findsOneWidget,
      );
    } finally {
      await bereskan(tester);
    }
  });

  testWidgets('aturan berulang tanpa akun terdaftar dan bisa dibuka', (
    tester,
  ) async {
    try {
      await recurring.create(
        tipe: TxType.pengeluaran,
        nominal: 99000,
        kategoriId: 'tagihan',
        frekuensi: Frequency.bulanan,
        mulai: DateTime.now(),
      );

      await nyalakan(tester);

      expect(find.text('Aturan berulang tanpa akun (1)'), findsOneWidget);
      expect(find.text('Tagihan & Utilitas'), findsOneWidget);

      await tester.tap(find.text('Tagihan & Utilitas'));
      await pompa(tester);
      expect(find.text('Ubah aturan'), findsOneWidget);
    } finally {
      await bereskan(tester);
    }
  });

  testWidgets('tanpa data lama, layarnya menyatakan bersih', (tester) async {
    try {
      await nyalakan(tester);

      expect(
        find.textContaining('Tidak ada yang perlu dibenahi'),
        findsOneWidget,
      );
      expect(find.textContaining('Transaksi tanpa akun'), findsNothing);
    } finally {
      await bereskan(tester);
    }
  });
}
