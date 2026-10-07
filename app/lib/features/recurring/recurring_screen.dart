import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/recurring.dart';
import '../../data/repositories/recurring_repository.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../util/contrast.dart';
import '../../util/format.dart';
import '../../widgets/neo.dart';

/// Aturan transaksi berulang (Bagian FR-12). Transaksinya dibangkitkan
/// otomatis saat jatuh tempo, bukan lewat tombol di layar ini.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(recurringRulesProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final catName = {for (final c in categories) c.id: c.nama};
    final accounts = ref.watch(accountsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi berulang'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      body: rulesAsync.when(
        loading: () => const NeoLoading(),
        error: (e, _) => NeoError(message: '$e'),
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: NeoCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.autorenew, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada aturan berulang',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Buat aturan untuk gaji, langganan, atau pengeluaran rutin. '
                        'Transaksinya akan dicatat sendiri setiap jatuh tempo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Neo.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final repo = ref.read(recurringRepositoryProvider);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: rules.length,
            separatorBuilder: (context, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = rules[i];
              final next = nextDue(
                mulai: r.mulai,
                frekuensi: r.frekuensi,
                terakhirDibuat: r.terakhirDibuat,
                sampai: r.sampai,
              );
              final pengeluaran = r.tipe == TxType.pengeluaran;
              return NeoCard(
                onTap: () => showRecurringForm(
                  context,
                  ref,
                  categories,
                  accounts,
                  initial: r,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          pengeluaran ? Icons.north_east : Icons.south_west,
                          size: 20,
                          color: pengeluaran ? Neo.expense : Neo.income,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${
                              pengeluaran ? '−' : '+'
                            }${rupiah(r.nominal)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Switch(
                          value: r.aktif,
                          activeThumbColor: Neo.ink,
                          onChanged: (v) => repo.setActive(r.id, v),
                        ),
                        IconButton(
                          tooltip: 'Hapus aturan',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(context, repo, r),
                        ),
                      ],
                    ),
                    Text(
                      '${catName[r.kategoriId] ?? 'Tanpa kategori'} • '
                      '${frequencyLabel(r.frekuensi)}'
                      '${r.akunId == null ? '' : ' • ${_accountName(accounts, r.akunId!)}'}',
                      style: TextStyle(color: Neo.muted, fontSize: 12),
                    ),
                    if ((r.catatan ?? '').isNotEmpty)
                      Text(
                        r.catatan!,
                        style: TextStyle(color: Neo.muted, fontSize: 12),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      !r.aktif
                          ? 'Nonaktif'
                          : next == null
                          ? 'Selesai'
                          : 'Berikutnya: ${DateFormat('d MMM yyyy', 'id_ID').format(next)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah aturan',
        backgroundColor: Neo.accent,
        foregroundColor: readableOn(Neo.accent),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Neo.radius),
          side: BorderSide(color: Neo.ink, width: Neo.borderW),
        ),
        onPressed: () => showRecurringForm(context, ref, categories, accounts),
        child: const Icon(Icons.add),
      ),
    );
  }
}

String _accountName(List<AccountWithInstitution> accounts, String id) {
  for (final a in accounts) {
    if (a.account.id == id) return a.institusi.nama;
  }
  return '?';
}

