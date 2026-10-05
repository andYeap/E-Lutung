import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/receipt.dart';
import '../../providers.dart';
import '../../services/receipt_scanner.dart';
import '../../services/receipt_storage.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../../widgets/neo.dart';

/// Scan struk: foto → OCR di perangkat → form review → simpan pengeluaran.
///
/// OCR tidak pernah menyimpan otomatis; nilainya selalu lewat form ini supaya
/// pengguna bisa membetulkan hasil baca yang keliru.
class ScanReceiptScreen extends ConsumerStatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nominal = TextEditingController();
  final TextEditingController _keterangan = TextEditingController();

  String? _imagePath;
  String? _teksOcr;
  ReceiptDraft? _draft;
  bool _memproses = false;
  bool _menyimpan = false;
  bool _simpanGambar = true;
  bool _izinkanKeluar = false;
  DateTime _tanggal = DateTime.now();
  String? _kategoriId;
  String? _akunId;

  bool get _adaIsian =>
      _imagePath != null ||
      _nominal.text.trim().isNotEmpty ||
      _keterangan.text.trim().isNotEmpty;

  Future<bool> _konfirmasiKeluar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buang scan ini?'),
        content: const Text('Hasil scan yang belum disimpan akan hilang.'),
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
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _ambil(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 2400,
      );
      if (x == null || !mounted) return;
      setState(() {
        _imagePath = x.path;
        _memproses = true;
      });
      final teks = await ReceiptScanner.recognizeText(x.path);
      final draft = parseReceipt(teks);
      if (!mounted) return;
      setState(() {
        _memproses = false;
        _teksOcr = teks;
        _draft = draft;
        if (draft.nominal != null) _nominal.text = formatThousands(draft.nominal!);
        if (draft.tanggal != null) _tanggal = draft.tanggal!;
        if (_keterangan.text.trim().isEmpty && draft.merchant != null) {
          _keterangan.text = draft.merchant!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _memproses = false);
      _snack('Gagal membaca struk: $e. Isi nominalnya manual.');
    }
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _tanggal = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _tanggal.hour,
            _tanggal.minute,
          ));
    }
  }

  Future<void> _simpan() async {
    final nominal = parseRupiah(_nominal.text);
    if (nominal <= 0) {
      _snack('Nominal harus lebih dari 0');
      return;
    }
    if (_kategoriId == null) {
      _snack('Pilih kategori');
      return;
    }
    setState(() => _menyimpan = true);
    try {
      String? strukPath;
      if (_simpanGambar && _imagePath != null) {
        strukPath = await ReceiptStorage.simpan(_imagePath!);
      }
      await ref.read(transactionRepositoryProvider).create(
        tipe: TxType.pengeluaran,
        nominal: nominal,
        tanggal: _tanggal,
        kategoriId: _kategoriId,
        akunId: _akunId,
        catatan: _keterangan.text.trim().isEmpty ? null : _keterangan.text.trim(),
        strukPath: strukPath,
      );
      if (mounted) {
        _izinkanKeluar = true;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      _snack('Gagal menyimpan: $e');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final activeAccounts = accounts
        .where((a) => a.account.aktif && a.institusi.aktif)
        .toList();

    return PopScope(
      canPop: !_adaIsian || _izinkanKeluar,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _konfirmasiKeluar();
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan struk'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(
            height: Neo.borderW,
            child: ColoredBox(color: Neo.ink),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_imagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(Neo.radius),
              child: Image.file(
                File(_imagePath!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  label: 'Kamera',
                  icon: Icons.photo_camera,
                  onPressed: _memproses || _menyimpan
                      ? null
                      : () => _ambil(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoButton(
                  label: 'Galeri',
                  icon: Icons.photo_library,
                  onPressed: _memproses || _menyimpan
                      ? null
                      : () => _ambil(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_memproses)
            const NeoLoading(message: 'Membaca struk…')
          else if (_imagePath != null)
            Text(
              'Periksa hasil baca di bawah dan sesuaikan bila perlu. Kategori '
              'selalu kamu pilih sendiri.',
              style: TextStyle(color: Neo.muted, fontSize: 12),
            ),
          if (_teksOcr != null && !_memproses)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                'Lihat teks hasil scan',
                style: TextStyle(color: Neo.muted, fontSize: 12),
              ),
              children: [
                SelectableText(
                  _teksOcr!,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          if (_draft != null && !_memproses && !_draft!.yakin)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: Neo.box(
                  color: Color.alphaBlend(
                    Neo.expense.withValues(alpha: 0.12),
                    Neo.surface,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 18, color: Neo.expense),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _draft!.nominal == null
                            ? 'Nominal belum terbaca. Ketik sendiri dari struk.'
                            : 'Nominal ditebak dari angka terbesar, bukan dari '
                                  'baris total. Periksa dan betulkan bila perlu.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_draft != null &&
              !_memproses &&
              _draft!.sumber == SumberNominal.pembayaranTunai)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 16, color: Neo.income),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nominal dicocokkan dari hitungan tunai dikurangi '
                      'kembalian.',
                      style: TextStyle(color: Neo.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          NeoTextField(
            controller: _nominal,
            label: 'Nominal',
            hint: '0',
            prefixText: 'Rp ',
            keyboardType: TextInputType.number,
            inputFormatters: const [ThousandsInputFormatter()],
          ),
          const SizedBox(height: 16),
          _KategoriChips(
            categories: categories,
            selectedId: _kategoriId,
            onSelected: (id) => setState(() => _kategoriId = id),
          ),
          const SizedBox(height: 16),
          _AkunChips(
            items: activeAccounts,
            selectedId: _akunId,
            onSelected: (id) =>
                setState(() => _akunId = _akunId == id ? null : id),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tanggal',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pilihTanggal,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: Neo.box(),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 10),
                      Text(DateFormat('d MMM yyyy', 'id_ID').format(_tanggal)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          NeoTextField(
            controller: _keterangan,
            label: 'Keterangan (opsional)',
            hint: 'mis. nama toko atau penanda',
          ),
          if (_imagePath != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simpan foto struk'),
              subtitle: const Text(
                'Mematikan ini membuang foto setelah disimpan.',
                style: TextStyle(fontSize: 12),
              ),
              value: _simpanGambar,
              activeThumbColor: Neo.ink,
              onChanged: _menyimpan
                  ? null
                  : (v) => setState(() => _simpanGambar = v),
            ),
          const SizedBox(height: 8),
          NeoButton(
            label: _menyimpan ? 'Menyimpan…' : 'Simpan',
            icon: Icons.check,
            expand: true,
            onPressed: _menyimpan ? null : _simpan,
          ),
        ],
      ),
      ),
    );
  }
}

class _KategoriChips extends StatelessWidget {
  const _KategoriChips({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Kategori',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
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

class _AkunChips extends StatelessWidget {
  const _AkunChips({
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<AccountWithInstitution> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Akun (opsional)',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      const SizedBox(height: 6),
      if (items.isEmpty)
        Text(
          'Belum ada akun — tambahkan dulu di Pengaturan.',
          style: TextStyle(color: Neo.muted, fontSize: 12),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((a) {
            final selected = a.account.id == selectedId;
            return ChoiceChip(
              label: Text(a.institusi.nama),
              selected: selected,
              onSelected: (_) => onSelected(a.account.id),
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
