import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../util/labels.dart';
import '../widgets/neo.dart';

class InstitutionsScreen extends ConsumerWidget {
  const InstitutionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(institutionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Institusi'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      body: StreamBuilder<List<Institution>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (snap.hasError) {
            return NeoError(message: '${snap.error}');
          }
          if (!snap.hasData) {
            return const NeoLoading();
          }
          final items = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final inst = items[i];
              return NeoCard(
                onTap: () => _showForm(context, ref, initial: inst),
                child: Row(
                  children: [
                    Icon(institutionTypeIcon(inst.tipe), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inst.nama,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          Text(
                            institutionTypeLabel(inst.tipe) + (inst.aktif ? '' : ' • nonaktif'),
                            style: TextStyle(color: Neo.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, ref, inst),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _NeoFab(
        onPressed: () => _showForm(context, ref),
        tooltip: 'Tambah institusi',
      ),
    );
  }
}

class _NeoFab extends StatelessWidget {
  const _NeoFab({required this.onPressed, required this.tooltip});
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => FloatingActionButton(
    tooltip: tooltip,
    backgroundColor: Neo.accent,
    foregroundColor: Neo.ink,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Neo.radius),
      side: BorderSide(color: Neo.ink, width: Neo.borderW),
    ),
    onPressed: onPressed,
    child: const Icon(Icons.add),
  );
}

Future<void> _showForm(
  BuildContext context,
  WidgetRef ref, {
  Institution? initial,
}) async {
  final repo = ref.read(institutionRepositoryProvider);
  final namaCtrl = TextEditingController(text: initial?.nama ?? '');
  var tipe = initial?.tipe ?? InstitutionType.bank;
  var aktif = initial?.aktif ?? true;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(initial == null ? 'Tambah Institusi' : 'Ubah Institusi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeoTextField(
                controller: namaCtrl,
                label: 'Nama',
                hint: 'mis. BCA / OVO / Tunai',
              ),
              const SizedBox(height: 14),
              const Text('Tipe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: InstitutionType.values.map((t) {
                  final selected = t == tipe;
                  return ChoiceChip(
                    label: Text(institutionTypeLabel(t)),
                    selected: selected,
                    onSelected: (_) => setState(() => tipe = t),
                    selectedColor: Neo.accent,
                    backgroundColor: Neo.surface,
                    side: BorderSide(color: Neo.ink, width: Neo.borderW),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Neo.ink,
                    ),
                  );
                }).toList(),
              ),
              if (initial != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  value: aktif,
                  activeThumbColor: Neo.ink,
                  onChanged: (v) => setState(() => aktif = v),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          NeoButton(
            label: 'Simpan',
            onPressed: () async {
              final nama = namaCtrl.text.trim();
              if (nama.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Nama tidak boleh kosong')),
                );
                return;
              }
              if (initial == null) {
                await repo.create(nama: nama, tipe: tipe);
              } else {
                await repo.update(id: initial.id, nama: nama, tipe: tipe, aktif: aktif);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
  namaCtrl.dispose();
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Institution inst,
) async {
  final repo = ref.read(institutionRepositoryProvider);
  final used = await repo.usedByAccounts(inst.id);
  if (!context.mounted) return;
  if (used > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tidak bisa hapus: dipakai oleh $used akun.')),
    );
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus institusi?'),
      content: Text('"${inst.nama}" akan disembunyikan (bisa dipulihkan nanti).'),
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
  if (ok == true) await repo.softDelete(inst.id);
}
