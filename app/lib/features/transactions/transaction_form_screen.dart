import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/finance.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../../widgets/neo.dart';

/// Form catat/ubah transaksi — mendukung pemasukan, pengeluaran, dan transfer
/// (Bagian FR-2; aturan transfer Bagian 8.1).
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    super.key,
    required this.tipe,
    this.initial,
    this.debtId,
    this.catatanAwal,
  });

  final TxType tipe;
  final Transaction? initial;

  /// Bila diisi, transaksi ini dicatat sebagai pelunasan catatan utang itu.
  final String? debtId;

  /// Isian catatan awal, mis. keterangan pelunasan utang.
  final String? catatanAwal;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  late TxType _tipe = widget.initial?.tipe ?? widget.tipe;
  late final TextEditingController _nominal = TextEditingController(
    text: (widget.initial == null || widget.initial!.nominal == 0)
        ? ''
        : formatThousands(widget.initial!.nominal),
  );
  late final TextEditingController _admin = TextEditingController(
    text: (widget.initial == null || widget.initial!.biayaAdmin == 0)
        ? ''
        : formatThousands(widget.initial!.biayaAdmin),
  );
  late final TextEditingController _catatan = TextEditingController(
    text: widget.initial?.catatan ?? widget.catatanAwal ?? '',
  );
  late DateTime _tanggal = widget.initial?.tanggal ?? DateTime.now();
  late String? _kategoriId = widget.initial?.kategoriId;
  late String? _akunId = widget.initial?.akunId;
  late String? _akunAsalId = widget.initial?.akunAsalId;
  late String? _akunTujuanId = widget.initial?.akunTujuanId;
  bool _saving = false;
  bool _addAgain = false; // FR-2.4

  /// Diizinkan keluar tanpa konfirmasi setelah simpan/hapus berhasil.
  bool _izinkanKeluar = false;

  bool get _adaIsian =>
      _nominal.text.trim().isNotEmpty || _catatan.text.trim().isNotEmpty;

  Future<bool> _konfirmasiKeluar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buang perubahan?'),
        content: const Text('Isian yang belum disimpan akan hilang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          NeoButton(
            label: 'Buang',
            color: Neo.expense,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  void dispose() {
    _nominal.dispose();
    _admin.dispose();
    _catatan.dispose();
    super.dispose();
  }

  bool get _isTransfer => _tipe == TxType.transfer;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _tanggal = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _tanggal.hour,
            _tanggal.minute,
          ));
    }
  }

  /// FR-2.1: tanggal **dan waktu** (default sekarang, bisa disetel).
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_tanggal),
    );
    if (picked != null) {
      setState(() => _tanggal = DateTime(
            _tanggal.year,
            _tanggal.month,
            _tanggal.day,
            picked.hour,
            picked.minute,
          ));
    }
  }

  Widget _pickerTile({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: Neo.box(),
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(value, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  /// Peringatan non-blokir bila transaksi ini membuat anggaran terlewati
  /// (FR-6.4). Mengembalikan pesan, atau null bila aman.
  String? _budgetWarning(int nominal, int admin) {
    final budgets = ref.read(budgetsProvider).value ?? const <Budget>[];
    final txs = ref.read(allTransactionsProvider).value ?? const <Transaction>[];
    final ownIds = ref.read(ownAccountIdsProvider);

    final isInternal = _isTransfer &&
        _akunTujuanId != null &&
        ownIds.contains(_akunTujuanId);
    final projected = switch (_tipe) {
      TxType.pemasukan => 0,
      TxType.pengeluaran => nominal,
      TxType.transfer => isInternal ? admin : nominal + admin,
    };
    if (projected == 0) return null;

    for (final b in budgets) {
      if (!b.aktif) continue;
      final start = DateTime(b.periodeMulai.year, b.periodeMulai.month, b.periodeMulai.day);
      final end = DateTime(b.periodeSelesai.year, b.periodeSelesai.month, b.periodeSelesai.day, 23, 59, 59);
      if (_tanggal.isBefore(start) || _tanggal.isAfter(end)) continue;
      if (b.lingkup == BudgetScope.kategori && b.kategoriId != _kategoriId) continue;

      final before = budgetUsageOf(b, txs, ownIds).used;
      final after = before + projected;
      if (before <= b.nominal && after > b.nominal) {
        final judul =
            b.lingkup == BudgetScope.total ? 'Anggaran total' : 'Anggaran kategori';
        return '$judul terlewati: ${rupiah(after)} dari ${rupiah(b.nominal)}.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final repo = ref.read(transactionRepositoryProvider);
    final nominal = parseRupiah(_nominal.text);
    final admin = parseRupiah(_admin.text);
    if (nominal <= 0) {
      _snack('Nominal harus lebih dari 0');
      return;
    }
    if (_isTransfer) {
      if (_akunAsalId == null || _akunTujuanId == null) {
        _snack('Pilih akun asal dan tujuan');
        return;
      }
      if (_akunAsalId == _akunTujuanId) {
        _snack('Akun asal dan tujuan tidak boleh sama');
        return;
      }
    } else {
      if (_kategoriId == null) {
        _snack('Pilih kategori');
        return;
      }
      // Akun wajib: uang tanpa akun tidak punya asal, dan membuat Sisa (saldo
      // akun) tidak bisa dicocokkan dengan Selisih.
      if (_akunId == null) {
        _snack('Pilih akun');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final warning = _budgetWarning(nominal, _isTransfer ? admin : 0);
      if (widget.initial == null) {
        await repo.create(
          tipe: _tipe,
          nominal: nominal,
          tanggal: _tanggal,
          kategoriId: _kategoriId,
          akunId: _isTransfer ? null : _akunId,
          catatan: _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
          akunAsalId: _isTransfer ? _akunAsalId : null,
          akunTujuanId: _isTransfer ? _akunTujuanId : null,
          biayaAdmin: _isTransfer ? admin : 0,
          debtId: widget.debtId,
        );
      } else {
        await repo.update(
          id: widget.initial!.id,
          tipe: _tipe,
          nominal: nominal,
          tanggal: _tanggal,
          kategoriId: _kategoriId,
          akunId: _isTransfer ? null : _akunId,
          catatan: _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
          akunAsalId: _isTransfer ? _akunAsalId : null,
          akunTujuanId: _isTransfer ? _akunTujuanId : null,
          biayaAdmin: _isTransfer ? admin : 0,
          debtId: widget.debtId,
        );
      }
      if (!mounted) return;
      if (warning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(warning),
            duration: const Duration(seconds: 4),
            backgroundColor: Neo.expense,
          ),
        );
      }
      if (_addAgain && widget.initial == null) {
        // Bersihkan untuk input berikutnya (FR-2.4).
        setState(() {
          _nominal.clear();
          _admin.clear();
          _catatan.clear();
          _akunId = null;
          _akunAsalId = null;
          _akunTujuanId = null;
        });
      } else {
        _izinkanKeluar = true;
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final repo = ref.read(transactionRepositoryProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi ini akan disembunyikan dari riwayat.'),
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
    if (ok != true) return;
    await repo.softDelete(widget.initial!.id);
    _izinkanKeluar = true;
    if (mounted) Navigator.pop(context, true);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final accounts = ref.watch(accountsProvider).value ?? const [];
    // FR-7.4: akun nonaktif — atau yang institusinya nonaktif — tidak muncul
    // di pilihan form baru (tetap tampil di riwayat lama).
    final activeAccounts = accounts
        .where((a) => a.account.aktif && a.institusi.aktif)
        .toList();

    final title = switch (_tipe) {
      TxType.pemasukan => 'Catat Pemasukan',
      TxType.pengeluaran => 'Catat Pengeluaran',
      TxType.transfer => 'Catat Transfer',
    };

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial != null
              ? 'Ubah Transaksi'
              : (widget.debtId == null ? title : 'Catat Pembayaran'),
        ),
        actions: [
          if (widget.initial != null)
            IconButton(
              tooltip: 'Hapus transaksi',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      // Ruang untuk bilah navigasi sistem. Aplikasi menggambar sampai tepi
      // layar (targetSdk Android 15 memaksa edge-to-edge), jadi tanpa ini tombol
      // paling bawah form bisa tertutup bilah navigasi HP.
      bottomNavigationBar: SizedBox(
        height: MediaQuery.viewPaddingOf(context).bottom,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.initial == null) ...[
            const Text('Tipe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: TxType.values.map((t) {
                final selected = t == _tipe;
                return ChoiceChip(
                  label: Text(switch (t) {
                    TxType.pemasukan => 'Pemasukan',
                    TxType.pengeluaran => 'Pengeluaran',
                    TxType.transfer => 'Transfer',
                  }),
                  selected: selected,
                  onSelected: (_) => setState(() => _tipe = t),
                  selectedColor: Neo.accent,
                  backgroundColor: Neo.surface,
                  side: BorderSide(color: Neo.ink, width: Neo.borderW),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          NeoTextField(
            controller: _nominal,
            label: 'Nominal',
            hint: '0',
            prefixText: 'Rp ',
            keyboardType: TextInputType.number,
            inputFormatters: const [ThousandsInputFormatter()],
          ),
          const SizedBox(height: 16),
          if (_isTransfer) ...[
            _Chips(
              label: 'Dari akun',
              items: activeAccounts,
              labels: akunLabels(accounts),
              selectedId: _akunAsalId,
              onSelected: (id) => setState(() => _akunAsalId = id),
            ),
            const SizedBox(height: 12),
            _Chips(
              label: 'Ke akun',
              items: activeAccounts,
              labels: akunLabels(accounts),
              selectedId: _akunTujuanId,
              onSelected: (id) => setState(() => _akunTujuanId = id),
            ),
            const SizedBox(height: 16),
            NeoTextField(
              controller: _admin,
              label: 'Biaya admin (opsional)',
              hint: '0',
              prefixText: 'Rp ',
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsInputFormatter()],
            ),
            const SizedBox(height: 16),
            _CategoryChips(
              categories: categories,
              selectedId: _kategoriId,
              onSelected: (id) => setState(() => _kategoriId = id),
              label: 'Kategori (opsional)',
            ),
          ] else ...[
            _CategoryChips(
              categories: categories,
              selectedId: _kategoriId,
              onSelected: (id) => setState(() => _kategoriId = id),
              label: 'Kategori',
            ),
            const SizedBox(height: 16),
            _Chips(
              label: 'Akun',
              items: activeAccounts,
              labels: akunLabels(accounts),
              selectedId: _akunId,
              onSelected: (id) => setState(() => _akunId = id),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _pickerTile(
                  label: 'Tanggal',
                  icon: Icons.calendar_today,
                  value: DateFormat('d MMM yyyy', 'id_ID').format(_tanggal),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pickerTile(
                  label: 'Jam',
                  icon: Icons.schedule,
                  value: DateFormat('HH:mm').format(_tanggal),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          NeoTextField(controller: _catatan, label: 'Catatan (opsional)'),
          if (widget.initial == null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simpan & tambah lagi'),
              value: _addAgain,
              activeThumbColor: Neo.ink,
              onChanged: (v) => setState(() => _addAgain = v),
            ),
          const SizedBox(height: 8),
          NeoButton(
            label: _saving ? 'Menyimpan…' : 'Simpan',
            icon: Icons.check,
            expand: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
    return PopScope(
      canPop: !_adaIsian || _izinkanKeluar,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _konfirmasiKeluar();
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: scaffold,
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.label,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((c) {
            final selected = c.id == selectedId;
            return ChoiceChip(
              label: Text(c.nama),
              selected: selected,
              onSelected: (_) => onSelected(selected ? null : c.id),
              selectedColor: Neo.accent,
              backgroundColor: Neo.surface,
              side: BorderSide(color: Neo.ink, width: Neo.borderW),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.label,
    required this.items,
    required this.labels,
    required this.selectedId,
    required this.onSelected,
  });

  final String label;
  final List<AccountWithInstitution> items;

  /// Label tiap akun (lihat [akunLabels]); dua akun di bank yang sama harus
  /// tetap bisa dibedakan saat memilih.
  final Map<String, String> labels;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text('Belum ada akun — tambahkan dulu di Pengaturan.',
              style: TextStyle(color: Neo.muted, fontSize: 12))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((a) {
              final selected = a.account.id == selectedId;
              return ChoiceChip(
                label: Text(labels[a.account.id] ?? a.institusi.nama),
                selected: selected,
                onSelected: (_) => onSelected(selected ? null : a.account.id),
                selectedColor: Neo.accent,
                backgroundColor: Neo.surface,
                side: BorderSide(color: Neo.ink, width: Neo.borderW),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              );
            }).toList(),
          ),
      ],
    );
  }
}
