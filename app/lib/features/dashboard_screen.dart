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
          // Sisa uang: saldo seluruh akun sendiri sampai akhir bulan terpilih,
          // jadi untuk bulan yang sudah lewat angkanya adalah sisa saat itu.
          final sisa = sisaUangSampai(
            accounts.map((a) => a.account).toList(),
            all,
            DateTime(_month.year, _month.month + 1, 0),
          );
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
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(
                            label: 'Selisih',
                            value: rupiahSigned(totals.net),
                            color: Neo.transfer,
                            icon: Icons.balance,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Stat(
                            label: 'Sisa',
                            value: rupiahSigned(sisa),
                            // Uang yang tersisa; merah bila sudah minus.
                            color: sisa < 0 ? Neo.expense : Neo.income,
                            icon: Icons.savings,
                          ),
                        ),
                      ],
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

  /// Maksimal baris anggaran terpakai yang ditampilkan; sisanya diringkas jadi
  /// satu catatan supaya kartu di Dashboard tidak memanjang.
  static const _maksBaris = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
    final catName = {
      for (final c
          in ref.watch(allCategoriesProvider).value ?? const <Category>[])
        c.id: c.nama,
    };
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

    if (berlaku.isEmpty) {
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

    // Hanya anggaran yang sudah terpakai yang ditampilkan, dan yang paling
    // terkuras lebih dulu: itu yang perlu ditindak. Anggaran yang belum
    // tersentuh tidak perlu memakan ruang di Dashboard.
    final terpakai = <(Budget, BudgetUsage)>[];
    for (final b in berlaku) {
      final usage = budgetUsageOf(b, all, ownIds);
      if (usage.used > 0) terpakai.add((b, usage));
    }
    terpakai.sort((a, b) => b.$2.fraction.compareTo(a.$2.fraction));
    final belumTerpakai = berlaku.length - terpakai.length;

    if (terpakai.isEmpty) {
      return NeoCard(
        child: Text(
          'Belum ada anggaran yang terpakai untuk periode ini. '
          '$belumTerpakai anggaran sudah disetel, buka tab Anggaran.',
          style: TextStyle(color: Neo.muted, fontSize: 12),
        ),
      );
    }

    final tampil = terpakai.take(_maksBaris).toList();
    final sisaTerpakai = terpakai.length - tampil.length;

    return NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NeoSectionTitle('Anggaran terpakai'),
          for (final (budget, usage) in tampil) ...[
            const SizedBox(height: 12),
            _BarisAnggaran(
              nama: budget.lingkup == BudgetScope.total
                  ? 'Total pengeluaran'
                  : (catName[budget.kategoriId] ?? 'Kategori'),
              usage: usage,
            ),
          ],
          if (sisaTerpakai > 0 || belumTerpakai > 0) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (sisaTerpakai > 0) '+$sisaTerpakai anggaran terpakai lain',
                if (belumTerpakai > 0)
                  '$belumTerpakai anggaran lain belum terpakai',
              ].join(' · '),
              style: TextStyle(color: Neo.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris anggaran di kartu Dashboard: nama, persentase terpakai, bar, dan
/// sisa. Warnanya mengikuti Bagian 8.2 lewat [budgetColor].
class _BarisAnggaran extends StatelessWidget {
  const _BarisAnggaran({required this.nama, required this.usage});

  final String nama;
  final BudgetUsage usage;

  @override
  Widget build(BuildContext context) {
    final color = budgetColor(budgetLevel(usage.fraction));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nama,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            Text(
              '${(usage.fraction * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: usage.fraction.clamp(0, 1),
            minHeight: 10,
            backgroundColor: Neo.bg,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'sisa ${sisaAnggaranTeks(usage.remaining)} / ${rupiah(usage.budget.nominal)}',
          style: TextStyle(color: Neo.muted, fontSize: 11),
        ),
      ],
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
