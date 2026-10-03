import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/finance.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../util/color.dart';
import '../../util/format.dart';
import '../../widgets/charts.dart';
import '../../widgets/neo.dart';

/// Rekap bulanan + grafik (Bagian FR-4 & FR-5): donut per kategori, tabel
/// persentase, bar 12 bulan, dan delta vs bulan sebelumnya. Filter kategori
/// memengaruhi tabel & grafik.
class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key});

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _kategoriId;

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    // Seluruh angka rekap dihitung di SQL (Bagian 6 & 16 PRD) — layar ini
    // tidak lagi memuat semua transaksi ke memori.
    final totalsAsync = ref.watch(
      monthTotalsProvider((
        year: _month.year,
        month: _month.month,
        kategoriId: _kategoriId,
      )),
    );
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    // Label & warna tetap benar walau kategorinya sudah dihapus.
    final allCategories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final catById = {for (final c in allCategories) c.id: c};

    return totalsAsync.when(
      loading: () => const NeoLoading(),
      error: (e, _) => NeoError(message: '$e'),
      data: (totals) {
        // Delta vs bulan sebelumnya (FR-4.5).
        final prevMonth = DateTime(_month.year, _month.month - 1);
        final prevTotals = ref
                .watch(
                  monthTotalsProvider((
                    year: prevMonth.year,
                    month: prevMonth.month,
                    kategoriId: _kategoriId,
                  )),
                )
                .value ??
            const Totals(0, 0);

        // Ikut terfilter kategori — tabel & grafik harus konsisten dengan
        // chip filter (FR-4.3/FR-5.5).
        final byCat = ref
                .watch(
                  monthExpenseByCategoryProvider((
                    year: _month.year,
                    month: _month.month,
                    kategoriId: _kategoriId,
                  )),
                )
                .value ??
            const <CategoryTotal>[];
        final now = DateTime.now();
        final series = ref
                .watch(
                  monthlySeriesProvider((
                    months: 12,
                    year: now.year,
                    month: now.month,
                  )),
                )
                .value ??
            const <MonthPoint>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _monthSelector(),
            const SizedBox(height: 12),
            NeoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _stat('Masuk', rupiah(totals.income), Neo.income)),
                      Expanded(child: _stat('Keluar', rupiah(totals.expense), Neo.expense)),
                      Expanded(child: _stat('Selisih', rupiah(totals.net), Neo.transfer)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _deltaLine(totals.expense, prevTotals.expense),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _categoryFilter(categories),
            const SizedBox(height: 12),
            if (totals.expense == 0)
              NeoCard(
                child: Text(
                  'Belum ada pengeluaran pada bulan/filter ini.',
                  style: TextStyle(color: Neo.muted, fontSize: 12),
                ),
              )
            else ...[
              NeoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NeoSectionTitle('Persentase pengeluaran'),
                    const SizedBox(height: 12),
                    ExpenseDonut(
                      byCat: byCat,
                      catById: catById,
                      totalExpense: totals.expense,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _table(byCat, catById, totals.expense),
            ],
            const SizedBox(height: 12),
            NeoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NeoSectionTitle('Masuk vs Keluar (12 bulan)'),
                  const SizedBox(height: 12),
                  MonthlyBars(series: series),
                ],
              ),
            ),
            const SizedBox(height: 12),
            NeoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NeoSectionTitle('Tren saldo kumulatif'),
                  const SizedBox(height: 12),
                  NetTrendChart(series: series),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _deltaLine(int expense, int prevExpense) {
    if (prevExpense <= 0) {
      // Pembagi nol: persentase tak terdefinisi — tampilkan "—", bukan NaN
      // (Bagian 13 PRD).
      return Text(
        expense > 0
            ? 'Perubahan vs bulan lalu: — (belum ada pembanding)'
            : 'Belum ada pengeluaran bulan ini.',
        style: TextStyle(fontSize: 11, color: Neo.muted),
      );
    }
    final delta = (expense - prevExpense) / prevExpense * 100;
    final naik = delta >= 0;
    return Text(
      'Keluar ${naik ? 'naik' : 'turun'} ${delta.abs().toStringAsFixed(1)}% vs bulan sebelumnya',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: naik ? Neo.expense : Neo.income,
      ),
    );
  }

  Widget _monthSelector() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
      Text(
        DateFormat('MMMM yyyy', 'id_ID').format(_month),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
    ],
  );

  Widget _stat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 11, color: Neo.muted)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
    ],
  );

  Widget _categoryFilter(List<Category> categories) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _chip('Semua', _kategoriId == null, () => setState(() => _kategoriId = null)),
        ...categories.map(
          (c) => _chip(
            c.nama,
            _kategoriId == c.id,
            () => setState(() => _kategoriId = _kategoriId == c.id ? null : c.id),
          ),
        ),
      ],
    ),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Neo.accent,
      backgroundColor: Neo.surface,
      side: BorderSide(color: Neo.ink, width: Neo.borderW),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );

  Widget _table(
    List<CategoryTotal> byCat,
    Map<String, Category> catById,
    int totalExpense,
  ) {
    return NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NeoSectionTitle('Rekap per kategori'),
          const SizedBox(height: 8),
          ...byCat.map((c) {
            final cat = c.kategoriId == null ? null : catById[c.kategoriId];
            final pct = totalExpense == 0 ? 0.0 : c.total / totalExpense * 100;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          cat?.nama ?? 'Tanpa kategori',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${rupiah(c.total)}  (${pct.toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: Neo.bg,
                      valueColor: AlwaysStoppedAnimation(parseHexColor(cat?.warna)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
