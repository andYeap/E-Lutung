import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repositories/category_repository.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../util/color.dart';
import '../util/contrast.dart';
import '../widgets/neo.dart';

/// CRUD kategori (Bagian FR-8). Hapus = arsip, bukan hapus permanen.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(categoryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      body: StreamBuilder<List<Category>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (snap.hasError) return NeoError(message: '${snap.error}');
          if (!snap.hasData) return const NeoLoading();
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Belum ada kategori. Tekan + untuk menambah.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Neo.muted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final c = items[i];
              return NeoCard(
                onTap: () => _showForm(context, ref, initial: c),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: parseHexColor(c.warna),
                        border: Border.all(color: Neo.ink, width: 2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c.nama,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, repo, c),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah kategori',
        backgroundColor: Neo.accent,
        foregroundColor: readableOn(Neo.accent),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Neo.radius),
          side: BorderSide(color: Neo.ink, width: Neo.borderW),
        ),
        onPressed: () => _showForm(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> _showForm(
  BuildContext context,
  WidgetRef ref, {
  Category? initial,
}) async {
  final repo = ref.read(categoryRepositoryProvider);
  final namaCtrl = TextEditingController(text: initial?.nama ?? '');
  final warnaCtrl = TextEditingController(text: initial?.warna ?? '#FF6B6B');
  final ikonCtrl = TextEditingController(text: initial?.ikon ?? '');
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(initial == null ? 'Tambah Kategori' : 'Ubah Kategori'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NeoTextField(controller: namaCtrl, label: 'Nama', hint: 'mis. Makanan & Minuman'),
            const SizedBox(height: 14),
            NeoTextField(controller: warnaCtrl, label: 'Warna (hex)', hint: '#FF6B6B'),
            const SizedBox(height: 14),
            NeoTextField(controller: ikonCtrl, label: 'Ikon (opsional)', hint: 'restaurant'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        NeoButton(
          label: 'Simpan',
          onPressed: () async {
            if (saving) return;
            final nama = namaCtrl.text.trim();
            if (nama.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Nama tidak boleh kosong')),
              );
              return;
            }
            final warna = warnaCtrl.text.trim().isEmpty ? null : warnaCtrl.text.trim();
            final ikon = ikonCtrl.text.trim().isEmpty ? null : ikonCtrl.text.trim();
            saving = true;
            if (initial == null) {
              await repo.create(nama: nama, ikon: ikon, warna: warna);
            } else {
              await repo.update(id: initial.id, nama: nama, ikon: ikon, warna: warna);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ],
    ),
  );
  namaCtrl.dispose();
  warnaCtrl.dispose();
  ikonCtrl.dispose();
}

Future<void> _confirmDelete(
  BuildContext context,
  CategoryRepository repo,
  Category c,
) async {
  // FR-8.2: kategori yang masih dipakai transaksi tidak dihapus — labelnya
  // dibutuhkan riwayat/rekap. Pindahkan transaksinya dulu.
  final used = await repo.usedByTransactions(c.id);
  if (!context.mounted) return;
  if (used > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tidak bisa hapus: masih dipakai $used transaksi. '
          'Ubah kategori transaksi itu dulu.',
        ),
      ),
    );
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus kategori?'),
      content: Text('"${c.nama}" dipindah ke Sampah dan bisa dipulihkan.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        NeoButton(
          label: 'Hapus',
          color: Neo.expense,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (ok == true) await repo.softDelete(c.id);
}
