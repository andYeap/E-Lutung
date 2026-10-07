import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/finance.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../util/budget.dart';
import '../util/format.dart';
import '../widgets/charts.dart';
import '../widgets/neo.dart';

/// Dashboard (Bagian FR-1): ringkasan bulan terpilih, donut kategori,
/// anggaran aktif, transaksi terbaru, dan tombol tambah cepat.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(allTransactionsProvider);
    // Termasuk kategori terhapus agar transaksi lama tetap berlabel & berwarna.
    final categories = ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final ownIds = ref.watch(ownAccountIdsProvider);

    final catName = {for (final c in categories) c.id: c.nama};
    final catById = {for (final c in categories) c.id: c};
    final accName = {for (final a in accounts) a.account.id: a.institusi.nama};

    return Scaffold(
      body: txsAsync.when(
        loading: () => const NeoLoading(),
        error: (e, _) => NeoError(message: '$e'),
        data: (all) {
          // Penanda "Data belum ada" saat belum ada transaksi sama sekali.
          if (all.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                NeoCard(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: Neo.muted),
                      const SizedBox(height: 12),
                      const Text(
                        'Data belum ada',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Belum ada transaksi tersimpan. Mulai catat lewat tombol '
                        '"Tambah" di kanan bawah — pilih Pemasukan, Pengeluaran, atau Transfer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Neo.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          final monthTx = all
              .where((t) => t.tanggal.year == _month.year && t.tanggal.month == _month.month)
              .toList();
          final totals = computeTotals(monthTx, ownIds);
          final byCat = expenseByCategory(monthTx, ownIds);
          // FR-1.5: daftar terbaru ikut bulan terpilih.
          final recent = ([...monthTx]..sort((a, b) => b.tanggal.compareTo(a.tanggal)))
              .take(5)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                  Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(_month),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                ],
              ),
              const SizedBox(height: 6),
              NeoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(
                            label: 'Pemasukan',
                            value: rupiah(totals.income),
                            color: Neo.income,
                            icon: Icons.south_west,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Stat(
                            label: 'Pengeluaran',
                            value: rupiah(totals.expense),
                            color: Neo.expense,
                            icon: Icons.north_east,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Stat(
                      label: 'Selisih',
                      value: rupiah(totals.net),
                      color: Neo.transfer,
                      icon: Icons.balance,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _BudgetCard(all: all, ownIds: ownIds, month: _month),
              if (byCat.isNotEmpty) ...[
                const SizedBox(height: 12),
                NeoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const NeoSectionTitle('Pengeluaran per kategori'),
                      const SizedBox(height: 12),
                      ExpenseDonut(
                        byCat: byCat,
                        catById: catById,
                        totalExpense: totals.expense,
                        height: 180,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const NeoSectionTitle('Transaksi terbaru bulan ini'),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                NeoCard(
                  child: Text(
                    'Belum ada transaksi di bulan ini.',
                    style: TextStyle(color: Neo.muted, fontSize: 12),
                  ),
                )
              else
                ...recent.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecentRow(tx: t, catName: catName, accName: accName),
                  ),
                ),
            ],
          );
        },
      ),
      // Tombol tambah dimiliki shell, supaya FAB dan SnackBar satu Scaffold.
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({
    required this.all,
    required this.ownIds,
    required this.month,
  });
  final List<Transaction> all;
  final Set<String> ownIds;

  /// Bulan yang sedang ditampilkan dashboard; kartu anggaran ikut bulan ini,
  /// bukan selalu bulan berjalan.
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // Anggaran yang berlaku bulan ini: aktif dan periodenya beririsan, jadi
    // rentang seperti 5 Okt - 5 Nov tetap terhitung untuk bulan Oktober.
    final berlaku = budgets
        .where(
          (b) =>
              b.aktif &&
              !b.periodeMulai.isAfter(monthEnd) &&
              !b.periodeSelesai.isBefore(monthStart),
        )
        .toList();
    final ringkas = totalAnggaranOf(berlaku, all, ownIds);

    if (ringkas.kosong) {
      // Tanpa membedakan dua sebab ini, kartu mengaku tidak ada anggaran
      // padahal anggaran aktifnya hanya berada di periode lain.
      final adaPeriodeLain = budgets.any((b) => b.aktif);
      return NeoCard(
        child: Text(
          adaPeriodeLain
              ? 'Tidak ada anggaran yang mencakup periode ini. Anggaran aktif '
                    'lainnya ada di periode berbeda, buka tab Anggaran.'
              : 'Belum ada anggaran aktif untuk periode ini. Setel di tab Anggaran.',
          style: TextStyle(color: Neo.muted, fontSize: 12),
        ),
      );
    }

    final level = budgetLevel(ringkas.fraction);
    final color = budgetColor(level);
    return NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: NeoSectionTitle(
                  ringkas.dariKategori ? 'Total anggaran' : 'Anggaran aktif',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  border: Border.all(color: Neo.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  budgetLevelLabel(level),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ],
          ),
          if (ringkas.dariKategori) ...[
            const SizedBox(height: 2),
            Text(
              'gabungan ${ringkas.jumlahAnggaran} anggaran kategori · '
              'anggaran total belum disetel',
              style: TextStyle(color: Neo.muted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ringkas.fraction.clamp(0, 1),
              minHeight: 12,
              backgroundColor: Neo.bg,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'sisa ${sisaAnggaranTeks(ringkas.remaining)} / ${rupiah(ringkas.nominal)} '
            '(${(ringkas.fraction * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.tx, required this.catName, required this.accName});
  final Transaction tx;
  final Map<String, String> catName;
  final Map<String, String> accName;

  @override
  Widget build(BuildContext context) {
    final (color, icon, sign) = switch (tx.tipe) {
      TxType.pemasukan => (Neo.income, Icons.south_west, '+'),
      TxType.pengeluaran => (Neo.expense, Icons.north_east, '−'),
      TxType.transfer => (Neo.transfer, Icons.swap_horiz, ''),
    };
    final title = tx.tipe == TxType.transfer
        ? 'Transfer ${accName[tx.akunAsalId] ?? '?'} → ${accName[tx.akunTujuanId] ?? '?'}'
        : (catName[tx.kategoriId] ?? 'Tanpa kategori');
    return NeoCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  '${relativeTime(tx.tanggal)} • '
                  '${DateFormat('HH:mm').format(tx.tanggal)}'
                  '${tx.recurringRuleId == null ? '' : ' • dari jadwal'}',
                  style: TextStyle(color: Neo.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            tx.tipe == TxType.transfer ? rupiah(tx.nominal) : '$sign${rupiah(tx.nominal)}',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: Neo.box(shadow: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: Neo.muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}
