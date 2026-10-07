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
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  late final _txRepo = ref.read(transactionRepositoryProvider);
  late final _catRepo = ref.read(categoryRepositoryProvider);
  late final _accRepo = ref.read(accountRepositoryProvider);
  late final _instRepo = ref.read(institutionRepositoryProvider);
  late final _budRepo = ref.read(budgetRepositoryProvider);
  late final _recRepo = ref.read(recurringRepositoryProvider);

  // Stream diambil sekali supaya tidak berlangganan ulang tiap rebuild.
  late final _txDeleted = _txRepo.watchDeleted();
  late final _catDeleted = _catRepo.watchDeleted();
  late final _accDeleted = _accRepo.watchDeleted();
  late final _instDeleted = _instRepo.watchDeleted();
  late final _budDeleted = _budRepo.watchDeleted();
  late final _recDeleted = _recRepo.watchDeleted();

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final catName = {for (final c in categories) c.id: c.nama};
    final institutions = ref.watch(institutionsProvider).value ?? const <Institution>[];
    final instName = {for (final i in institutions) i.id: i.nama};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sampah'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      // Ruang untuk bilah navigasi sistem; tanpa ini daftar terbawah tertutup.
      bottomNavigationBar: SizedBox(
        height: MediaQuery.viewPaddingOf(context).bottom,
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
            stream: _txDeleted,
            label: (t) {
              final judul = t.tipe == TxType.transfer
                  ? 'Transfer'
                  : (catName[t.kategoriId] ?? 'Tanpa kategori');
              return '$judul • ${rupiah(t.nominal)} • '
                  '${DateFormat('d MMM yyyy', 'id_ID').format(t.tanggal)}';
            },
            onRestore: (t) => _txRepo.restore(t.id),
          ),
          _Section<Category>(
            title: 'Kategori',
            stream: _catDeleted,
            label: (c) => c.nama,
            onRestore: (c) => _catRepo.restore(c.id),
          ),
          _Section<Account>(
            title: 'Akun',
            stream: _accDeleted,
            label: (a) => 'Akun ${instName[a.institusiId] ?? ''}'.trim(),
            onRestore: (a) => _accRepo.restore(a.id),
          ),
          _Section<Institution>(
            title: 'Institusi',
            stream: _instDeleted,
            label: (i) => i.nama,
            onRestore: (i) => _instRepo.restore(i.id),
          ),
          _Section<RecurringRule>(
            title: 'Transaksi berulang',
            stream: _recDeleted,
            label: (r) =>
                '${catName[r.kategoriId] ?? 'Tanpa kategori'} • '
                '${rupiah(r.nominal)} • ${frequencyLabel(r.frekuensi)}',
            onRestore: (r) => _recRepo.restore(r.id),
          ),
          _Section<Budget>(
            title: 'Anggaran',
            stream: _budDeleted,
            label: (b) => '${b.lingkup == BudgetScope.total ? 'Total' : 'Kategori'} • '
                '${rupiah(b.nominal)}',
            onRestore: (b) => _budRepo.restore(b.id),
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
