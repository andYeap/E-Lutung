import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/recurring.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/neo.dart';

/// Sampah — semua item yang dihapus (transaksi, kategori, akun, institusi,
/// anggaran) bisa dipulihkan dari sini.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txRepo = ref.watch(transactionRepositoryProvider);
    final catRepo = ref.watch(categoryRepositoryProvider);
    final accRepo = ref.watch(accountRepositoryProvider);
    final instRepo = ref.watch(institutionRepositoryProvider);
    final budRepo = ref.watch(budgetRepositoryProvider);
    final recRepo = ref.watch(recurringRepositoryProvider);

    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final catName = {for (final c in categories) c.id: c.nama};
    final institutions = ref.watch(institutionsProvider).value ?? const <Institution>[];
    final instName = {for (final i in institutions) i.id: i.nama};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sampah'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Item yang kamu hapus tidak hilang permanen — semuanya muncul di '
            'sini dan bisa dipulihkan.',
            style: TextStyle(color: Neo.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _Section<Transaction>(
            title: 'Transaksi',
            stream: txRepo.watchDeleted(),
            label: (t) {
              final judul = t.tipe == TxType.transfer
                  ? 'Transfer'
                  : (catName[t.kategoriId] ?? 'Tanpa kategori');
              return '$judul • ${rupiah(t.nominal)} • '
                  '${DateFormat('d MMM yyyy', 'id_ID').format(t.tanggal)}';
            },
            onRestore: (t) => txRepo.restore(t.id),
          ),
          _Section<Category>(
            title: 'Kategori',
            stream: catRepo.watchDeleted(),
            label: (c) => c.nama,
            onRestore: (c) => catRepo.restore(c.id),
          ),
          _Section<Account>(
            title: 'Akun',
            stream: accRepo.watchDeleted(),
            label: (a) => 'Akun ${instName[a.institusiId] ?? ''}'.trim(),
            onRestore: (a) => accRepo.restore(a.id),
          ),
          _Section<Institution>(
            title: 'Institusi',
            stream: instRepo.watchDeleted(),
            label: (i) => i.nama,
            onRestore: (i) => instRepo.restore(i.id),
          ),
          _Section<RecurringRule>(
            title: 'Transaksi berulang',
            stream: recRepo.watchDeleted(),
            label: (r) =>
                '${catName[r.kategoriId] ?? 'Tanpa kategori'} • '
                '${rupiah(r.nominal)} • ${frequencyLabel(r.frekuensi)}',
            onRestore: (r) => recRepo.restore(r.id),
          ),
          _Section<Budget>(
            title: 'Anggaran',
            stream: budRepo.watchDeleted(),
            label: (b) => '${b.lingkup == BudgetScope.total ? 'Total' : 'Kategori'} • '
                '${rupiah(b.nominal)}',
            onRestore: (b) => budRepo.restore(b.id),
          ),
        ],
      ),
    );
  }
}

class _Section<T> extends StatelessWidget {
  const _Section({
    required this.title,
    required this.stream,
    required this.label,
    required this.onRestore,
  });

  final String title;
  final Stream<List<T>> stream;
  final String Function(T) label;
  final Future<void> Function(T) onRestore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? <T>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeoCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(label(e), style: const TextStyle(fontSize: 13)),
                      ),
                      TextButton.icon(
                        onPressed: () => onRestore(e),
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('Pulihkan'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
