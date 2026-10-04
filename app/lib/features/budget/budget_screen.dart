import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/finance.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../util/budget.dart';
import '../../util/format.dart';
import '../../widgets/neo.dart';

/// Anggaran (Bagian FR-6): batas total & per kategori dengan rentang tanggal,
/// progressbar berwarna hijau→merah (Bagian 8.2).
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  String? _kategoriId; // null = semua (FR-6.5)

  Widget _filterChip(String label, bool selected, VoidCallback onTap) => Padding(
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

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final txs = ref.watch(allTransactionsProvider).value ?? const <Transaction>[];
    final ownIds = ref.watch(ownAccountIdsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    // Judul anggaran tetap benar walau kategorinya sudah dihapus.
    final allCategories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final catById = {for (final c in allCategories) c.id: c};

    return Scaffold(
      body: budgetsAsync.when(
        loading: () => const NeoLoading(),
        error: (e, _) => NeoError(message: '$e'),
        data: (allBudgets) {
          final budgets = _kategoriId == null
              ? allBudgets
              : allBudgets
                  .where((b) =>
                      b.lingkup == BudgetScope.kategori &&
                      b.kategoriId == _kategoriId)
                  .toList();
          final filter = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Semua', _kategoriId == null,
                    () => setState(() => _kategoriId = null)),
                ...categories.map(
                  (c) => _filterChip(c.nama, _kategoriId == c.id,
                      () => setState(() => _kategoriId = _kategoriId == c.id ? null : c.id)),
                ),
              ],
            ),
          );
          if (budgets.isEmpty) {
            return Column(
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: filter),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        allBudgets.isEmpty
                            ? 'Belum ada anggaran. Tekan + untuk menetapkan batas pengeluaran.'
                            : 'Tidak ada anggaran untuk filter ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Neo.muted),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: filter),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: budgets.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
              final b = budgets[i];
              final usage = budgetUsageOf(b, txs, ownIds);
              final level = budgetLevel(usage.fraction);
              final color = budgetColor(level);
              final judul = b.lingkup == BudgetScope.total
                  ? 'Total pengeluaran'
                  : (catById[b.kategoriId]?.nama ?? 'Kategori');
              return NeoCard(
                onTap: () => showBudgetForm(context, ref, categories, initial: b),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            judul,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
                    Text(
                      '${DateFormat('d MMM yyyy', 'id_ID').format(b.periodeMulai)} – '
                      '${DateFormat('d MMM yyyy', 'id_ID').format(b.periodeSelesai)}'
                      '${b.aktif ? '' : ' • nonaktif'}',
                      style: TextStyle(color: Neo.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: usage.fraction.clamp(0, 1),
                        minHeight: 12,
                        backgroundColor: Neo.bg,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'sisa ${sisaAnggaranTeks(usage.remaining)} / ${rupiah(b.nominal)} '
                      '(${(usage.fraction * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
                },
              ),
            ),
          ],
        );
        },
      ),
      // Tombol tambah dipindah ke shell (lihat `ShellScreen._buildFab`), supaya
      // FAB dan SnackBar berada di Scaffold yang sama.
      floatingActionButton: null,
    );
  }
}

/// Membuka form tambah/ubah anggaran.
///
/// Publik karena dipanggil dari [ShellScreen] lewat FAB-nya.
Future<void> showBudgetForm(
  BuildContext context,
  WidgetRef ref,
  List<Category> categories, {
  Budget? initial,
}) async {
  final repo = ref.read(budgetRepositoryProvider);
  final nominalCtrl = TextEditingController(
    text: initial == null ? '' : formatThousands(initial.nominal),
  );
  var lingkup = initial?.lingkup ?? BudgetScope.total;
  String? kategoriId = initial?.kategoriId;
  var mulai = initial?.periodeMulai ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
  var selesai = initial?.periodeSelesai ??
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  var aktif = initial?.aktif ?? true;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(initial == null ? 'Tambah Anggaran' : 'Ubah Anggaran'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lingkup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _chip('Total', lingkup == BudgetScope.total, () => setState(() => lingkup = BudgetScope.total)),
                  const SizedBox(width: 8),
                  _chip('Per kategori', lingkup == BudgetScope.kategori,
                      () => setState(() => lingkup = BudgetScope.kategori)),
                ],
              ),
              if (lingkup == BudgetScope.kategori) ...[
                const SizedBox(height: 12),
                const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((c) {
                    final selected = c.id == kategoriId;
                    return _chip(c.nama, selected,
                        () => setState(() => kategoriId = selected ? null : c.id));
                  }).toList(),
                ),
              ],
              const SizedBox(height: 14),
              NeoTextField(
                controller: nominalCtrl,
                label: 'Batas maksimum',
                hint: '0',
                prefixText: 'Rp ',
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsInputFormatter()],
              ),
              const SizedBox(height: 14),
              const Text('Periode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: ctx,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDateRange: DateTimeRange(start: mulai, end: selesai),
                  );
                  if (picked != null) {
                    setState(() {
                      mulai = picked.start;
                      selesai = picked.end;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: Neo.box(),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 16),
                      const SizedBox(width: 10),
                      Text(
                        '${DateFormat('d MMM yyyy', 'id_ID').format(mulai)} – '
                        '${DateFormat('d MMM yyyy', 'id_ID').format(selesai)}',
                      ),
                    ],
                  ),
                ),
              ),
              if (initial != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  value: aktif,
                  activeThumbColor: Neo.ink,
                  onChanged: (v) => setState(() => aktif = v),
                ),
            ],
          ),
        ),
        actions: [
          if (initial != null)
            TextButton(
              onPressed: () async {
                await repo.softDelete(initial.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Hapus', style: TextStyle(color: Neo.expense)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          NeoButton(
            label: 'Simpan',
            onPressed: () async {
              final nominal = parseRupiah(nominalCtrl.text);
              if (nominal <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Batas harus lebih dari 0')),
                );
                return;
              }
              if (lingkup == BudgetScope.kategori && kategoriId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Pilih kategorinya')),
                );
                return;
              }
              if (initial == null) {
                await repo.create(
                  lingkup: lingkup,
                  kategoriId: kategoriId,
                  periodeMulai: mulai,
                  periodeSelesai: selesai,
                  nominal: nominal,
                );
              } else {
                await repo.update(
                  id: initial.id,
                  lingkup: lingkup,
                  kategoriId: kategoriId,
                  periodeMulai: mulai,
                  periodeSelesai: selesai,
                  nominal: nominal,
                  aktif: aktif,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
  nominalCtrl.dispose();
}

Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
  label: Text(label),
  selected: selected,
  onSelected: (_) => onTap(),
  selectedColor: Neo.accent,
  backgroundColor: Neo.surface,
  side: BorderSide(color: Neo.ink, width: Neo.borderW),
  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
);
