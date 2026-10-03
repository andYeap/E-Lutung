import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/finance.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../../widgets/neo.dart';
import 'transaction_form_screen.dart';

/// Riwayat transaksi + filter + pencarian (Bagian FR-3).
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _kw = TextEditingController();
  TxType? _tipe;
  String? _kategoriId;
  String? _akunId;
  DateTimeRange? _range;

  @override
  void dispose() {
    _kw.dispose();
    super.dispose();
  }

  Future<void> _openForm(TxType tipe) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionFormScreen(tipe: tipe)),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(transactionRepositoryProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final ownIds = ref.watch(ownAccountIdsProvider);

    // Label & pencarian tetap mengenali kategori yang sudah dihapus.
    final allCategories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final catName = {for (final c in allCategories) c.id: c.nama};
    final accName = {
      for (final a in accounts) a.account.id: a.institusi.nama,
    };

    return Scaffold(
      body: Column(
        children: [
          _filters(categories, accounts),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: repo.watchFiltered(
                tipe: _tipe,
                kategoriId: _kategoriId,
                akunId: _akunId,
                from: _range?.start,
                to: _range?.end == null
                    ? null
                    : DateTime(
                        _range!.end.year,
                        _range!.end.month,
                        _range!.end.day,
                        23,
                        59,
                        59,
                      ),
              ),
              builder: (context, snap) {
                if (snap.hasError) {
                  return NeoError(message: '${snap.error}');
                }
                if (!snap.hasData) {
                  return const NeoLoading();
                }
                var items = snap.data!;
                final kw = _kw.text.trim().toLowerCase();
                if (kw.isNotEmpty) {
                  items = items.where((t) {
                    final hay = [
                      t.catatan ?? '',
                      catName[t.kategoriId] ?? '',
                      accName[t.akunId] ?? '',
                      accName[t.akunAsalId] ?? '',
                      accName[t.akunTujuanId] ?? '',
                    ].join(' ').toLowerCase();
                    return hay.contains(kw);
                  }).toList();
                }
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Belum ada transaksi pada rentang/filter ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Neo.muted),
                      ),
                    ),
                  );
                }
                final totals = computeTotals(items, ownIds);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    _summary(totals),
                    ..._grouped(items, catName, accName, ownIds),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _fab('Transfer', Icons.swap_horiz, () => _openForm(TxType.transfer)),
          const SizedBox(height: 10),
          _fab('Pemasukan', Icons.south_west, () => _openForm(TxType.pemasukan)),
          const SizedBox(height: 10),
          _fab('Pengeluaran', Icons.north_east, () => _openForm(TxType.pengeluaran)),
        ],
      ),
    );
  }

  Widget _fab(String label, IconData icon, VoidCallback onTap) {
    return FloatingActionButton.extended(
      heroTag: label,
      onPressed: onTap,
      backgroundColor: Neo.accent,
      foregroundColor: Neo.ink,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Neo.radius),
        side: BorderSide(color: Neo.ink, width: Neo.borderW),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _filters(List<Category> categories, List<AccountWithInstitution> accounts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _kw,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari catatan / kategori / akun…',
              isDense: true,
              filled: true,
              fillColor: Neo.surface,
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Neo.radius),
                borderSide: BorderSide(color: Neo.ink, width: Neo.borderW),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Neo.radius),
                borderSide: BorderSide(color: Neo.ink, width: 3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Semua', _tipe == null, () => setState(() => _tipe = null)),
                _filterChip('Masuk', _tipe == TxType.pemasukan,
                    () => setState(() => _tipe = TxType.pemasukan)),
                _filterChip('Keluar', _tipe == TxType.pengeluaran,
                    () => setState(() => _tipe = TxType.pengeluaran)),
                _filterChip('Transfer', _tipe == TxType.transfer,
                    () => setState(() => _tipe = TxType.transfer)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  _range == null
                      ? 'Rentang tanggal'
                      : '${DateFormat('d MMM', 'id_ID').format(_range!.start)} – ${DateFormat('d MMM', 'id_ID').format(_range!.end)}',
                  _range != null,
                  _pickRange,
                ),
                if (_range != null)
                  IconButton(
                    tooltip: 'Hapus rentang',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _range = null),
                  ),
                _filterChip('Semua kategori', _kategoriId == null,
                    () => setState(() => _kategoriId = null)),
                ...categories.map(
                  (c) => _filterChip(
                    c.nama,
                    _kategoriId == c.id,
                    () => setState(() => _kategoriId = _kategoriId == c.id ? null : c.id),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Filter per akun (FR-3.2).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Semua akun', _akunId == null, () => setState(() => _akunId = null)),
                ...accounts.map(
                  (a) => _filterChip(
                    a.institusi.nama,
                    _akunId == a.account.id,
                    () => setState(() => _akunId = _akunId == a.account.id ? null : a.account.id),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
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
  }

  Widget _summary(Totals totals) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: Neo.box(),
      child: Row(
        children: [
          Expanded(
            child: _miniStat('Masuk', rupiah(totals.income), Neo.income, Icons.south_west),
          ),
          Expanded(
            child: _miniStat('Keluar', rupiah(totals.expense), Neo.expense, Icons.north_east),
          ),
          Expanded(
            child: _miniStat('Selisih', rupiah(totals.net), Neo.transfer, Icons.balance),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Neo.muted)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      ],
    );
  }

  List<Widget> _grouped(
    List<Transaction> items,
    Map<String, String> catName,
    Map<String, String> accName,
    Set<String> ownIds,
  ) {
    final sorted = [...items]
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    // Kelompokkan per tanggal sekaligus hitung subtotal harian (FR-3.4).
    final groups = <String, List<Transaction>>{};
    for (final t in sorted) {
      final d = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(t.tanggal);
      groups.putIfAbsent(d, () => []).add(t);
    }
    final widgets = <Widget>[];
    groups.forEach((d, dayTx) {
      final day = computeTotals(dayTx, ownIds);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  d,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              Text(
                '+${rupiah(day.income)}  −${rupiah(day.expense)}',
                style: TextStyle(fontSize: 11, color: Neo.muted),
              ),
            ],
          ),
        ),
      );
      for (final t in dayTx) {
        widgets.add(_row(t, catName, accName, ownIds));
      }
    });
    return widgets;
  }

  Widget _row(
    Transaction t,
    Map<String, String> catName,
    Map<String, String> accName,
    Set<String> ownIds,
  ) {
    final (color, icon, sign) = switch (t.tipe) {
      TxType.pemasukan => (Neo.income, Icons.south_west, '+'),
      TxType.pengeluaran => (Neo.expense, Icons.north_east, '−'),
      TxType.transfer => (Neo.transfer, Icons.swap_horiz, ''),
    };
    final title = switch (t.tipe) {
      TxType.transfer =>
        'Transfer: ${accName[t.akunAsalId] ?? '?'} → ${accName[t.akunTujuanId] ?? '?'}',
      _ => catName[t.kategoriId] ?? 'Tanpa kategori',
    };
    final subs = <String>[
      if (t.tipe != TxType.transfer && t.akunId != null &&
          (accName[t.akunId] ?? '').isNotEmpty)
        accName[t.akunId]!,
      if (t.tipe == TxType.transfer && t.biayaAdmin > 0)
        'Admin ${rupiah(t.biayaAdmin)}',
      if (t.recurringRuleId != null) 'dari jadwal',
      if ((t.catatan ?? '').isNotEmpty) t.catatan!,
    ];
    final amountLabel = t.tipe == TxType.transfer
        ? rupiah(t.nominal)
        : '$sign${rupiah(t.nominal)}';

    return NeoCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TransactionFormScreen(tipe: t.tipe, initial: t),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (subs.isNotEmpty)
                  Text(subs.join(' • '), style: TextStyle(color: Neo.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(amountLabel, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
