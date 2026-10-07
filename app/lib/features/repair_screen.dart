import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/recurring.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/neo.dart';
import 'recurring/recurring_screen.dart';
import 'transactions/transaction_form_screen.dart';

/// Transaksi yang belum punya akun.
///
/// Transfer tidak dihitung: ia memang tidak memakai `akunId`, melainkan
/// `akunAsalId` dan `akunTujuanId` yang sudah wajib diisi.
List<Transaction> transaksiTanpaAkun(List<Transaction> txs) => txs
    .where((t) => t.tipe != TxType.transfer && t.akunId == null)
    .toList()
  ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

/// Aturan berulang yang belum punya akun, sehingga transaksi yang dibangkitkan
/// jadwalnya ikut tanpa akun.
List<RecurringRule> aturanTanpaAkun(List<RecurringRule> rules) =>
    rules.where((r) => r.akunId == null).toList();

/// "Perlu dibenahi": catatan lama yang belum punya akun. Sejak akun diwajibkan
/// pada transaksi baru, data yang dibuat sebelum aturan itu bisa tertinggal
/// tanpa akun. Semuanya dikumpulkan di sini supaya bisa dibetulkan lewat form
/// yang sama dengan pencatatan biasa, jadi aturan barunya ikut berlaku saat
/// dibetulkan.
class RepairScreen extends ConsumerWidget {
  const RepairScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaksi = transaksiTanpaAkun(
      ref.watch(allTransactionsProvider).value ?? const <Transaction>[],
    );
    final aturan = aturanTanpaAkun(
      ref.watch(recurringRulesProvider).value ?? const <RecurringRule>[],
    );
    // Label kategori tetap benar walau kategorinya sudah dihapus.
    final catName = {
      for (final c
          in ref.watch(allCategoriesProvider).value ?? const <Category>[])
        c.id: c.nama,
    };
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final accounts = ref.watch(accountsProvider).value ?? const [];

    if (transaksi.isEmpty && aturan.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perlu dibenahi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Tidak ada yang perlu dibenahi. Semua transaksi dan jadwal sudah '
              'punya akun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Neo.muted),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perlu dibenahi')),
      // Ruang untuk bilah navigasi sistem; tanpa ini kartu terbawah tertutup.
      bottomNavigationBar: SizedBox(
        height: MediaQuery.viewPaddingOf(context).bottom,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NeoCard(
            child: Text(
              'Catatan lama di bawah ini belum punya akun, jadi saldo akun tidak '
              'ikut menghitungnya. Ketuk salah satu untuk memilih akunnya.',
              style: TextStyle(color: Neo.muted, fontSize: 12),
            ),
          ),
          if (transaksi.isNotEmpty) ...[
            const SizedBox(height: 16),
            NeoSectionTitle('Transaksi tanpa akun (${transaksi.length})'),
            for (final t in transaksi) ...[
              const SizedBox(height: 12),
              NeoCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        TransactionFormScreen(tipe: t.tipe, initial: t),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      t.tipe == TxType.pemasukan
                          ? Icons.south_west
                          : Icons.north_east,
                      size: 18,
                      color: t.tipe == TxType.pemasukan
                          ? Neo.income
                          : Neo.expense,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            catName[t.kategoriId] ?? 'Tanpa kategori',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            DateFormat('d MMM yyyy', 'id_ID').format(t.tanggal),
                            style: TextStyle(color: Neo.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${t.tipe == TxType.pemasukan ? '+' : '−'}${rupiah(t.nominal)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: t.tipe == TxType.pemasukan
                            ? Neo.income
                            : Neo.expense,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (aturan.isNotEmpty) ...[
            const SizedBox(height: 16),
            NeoSectionTitle('Aturan berulang tanpa akun (${aturan.length})'),
            for (final r in aturan) ...[
              const SizedBox(height: 12),
              NeoCard(
                onTap: () =>
                    showRecurringForm(context, ref, categories, accounts, initial: r),
                child: Row(
                  children: [
                    const Icon(Icons.repeat, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            catName[r.kategoriId] ?? 'Tanpa kategori',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${frequencyLabel(r.frekuensi)} • ${r.aktif ? 'aktif' : 'nonaktif'}',
                            style: TextStyle(color: Neo.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      rupiah(r.nominal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
