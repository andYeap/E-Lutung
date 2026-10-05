import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/finance.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../util/contrast.dart';
import '../util/format.dart';
import '../widgets/neo.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  // Stream diambil sekali supaya tidak berlangganan ulang tiap rebuild.
  late final _instStream = ref.read(institutionRepositoryProvider).watchAll();
  late final _accStream = ref.read(accountRepositoryProvider).watchAll();

  @override
  Widget build(BuildContext context) {
    // Saldo berjalan dihitung dari transaksi (Bagian FR-7.2).
    final txs = ref.watch(allTransactionsProvider).value ?? const <Transaction>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      body: StreamBuilder<List<Institution>>(
        stream: _instStream,
        builder: (context, instSnap) {
          final institutions = instSnap.data ?? const <Institution>[];
          return StreamBuilder<List<AccountWithInstitution>>(
            stream: _accStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return NeoError(message: '${snap.error}');
              }
              if (!snap.hasData) {
                return const NeoLoading();
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return _EmptyState(
                  onTap: institutions.isEmpty
                      ? null
                      : () => _showForm(context, ref, institutions),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final row = items[i];
                  return NeoCard(
                    onTap: () => _showForm(
                      context,
                      ref,
                      institutions,
                      initial: row,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.institusi.nama,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                row.account.milikSendiri
                                    ? 'Milik sendiri • Saldo ${rupiah(accountBalance(row.account.id, row.account.saldoAwal, txs))}'
                                    : 'Pihak lain • Saldo ${rupiah(accountBalance(row.account.id, row.account.saldoAwal, txs))}',
                                style: TextStyle(
                                  color: Neo.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(context, ref, row),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<List<Institution>>(
        stream: _instStream,
        builder: (context, snap) {
          final institutions = snap.data ?? const <Institution>[];
          return FloatingActionButton(
            tooltip: 'Tambah akun',
            backgroundColor: Neo.accent,
            foregroundColor: readableOn(Neo.accent),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Neo.radius),
              side: BorderSide(color: Neo.ink, width: Neo.borderW),
            ),
            onPressed: institutions.isEmpty
                ? null
                : () => _showForm(context, ref, institutions),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada akun',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan akun (mis. Tunai, BCA, OVO) untuk mulai mencatat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Neo.muted),
            ),
            if (onTap != null) ...[
              const SizedBox(height: 16),
              NeoButton(label: 'Tambah akun', icon: Icons.add, onPressed: onTap),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showForm(
  BuildContext context,
  WidgetRef ref,
  List<Institution> institutions, {
  AccountWithInstitution? initial,
}) async {
  final repo = ref.read(accountRepositoryProvider);
  final saldoCtrl = TextEditingController(
    text: initial == null || initial.account.saldoAwal == 0
        ? ''
        : formatThousands(initial.account.saldoAwal),
  );
  var institusiId = initial?.account.institusiId ??
      (institutions.isNotEmpty ? institutions.first.id : '');
  var milikSendiri = initial?.account.milikSendiri ?? true;
  var aktif = initial?.account.aktif ?? true;
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(initial == null ? 'Tambah Akun' : 'Ubah Akun'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Institusi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: institutions.map((inst) {
                  final selected = inst.id == institusiId;
                  return ChoiceChip(
                    label: Text(inst.nama),
                    selected: selected,
                    onSelected: (_) => setState(() => institusiId = inst.id),
                    selectedColor: Neo.accent,
                    backgroundColor: Neo.surface,
                    side: BorderSide(color: Neo.ink, width: Neo.borderW),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? readableOn(Neo.accent) : Neo.ink,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              NeoTextField(
                controller: saldoCtrl,
                label: 'Saldo awal (opsional)',
                hint: '0',
                prefixText: 'Rp ',
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsInputFormatter()],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Milik sendiri'),
                subtitle: const Text(
                  'Matikan untuk akun pihak lain (tujuan transfer).',
                  style: TextStyle(fontSize: 12),
                ),
                value: milikSendiri,
                activeThumbColor: Neo.ink,
                onChanged: (v) => setState(() => milikSendiri = v),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          NeoButton(
            label: 'Simpan',
            onPressed: () async {
              if (saving) return;
              if (institusiId.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Pilih institusi dulu')),
                );
                return;
              }
              final saldo = parseRupiah(saldoCtrl.text);
              saving = true;
              if (initial == null) {
                await repo.create(
                  institusiId: institusiId,
                  milikSendiri: milikSendiri,
                  saldoAwal: saldo,
                );
              } else {
                await repo.update(
                  id: initial.account.id,
                  institusiId: institusiId,
                  milikSendiri: milikSendiri,
                  saldoAwal: saldo,
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
  saldoCtrl.dispose();
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  AccountWithInstitution row,
) async {
  final repo = ref.read(accountRepositoryProvider);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus akun?'),
      content: Text('Akun "${row.institusi.nama}" akan disembunyikan.'),
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
  if (ok == true) await repo.softDelete(row.account.id);
}
