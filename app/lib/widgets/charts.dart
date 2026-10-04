import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/finance.dart';
import '../theme/app_theme.dart';
import '../util/color.dart';
import '../util/format.dart';

/// Palet cadangan bila kategori belum punya warna sendiri.
const _chartPalette = [
  Color(0xFFD98C7A),
  Color(0xFFE0B36B),
  Color(0xFF7FA0CC),
  Color(0xFFA08CC0),
  Color(0xFF6FBFA8),
  Color(0xFFD79AC0),
  Color(0xFF86C4D6),
  Color(0xFF8B93CE),
];

/// Satu potongan grafik (setelah kategori kecil digabung).
class ChartSlice {
  const ChartSlice({
    required this.label,
    required this.total,
    required this.color,
  });

  final String label;
  final int total;
  final Color color;
}

/// Label gabungan untuk kategori kecil.
const String kOtherSliceLabel = 'Lainnya';

/// Pesan saat belum ada data bulanan, dipakai bersama oleh grafik batang dan
/// grafik tren supaya keadaan kosongnya seragam.
const String kNoMonthlyData = 'Belum ada data 12 bulan.';

/// Porsi minimum sebuah kategori agar tampil sendiri di grafik. Kategori di
/// bawah ambang ini digabung jadi satu potongan "Lainnya" supaya legend tidak
/// ramai saat kategorinya banyak (mitigasi risiko Bagian 16 PRD).
const double kChartGroupBelowShare = 0.03;

/// Susun potongan grafik dari total per kategori.
///
/// Bila ada **lebih dari satu** kategori kecil, semuanya digabung jadi satu
/// potongan "Lainnya" sehingga jumlah seluruh potongan tetap sama dengan
/// [totalExpense] (persentase tetap berjumlah 100%).
List<ChartSlice> buildChartSlices({
  required List<CategoryTotal> byCat,
  required Map<String, Category> catById,
  required int totalExpense,
  double groupBelowShare = kChartGroupBelowShare,
}) {
  if (totalExpense <= 0 || byCat.isEmpty) return const [];

  String labelOf(CategoryTotal c) =>
      (c.kategoriId == null ? null : catById[c.kategoriId]?.nama) ??
      'Tanpa kategori';

  Color colorOf(CategoryTotal c, int paletteIndex) => parseHexColor(
    c.kategoriId == null ? null : catById[c.kategoriId]?.warna,
    fallback: _chartPalette[paletteIndex % _chartPalette.length],
  );

  final big = <CategoryTotal>[];
  final small = <CategoryTotal>[];
  for (final c in byCat) {
    if (c.total / totalExpense < groupBelowShare) {
      small.add(c);
    } else {
      big.add(c);
    }
  }

  final slices = <ChartSlice>[
    for (var i = 0; i < big.length; i++)
      ChartSlice(
        label: labelOf(big[i]),
        total: big[i].total,
        color: colorOf(big[i], i),
      ),
  ];

  if (small.length > 1) {
    slices.add(
      ChartSlice(
        label: kOtherSliceLabel,
        total: small.fold(0, (sum, c) => sum + c.total),
        color: parseHexColor(null),
      ),
    );
  } else {
    // Satu kategori kecil tidak perlu digabung — biarkan tampil apa adanya.
    for (var i = 0; i < small.length; i++) {
      slices.add(
        ChartSlice(
          label: labelOf(small[i]),
          total: small[i].total,
          color: colorOf(small[i], big.length + i),
        ),
      );
    }
  }

  return slices;
}

/// Donut persentase pengeluaran per kategori, dengan label aksesibilitas.
class ExpenseDonut extends StatelessWidget {
  const ExpenseDonut({
    super.key,
    required this.byCat,
    required this.catById,
    required this.totalExpense,
    this.height = 200,
    this.showLegend = true,
  });

