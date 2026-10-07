import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../util/contrast.dart';
import '../../util/format.dart';
import '../../widgets/neo.dart';
import '../transactions/transaction_form_screen.dart';

String debtDirectionLabel(DebtDirection arah) =>
    arah == DebtDirection.utang ? 'Utang' : 'Piutang';

/// Utang & piutang (Bagian 7.7). Satu catatan menyimpan pokok pinjaman; jumlah
/// terbayarnya dibaca dari transaksi yang tertaut, jadi tidak ada uang yang
/// dicatat dua kali.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utang & piutang'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(
            height: Neo.borderW,
            child: ColoredBox(color: Neo.ink),
          ),
        ),
      ),
      // Ruang untuk bilah navigasi sistem; tanpa ini tombol terbawah tertutup.
      bottomNavigationBar: SizedBox(
        height: MediaQuery.viewPaddingOf(context).bottom,
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Tambah catatan',
        backgroundColor: Neo.accent,
        foregroundColor: readableOn(Neo.accent),
        elevation: 0,
        shape: Neo.buttonShapeBorder(),
        onPressed: () => _showForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: debtsAsync.when(
        loading: () => const NeoLoading(),
        error: (e, _) => NeoError(message: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Belum ada catatan utang atau piutang. Tekan Tambah untuk '
                  'mencatat siapa berutang kepada siapa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Neo.muted),
                ),
              ),
            );
          }

          final belumUtang = list
              .where((d) => d.debt.arah == DebtDirection.utang && !d.lunas)
              .fold(0, (a, d) => a + d.sisa);
          final belumPiutang = list
              .where((d) => d.debt.arah == DebtDirection.piutang && !d.lunas)
              .fold(0, (a, d) => a + d.sisa);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (belumUtang > 0 || belumPiutang > 0) ...[
                NeoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const NeoSectionTitle('Belum lunas'),
                      const SizedBox(height: 8),
                      Text(
                        'Utang ${rupiah(belumUtang)} · Piutang ${rupiah(belumPiutang)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final d in list) ...[
                _DebtCard(baris: d),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.baris});

  final DebtWithPaid baris;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debt = baris.debt;
    final utang = debt.arah == DebtDirection.utang;
    // Utang memakai warna pengeluaran, piutang memakai warna pemasukan.
    final warna = utang ? Neo.expense : Neo.income;
    final lewatTenggat =
        debt.tenggat != null && debt.tenggat!.isBefore(DateTime.now());

    return NeoCard(
      onTap: () => _showForm(context, ref, initial: debt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  debt.pihak,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.18),
                  border: Border.all(color: Neo.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  baris.lunas ? 'Lunas' : debtDirectionLabel(debt.arah),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            debt.tenggat == null
                ? 'Tanpa tenggat'
                : 'Tenggat ${DateFormat('d MMM yyyy', 'id_ID').format(debt.tenggat!)}'
                      '${lewatTenggat && !baris.lunas ? ' · lewat tenggat' : ''}',
            style: TextStyle(
              color: lewatTenggat && !baris.lunas ? Neo.expense : Neo.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: baris.fraksi,
              minHeight: 10,
              backgroundColor: Neo.bg,
              valueColor: AlwaysStoppedAnimation(
                baris.lunas ? Neo.income : warna,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'terbayar ${rupiah(baris.terbayar)} / ${rupiah(debt.nominal)} · '
            'sisa ${rupiah(baris.sisa)}',
            style: const TextStyle(fontSize: 12),
          ),
          if ((debt.catatan ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              debt.catatan!,
              style: TextStyle(color: Neo.muted, fontSize: 11),
            ),
          ],
          if (!baris.lunas) ...[
            const SizedBox(height: 8),
            NeoButton(
              label: 'Catat pembayaran',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TransactionFormScreen(
                    tipe: baris.tipeBayar,
                    debtId: debt.id,
                    catatanAwal:
                        'Pelunasan ${utang ? 'utang' : 'piutang'} — ${debt.pihak}',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Form catatan: arah, pihak, nominal, tenggat, catatan. Menyunting catatan
/// yang sudah ada juga bisa menghapusnya.
Future<void> _showForm(
  BuildContext context,
  WidgetRef ref, {
  Debt? initial,
}) async {
  final repo = ref.read(debtRepositoryProvider);
  final pihakCtrl = TextEditingController(text: initial?.pihak ?? '');
  final nominalCtrl = TextEditingController(
    text: initial == null ? '' : formatThousands(initial.nominal),
  );
  final catatanCtrl = TextEditingController(text: initial?.catatan ?? '');
  var arah = initial?.arah ?? DebtDirection.utang;
  var tenggat = initial?.tenggat;
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(initial == null ? 'Tambah catatan' : 'Ubah catatan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Arah',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Aku berutang'),
                    selected: arah == DebtDirection.utang,
                    selectedColor: Neo.accent,
                    backgroundColor: Neo.surface,
                    side: BorderSide(color: Neo.ink, width: Neo.borderW),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) =>
                        setState(() => arah = DebtDirection.utang),
                  ),
                  ChoiceChip(
                    label: const Text('Dia berutang'),
                    selected: arah == DebtDirection.piutang,
                    selectedColor: Neo.accent,
                    backgroundColor: Neo.surface,
                    side: BorderSide(color: Neo.ink, width: Neo.borderW),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) =>
                        setState(() => arah = DebtDirection.piutang),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              NeoTextField(
                controller: pihakCtrl,
                label: 'Nama pihak',
                hint: 'mis. Budi',
              ),
              const SizedBox(height: 14),
              NeoTextField(
                controller: nominalCtrl,
                label: 'Nominal',
                hint: '0',
                prefixText: 'Rp ',
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsInputFormatter()],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tenggat == null
                          ? 'Tanpa tenggat'
                          : 'Tenggat ${DateFormat('d MMM yyyy', 'id_ID').format(tenggat!)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final pilih = await showDatePicker(
                        context: ctx,
                        initialDate: tenggat ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (pilih != null) setState(() => tenggat = pilih);
                    },
                    child: const Text('Pilih'),
                  ),
                  if (tenggat != null)
                    TextButton(
                      onPressed: () => setState(() => tenggat = null),
                      child: const Text('Kosongkan'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              NeoTextField(
                controller: catatanCtrl,
                label: 'Catatan (opsional)',
              ),
            ],
          ),
        ),
        actions: [
          if (initial != null)
            TextButton(
              onPressed: () async {
                final yakin = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    title: const Text('Hapus catatan?'),
                    content: const Text(
                      'Catatan ini dihapus dari daftar. Transaksi pelunasan '
                      'yang sudah tercatat tetap tersimpan di riwayat.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Batal'),
                      ),
                      NeoButton(
                        label: 'Hapus',
                        onPressed: () => Navigator.pop(c, true),
                      ),
                    ],
                  ),
                );
                if (yakin == true) {
                  await repo.softDelete(initial.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Hapus'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          NeoButton(
            label: 'Simpan',
            onPressed: () async {
              if (saving) return;
              final nominal = parseRupiah(nominalCtrl.text);
              if (pihakCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Isi nama pihaknya')),
                );
                return;
              }
              if (nominal <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Nominal harus lebih dari 0')),
                );
                return;
              }
              saving = true;
              if (initial == null) {
                await repo.create(
                  arah: arah,
                  pihak: pihakCtrl.text,
                  nominal: nominal,
                  tenggat: tenggat,
                  catatan: catatanCtrl.text,
                );
              } else {
                await repo.update(
                  id: initial.id,
                  arah: arah,
                  pihak: pihakCtrl.text,
                  nominal: nominal,
                  tenggat: tenggat,
                  catatan: catatanCtrl.text,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
  pihakCtrl.dispose();
  nominalCtrl.dispose();
  catatanCtrl.dispose();
}
