import 'package:drift/native.dart';
import 'package:elutung/data/database.dart';
import 'package:elutung/data/repositories/account_repository.dart';
import 'package:elutung/data/repositories/transaction_repository.dart';
import 'package:elutung/features/shell.dart';
import 'package:elutung/providers.dart';
import 'package:elutung/util/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sisa uang: kolom "Sisa" di Dashboard dan kartu "Sisa periode lalu" di tab
/// Anggaran. Keduanya bicara uang nyata, bukan jatah anggaran.
void main() {
  setUpAll(() async => ensureIntlLocale());

  late AppDatabase db;
  late AccountRepository accounts;
  late TransactionRepository transactions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(db);
    transactions = TransactionRepository(db);
  });
  tearDown(() => db.close());

  Future<String> buatAkun(int saldoAwal) => accounts.create(
    institusiId: 'tunai',
    milikSendiri: true,
    saldoAwal: saldoAwal,
  );

  Future<void> pumpBeberapaKali(WidgetTester tester, [int kali = 12]) async {
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
        child: const MaterialApp(home: ShellScreen()),
      ),
    );
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

  testWidgets('Dashboard menampilkan Sisa uang sampai akhir bulan', (tester) async {
    final now = DateTime.now();
    final akunId = await buatAkun(1000000);
    // Bulan lalu: tidak lagi mengubah angka hari ini, tapi ikut saldo berjalan.
    await transactions.create(
      tipe: TxType.pengeluaran,
      nominal: 200000,
      tanggal: DateTime(now.year, now.month - 1, 15),
      kategoriId: 'makanan',
      akunId: akunId,
    );
    await transactions.create(
      tipe: TxType.pengeluaran,
      nominal: 50000,
      tanggal: now,
      kategoriId: 'makanan',
      akunId: akunId,
    );

    await nyalakan(tester);

    expect(find.text('Sisa'), findsOneWidget);
    // 1.000.000 - 200.000 - 50.000
    expect(find.text('Rp 750.000'), findsOneWidget);

    await bereskan(tester);
  });

  testWidgets('tab Anggaran menampilkan Sisa periode lalu', (tester) async {
    final now = DateTime.now();
    final akunId = await buatAkun(1000000);
    await transactions.create(
      tipe: TxType.pengeluaran,
      nominal: 200000,
      tanggal: DateTime(now.year, now.month - 1, 15),
      kategoriId: 'makanan',
      akunId: akunId,
    );

    await nyalakan(tester);
    await bukaTab(tester, 'Anggaran');

    expect(find.text('Sisa periode lalu'), findsOneWidget);
    // 1.000.000 - 200.000, dihitung sampai akhir bulan lalu.
    expect(find.text('Rp 800.000'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await bereskan(tester);
  });

  testWidgets('Sisa uang negatif tampil dengan tanda minus yang benar', (tester) async {
    final now = DateTime.now();
    final akunId = await buatAkun(100000);
    await transactions.create(
      tipe: TxType.pengeluaran,
      nominal: 350000,
      tanggal: now,
      kategoriId: 'makanan',
      akunId: akunId,
    );

    await nyalakan(tester);

    // 100.000 - 350.000, memakai minus U+2212 bukan tanda hubung formatter.
    expect(find.text('−Rp 250.000'), findsOneWidget);

    await bereskan(tester);
  });

  /// Nilai sebuah petak statistik di Dashboard, dicari lewat labelnya. Nominal
  /// yang sama juga muncul di daftar transaksi terbaru, jadi mencari langsung
  /// berdasarkan teks nominal akan salah sasaran.
  String nilaiStat(WidgetTester tester, String label) {
    final kolom = find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first;
    return tester
        .widget<Text>(
          find.descendant(of: kolom, matching: find.textContaining('Rp')),
        )
        .data!;
  }

  Future<void> catatPemasukanDanPengeluaran(
    DateTime now,
    String akunId,
  ) async {
    await transactions.create(
      tipe: TxType.pemasukan,
      nominal: 100000,
      tanggal: now,
      akunId: akunId,
    );
    await transactions.create(
      tipe: TxType.pengeluaran,
      nominal: 50000,
      tanggal: now,
      kategoriId: 'makanan',
      akunId: akunId,
    );
  }

  testWidgets('saldo awal nol: Sisa sama dengan Selisih', (tester) async {
    final now = DateTime.now();
    final akunId = await buatAkun(0);
    await catatPemasukanDanPengeluaran(now, akunId);

    await nyalakan(tester);

    // Arus bulan ini (100.000 - 50.000) sekaligus stok akhir bulan, karena
    // saldo awalnya nol dan belum ada transaksi sebelumnya. Karena itu keduanya
    // memang harus sama.
    expect(nilaiStat(tester, 'Selisih'), 'Rp 50.000');
    expect(nilaiStat(tester, 'Sisa'), 'Rp 50.000');

    await bereskan(tester);
  });

  testWidgets('ada saldo awal: Sisa berbeda dari Selisih', (tester) async {
    final now = DateTime.now();
    final akunId = await buatAkun(1000000);
    await catatPemasukanDanPengeluaran(now, akunId);

    await nyalakan(tester);

    // Selisih bulan ini 50.000, tetapi uang yang tersisa 1.050.000.
    expect(nilaiStat(tester, 'Selisih'), 'Rp 50.000');
    expect(nilaiStat(tester, 'Sisa'), 'Rp 1.050.000');

    await bereskan(tester);
  });
}