Future<void> _confirmDelete(
  BuildContext context,
  RecurringRepository repo,
  RecurringRule r,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus aturan?'),
      content: const Text(
        'Aturan dipindah ke Sampah dan bisa dipulihkan. Transaksi yang sudah '
        'terbuat tetap ada di riwayat.',
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
  if (ok == true) await repo.softDelete(r.id);
}

Future<void> showRecurringForm(
  BuildContext context,
  WidgetRef ref,
  List<Category> categories,
  List<AccountWithInstitution> accounts, {
  RecurringRule? initial,
}) async {
  final repo = ref.read(recurringRepositoryProvider);
  final nominalCtrl = TextEditingController(
    text: initial == null ? '' : formatThousands(initial.nominal),
  );
  final catatanCtrl = TextEditingController(text: initial?.catatan ?? '');
  var tipe = initial?.tipe ?? TxType.pengeluaran;
  var frekuensi = initial?.frekuensi ?? Frequency.bulanan;
  var kategoriId = initial?.kategoriId;
  var akunId = initial?.akunId;
  var mulai = initial?.mulai ?? DateTime.now();
  var sampai = initial?.sampai;
  var aktif = initial?.aktif ?? true;
  final activeAccounts = accounts
      .where((a) => a.account.aktif && a.institusi.aktif)
      .toList();
  final activeCategories = categories;
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(initial == null ? 'Tambah aturan' : 'Ubah aturan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Jenis', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _chip('Pengeluaran', tipe == TxType.pengeluaran,
                      () => setState(() => tipe = TxType.pengeluaran)),
                  _chip('Pemasukan', tipe == TxType.pemasukan,
                      () => setState(() => tipe = TxType.pemasukan)),
                ],
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
              const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activeCategories.map((c) {
                  final selected = c.id == kategoriId;
                  return _chip(
                    c.nama,
                    selected,
                    () => setState(() => kategoriId = selected ? null : c.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text('Frekuensi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: Frequency.values.map((f) {
                  return _chip(
                    frequencyLabel(f),
                    f == frekuensi,
                    () => setState(() => frekuensi = f),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text('Mulai', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: mulai,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      mulai = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        mulai.hour,
                        mulai.minute,
                      );
                      // Tanggal selesai tak boleh mendahului mulai.
                      if (sampai != null && sampai!.isBefore(mulai)) {
                        sampai = mulai;
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: Neo.box(),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 10),
                      Text(DateFormat('d MMM yyyy', 'id_ID').format(mulai)),
                    ],
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ada tanggal selesai'),
                value: sampai != null,
                activeThumbColor: Neo.ink,
                onChanged: (v) => setState(
                  () => sampai = v ? (sampai ?? mulai) : null,
                ),
              ),
              if (sampai != null)
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: sampai!,
                      firstDate: mulai,
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => sampai = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: Neo.box(),
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy, size: 16),
                        const SizedBox(width: 10),
                        Text('Selesai: ${DateFormat('d MMM yyyy', 'id_ID').format(sampai!)}'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const Text('Akun', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              if (activeAccounts.isEmpty)
                Text(
                  'Belum ada akun — tambahkan dulu di Pengaturan.',
                  style: TextStyle(color: Neo.muted, fontSize: 12),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: activeAccounts.map((a) {
                    final selected = a.account.id == akunId;
                    return _chip(
                      a.institusi.nama,
                      selected,
                      () => setState(() => akunId = a.account.id),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 14),
              NeoTextField(controller: catatanCtrl, label: 'Catatan (opsional)'),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          NeoButton(
            label: 'Simpan',
            onPressed: () async {
              if (saving) return;
              final nominal = parseRupiah(nominalCtrl.text);
              if (nominal <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Nominal harus lebih dari 0')),
                );
                return;
              }
              if (kategoriId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Pilih kategorinya')),
                );
                return;
              }
              // Akun wajib: transaksi yang dibangkitkan aturan ini harus punya
              // asal, sama seperti transaksi yang dicatat manual.
              if (akunId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Pilih akun')),
                );
                return;
              }
              if (sampai != null && sampai!.isBefore(mulai)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Tanggal selesai tidak boleh sebelum mulai'),
                  ),
                );
                return;
              }
              saving = true;
              final catatan =
                  catatanCtrl.text.trim().isEmpty ? null : catatanCtrl.text.trim();
              if (initial == null) {
                await repo.create(
                  tipe: tipe,
                  nominal: nominal,
                  kategoriId: kategoriId,
                  akunId: akunId,
                  catatan: catatan,
                  frekuensi: frekuensi,
                  mulai: mulai,
                  sampai: sampai,
                );
              } else {
                await repo.update(
                  id: initial.id,
                  tipe: tipe,
                  nominal: nominal,
                  kategoriId: kategoriId,
                  akunId: akunId,
                  catatan: catatan,
                  frekuensi: frekuensi,
                  mulai: mulai,
                  sampai: sampai,
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
  catatanCtrl.dispose();
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