  final List<CategoryTotal> byCat;
  final Map<String, Category> catById;
  final int totalExpense;
  final double height;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final slices = buildChartSlices(
      byCat: byCat,
      catById: catById,
      totalExpense: totalExpense,
    );
    if (slices.isEmpty) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];
    for (final s in slices) {
      final pct = s.total / totalExpense * 100;
      sections.add(
        PieChartSectionData(
          value: s.total.toDouble(),
          color: s.color,
          radius: 52,
          title: pct >= 7 ? '${pct.toStringAsFixed(0)}%' : '',
          titleStyle: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: Neo.ink,
          ),
        ),
      );
    }

    // Ringkasan untuk screen reader (NFR aksesibilitas).
    final spoken = slices
        .map((s) => '${s.label} ${(s.total / totalExpense * 100).toStringAsFixed(0)} persen')
        .join(', ');

    return Semantics(
      label: 'Grafik donat pengeluaran per kategori: $spoken',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 46,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          if (showLegend) ...[
            const SizedBox(height: 12),
            ...slices.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: s.color,
                        border: Border.all(color: Neo.ink, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.label, style: const TextStyle(fontSize: 12)),
                    ),
                    Text(
                      '${(s.total / totalExpense * 100).toStringAsFixed(1)}%  ${rupiah(s.total)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bar pemasukan vs pengeluaran per bulan, dengan label aksesibilitas.
class MonthlyBars extends StatelessWidget {
  const MonthlyBars({super.key, required this.series, this.height = 190});

  final List<MonthPoint> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxY = series
        .expand((p) => [p.income, p.expense])
        .fold<int>(0, (a, b) => a > b ? a : b)
        .toDouble();
    if (maxY == 0) {
      return Text(kNoMonthlyData, style: TextStyle(color: Neo.muted, fontSize: 12));
    }
    final last = series.isNotEmpty ? series.last : null;
    return Semantics(
      label: last == null
          ? 'Grafik batang pemasukan dan pengeluaran bulanan'
          : 'Grafik batang pemasukan dan pengeluaran bulanan. '
              'Bulan terakhir masuk ${rupiah(last.income)}, keluar ${rupiah(last.expense)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Legend(color: Neo.income, label: 'Masuk'),
              const SizedBox(width: 12),
              _Legend(color: Neo.expense, label: 'Keluar'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.15,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= series.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('MMM', 'id_ID').format(series[i].month),
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < series.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 2,
                      barRods: [
                        BarChartRodData(
                          toY: series[i].income.toDouble(),
                          color: Neo.income,
                          width: 6,
                          borderSide: BorderSide(color: Neo.ink, width: 1),
                        ),
                        BarChartRodData(
                          toY: series[i].expense.toDouble(),
                          color: Neo.expense,
                          width: 6,
                          borderSide: BorderSide(color: Neo.ink, width: 1),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Garis tren saldo kumulatif bulanan (FR-5.3, opsional v1.1).
class NetTrendChart extends StatelessWidget {
  const NetTrendChart({super.key, required this.series, this.height = 170});

  final List<MonthPoint> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    var running = 0;
    for (var i = 0; i < series.length; i++) {
      running += series[i].income - series[i].expense;
      spots.add(FlSpot(i.toDouble(), running.toDouble()));
    }
    // Tanpa data, jangan menggambar garis datar: itu terlihat seperti saldo nol
    // yang nyata. Tampilkan pesan kosong yang sama dengan grafik batang.
    final adaData = series.any((p) => p.income != 0 || p.expense != 0);
    if (spots.isEmpty || !adaData) {
      return Text(kNoMonthlyData, style: TextStyle(color: Neo.muted, fontSize: 12));
    }
    var minY = spots.first.y;
    var maxY = spots.first.y;
    for (final s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    final pad = ((maxY - minY).abs() * 0.1) + 1;

    return Semantics(
      label: 'Grafik garis tren saldo kumulatif. Saldo terakhir ${rupiah(running)}.',
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            minY: minY - pad,
            maxY: maxY + pad,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= series.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('MMM', 'id_ID').format(series[i].month),
                        style: const TextStyle(fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 3,
                color: Neo.transfer,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Neo.transfer.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, border: Border.all(color: Neo.ink, width: 1.5)),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
