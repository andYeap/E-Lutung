import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../providers.dart';
import '../../services/receipt_storage.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../../widgets/neo.dart';

/// Layar Foto struk: semua foto struk yang tersimpan di perangkat.
///
/// Foto tidak ikut dalam ekspor cadangan (gambar tidak masuk JSON), jadi layar
/// ini juga tempat pengguna melihat dan membersihkan sisa path yang menunjuk ke
/// berkas hilang setelah impor cadangan.
class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiptTransactionsProvider);
    final categories = ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final catName = {for (final c in categories) c.id: c.nama};
    final catWarna = {for (final c in categories) c.id: c.warna};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto struk'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      body: async.when(
        loading: () => const NeoLoading(message: 'Memuat foto struk…'),
        error: (e, _) => NeoError(message: 'Gagal memuat: $e'),
        data: (list) {
          if (list.isEmpty) return _kosong(context);
          final ada = list.where((t) => ReceiptStorage.ada(t.strukPath)).toList();
          final hilang = list.where((t) => !ReceiptStorage.ada(t.strukPath)).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Ringkasan(
                jumlah: ada.length,
                ukuran: ReceiptStorage.formatUkuran(
                  ReceiptStorage.totalUkuranSync(ada.map((t) => t.strukPath)),
                ),
              ),
              const SizedBox(height: 12),
              if (ada.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Semua foto di daftar ini sudah hilang dari perangkat.',
                    style: TextStyle(color: Neo.muted, fontSize: 12),
                  ),
                )
              else
                ...ada.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StrukCard(
                      transaksi: t,
                      namaKategori: catName[t.kategoriId] ?? 'Tanpa kategori',
                      warnaKategori: catWarna[t.kategoriId],
                    ),
                  ),
                ),
              if (hilang.isNotEmpty) ...[
                const SizedBox(height: 8),
                _HilangCard(
                  hilang: hilang,
                  onBersihkan: () => _bersihkan(context, ref, hilang),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _kosong(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const SizedBox(height: 40),
      Icon(Icons.receipt_long, size: 48, color: Neo.muted),
      const SizedBox(height: 12),
      Text(
        'Belum ada foto struk tersimpan.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Neo.muted, fontSize: 13),
      ),
      const SizedBox(height: 6),
      Text(
        'Saat memakai Scan struk, aktifkan "Simpan foto struk" supaya foto '
        'tersimpan di sini.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Neo.muted, fontSize: 12),
      ),
    ],
  );

  Future<void> _bersihkan(
    BuildContext context,
    WidgetRef ref,
    List<Transaction> hilang,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lepas ${hilang.length} path hilang?'),
        content: const Text(
          'Foto-foto ini sudah tidak ada di perangkat, jadi yang dibersihkan '
          'hanya penunjuk berkasnya. Transaksinya sendiri tetap utuh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          NeoButton(label: 'Bersihkan', onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref
        .read(transactionRepositoryProvider)
        .clearReceiptPaths(hilang.map((t) => t.id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${hilang.length} path foto dilepas')),
    );
  }
}

class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.jumlah, required this.ukuran});

  final int jumlah;
  final String ukuran;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: Neo.box(),
    child: Row(
      children: [
        Icon(Icons.photo_library, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$jumlah foto tersimpan',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                'Total $ukuran • tidak ikut ekspor cadangan',
                style: TextStyle(color: Neo.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StrukCard extends StatelessWidget {
  const _StrukCard({
    required this.transaksi,
    required this.namaKategori,
    required this.warnaKategori,
  });

  final Transaction transaksi;
  final String namaKategori;
  final String? warnaKategori;

  @override
  Widget build(BuildContext context) {
    final path = transaksi.strukPath!;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _StrukViewer(transaksi: transaksi, path: path),
        ),
      ),
      child: NeoCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Neo.radius),
              child: Image.file(
                File(path),
                width: 64,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 64,
                  height: 84,
                  color: Neo.surface,
                  child: Icon(Icons.broken_image, color: Neo.muted),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    namaKategori,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rupiah(transaksi.nominal),
                    style: TextStyle(
                      color: Neo.expense,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM yyyy', 'id_ID').format(transaksi.tanggal),
                    style: TextStyle(color: Neo.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Neo.muted),
          ],
        ),
      ),
    );
  }
}

/// Penanda path yang menunjuk ke berkas hilang — biasanya hasil impor cadangan,
/// karena gambar tidak ikut dalam JSON.
class _HilangCard extends StatelessWidget {
  const _HilangCard({required this.hilang, required this.onBersihkan});

  final List<Transaction> hilang;
  final VoidCallback onBersihkan;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: Neo.box(
      color: Color.alphaBlend(
        Neo.expense.withValues(alpha: 0.12),
        Neo.surface,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber, size: 18, color: Neo.expense),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${hilang.length} foto sudah tidak ada di perangkat',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Path-nya ikut saat impor cadangan, tapi gambarnya tidak. Transaksinya '
          'masih ada — hanya buktinya yang hilang.',
          style: TextStyle(color: Neo.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        NeoButton(
          label: 'Bersihkan path',
          onPressed: onBersihkan,
        ),
      ],
    ),
  );
}

/// Penampil foto layar penuh dengan zoom.
class _StrukViewer extends ConsumerWidget {
  const _StrukViewer({required this.transaksi, required this.path});

  final Transaction transaksi;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Neo.bg,
      appBar: AppBar(
        title: Text(
          DateFormat('d MMM yyyy', 'id_ID').format(transaksi.tanggal),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
        actions: [
          IconButton(
            tooltip: 'Hapus foto ini',
            icon: Icon(Icons.delete_outline),
            onPressed: () => _konfirmasiHapus(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: Neo.box(),
            child: Text(
              '${rupiah(transaksi.nominal)} • ${transaksi.catatan ?? 'tanpa keterangan'}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: Image.file(
                  File(path),
                  errorBuilder: (_, _, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Foto tidak bisa dibuka. Berkasnya mungkin sudah terhapus.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Neo.muted, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cubit satu jari untuk memperbesar.',
            style: TextStyle(color: Neo.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _konfirmasiHapus(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus foto struk?'),
        content: const Text(
          'Berkas fotonya dihapus dari perangkat. Transaksinya tetap ada dan '
          'bisa dibuka lagi tanpa foto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          NeoButton(
            label: 'Hapus',
            color: Neo.expense,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ReceiptStorage.hapus(path);
    await ref
        .read(transactionRepositoryProvider)
        .clearReceiptPath(transaksi.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto struk dihapus')),
    );
  }
}
