import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../providers.dart';
import '../util/format.dart';
import '../services/app_lock.dart';
import '../services/recurring_runner.dart';
import '../services/widget_sync.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/neo.dart';
import 'accounts_screen.dart';
import 'budget/budget_screen.dart';
import 'categories_screen.dart';
import 'dashboard_screen.dart';
import 'institutions_screen.dart';
import 'recap/recap_screen.dart';
import 'recurring/recurring_screen.dart';
import 'theme/theme_screen.dart';
import 'transactions/add_transaction_sheet.dart';
import 'transactions/transaction_form_screen.dart';
import 'transactions/transactions_screen.dart';
import 'trash_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;
  StreamSubscription<Uri?>? _widgetClickSub;

  static const _titles = ['Dashboard', 'Riwayat', 'Rekap', 'Anggaran'];

  @override
  void initState() {
    super.initState();
    // Bangkitkan transaksi terjadwal lalu dorong data ke widget beranda.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapData());
    // Pengingat cadangan bila sudah lama tidak mengekspor (FR-10.4).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRemindBackup());
    // Ketukan widget beranda membuka detail transaksi terbaru (FR-9.6).
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleWidgetLaunch());
    _widgetClickSub = HomeWidget.widgetClicked.listen(
      _handleWidgetUri,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    super.dispose();
  }

  Future<void> _handleWidgetLaunch() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      await _handleWidgetUri(uri);
    } catch (_) {
      // Peluncuran biasa — tidak ada URI widget.
    }
  }

  Future<void> _handleWidgetUri(Uri? uri) async {
    if (uri == null || uri.host != 'open') return;
    final all = await ref.read(transactionRepositoryProvider).all();
    if (all.isEmpty) return;
    all.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    final latest = all.first;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(tipe: latest.tipe, initial: latest),
      ),
    );
  }

  Future<void> _maybeRemindBackup() async {
    if (!await BackupService.shouldRemindBackup()) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sudah lama tidak mencadangkan data.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Cadangkan',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ),
    );
  }

  /// Tombol tambah sesuai tab yang sedang aktif. Rekap tidak punya aksi tambah.
  Widget? _buildFab() {
    if (_index == 2) return null;

    final bentuk = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Neo.radius),
      side: BorderSide(color: Neo.ink, width: Neo.borderW),
    );

    if (_index == 3) {
      return FloatingActionButton(
        heroTag: 'shell-add-budget',
        tooltip: 'Tambah anggaran',
        backgroundColor: Neo.accent,
        foregroundColor: Neo.ink,
        elevation: 0,
        shape: bentuk,
        onPressed: () => showBudgetForm(
          context,
          ref,
          ref.read(categoriesProvider).value ?? const <Category>[],
        ),
        child: const Icon(Icons.add),
      );
    }

    return FloatingActionButton.extended(
      heroTag: 'shell-add-transaction',
      onPressed: () => showAddTransactionSheet(context),
      backgroundColor: Neo.accent,
      foregroundColor: Neo.ink,
      elevation: 0,
      shape: bentuk,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Future<void> _syncWidget() =>
      WidgetSync.push(ref.read(databaseProvider));

  /// Bangkitkan transaksi dari aturan berulang yang jatuh tempo (FR-12.2),
  /// baru segarkan widget supaya ikut menampilkan hasilnya.
  Future<void> _bootstrapData() async {
    var created = 0;
    try {
      created = await RecurringRunner.runDue(ref.read(databaseProvider));
    } catch (e) {
      debugPrint('[Recurring] gagal membangkitkan transaksi: $e');
    }
    await _syncWidget();
    if (created > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created == 1
                ? '1 transaksi dari jadwal dibuat.'
                : '$created transaksi dari jadwal dibuat.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Segarkan widget setiap data berubah (Bagian FR-9.5).
    ref.listen(allTransactionsProvider, (_, _) => _syncWidget());
    ref.listen(budgetsProvider, (_, _) => _syncWidget());
    ref.listen(accountsProvider, (_, _) => _syncWidget());

    return Scaffold(
      appBar: AppBar(
        title: Text('E-Lutung — ${_titles[_index]}'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          TransactionsScreen(),
          RecapScreen(),
          BudgetScreen(),
        ],
      ),
      // Satu tombol tambah milik shell, bukan milik tiap tab.
      //
      // Ini bukan sekadar merapikan: SnackBar yang muncul dari shell dirender
      // oleh Scaffold ini, dan Flutter hanya menaruh SnackBar mengambang **di
      // atas FAB** bila keduanya berada di Scaffold yang sama. Waktu FAB masih
      // di dalam tab, SnackBar menutupi tombolnya.
      floatingActionButton: _buildFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Rekap',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Anggaran',
          ),
        ],
      ),
    );
  }
}

/// Pengaturan — Institusi, Akun, tema, dan cadangan.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(backupServiceProvider);
    final theme = ThemeController.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
            icon: Icons.account_balance,
            title: 'Institusi',
            subtitle: 'Bank, e-wallet, tunai',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InstitutionsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.account_balance_wallet,
            title: 'Akun',
            subtitle: 'Dompet yang kamu pakai',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.savings,
            title: 'Anggaran',
            subtitle: 'Atur batas pengeluaran (Bagian FR-6)',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BudgetScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.sell,
            title: 'Kategori',
            subtitle: 'Kelola kategori pengeluaran/pemasukan',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.autorenew,
            title: 'Transaksi berulang',
            subtitle: 'Gaji, langganan, pengeluaran rutin',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecurringScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: theme,
            builder: (context, _) => _SettingsTile(
              icon: Icons.palette,
              title: 'Tema & warna',
              subtitle: '${themeModeLabel(theme.mode)} • ${theme.preset.name}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ThemeScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.language,
            title: 'Format & lokalisasi',
            subtitle: 'Rupiah (IDR) • Bahasa Indonesia',
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Format & lokalisasi'),
                content: Text(
                  'Mata uang: Rupiah (IDR), tanpa desimal.\n'
                  'Locale: id_ID (tanggal & angka gaya Indonesia).\n\n'
                  'Contoh nominal: ${rupiah(1250000)}\n'
                  'Contoh tanggal: '
                  '${DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.now())}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: AppLock.instance,
            builder: (context, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.lock_outline),
              title: const Text('Kunci aplikasi'),
              subtitle: const Text('Minta PIN/biometrik perangkat saat membuka'),
              value: AppLock.instance.enabled,
              activeThumbColor: Neo.ink,
              onChanged: (v) async {
                if (v) {
                  final ok = await AppLock.instance.authenticate();
                  if (!ok) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Autentikasi gagal — kunci tidak diaktifkan.'),
                        ),
                      );
                    }
                    return;
                  }
                  await AppLock.instance.setEnabled(true);
                } else {
                  await AppLock.instance.setEnabled(false);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.widgets,
            title: 'Pasang widget beranda',
            subtitle: 'Tampilkan ringkasan di beranda HP',
            onTap: () async {
              final msg = await WidgetSync.requestPin(ref.read(databaseProvider));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.ios_share,
            title: 'Ekspor cadangan',
            subtitle: 'Simpan/bagikan seluruh data (JSON)',
            onTap: () async {
              final ok = await backup.shareBackup();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Menyiapkan file cadangan…' : 'Gagal mengekspor'),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.table_chart,
            title: 'Ekspor CSV',
            subtitle: 'Transaksi untuk Excel/Sheets',
            onTap: () async {
              final ok = await backup.shareCsv();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Menyiapkan CSV…' : 'Gagal mengekspor CSV')),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: 'Sampah',
            subtitle: 'Pulihkan transaksi yang dihapus',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.restore,
            title: 'Impor cadangan',
            subtitle: 'Pulihkan dari file JSON',
            onTap: () => _importDialog(context, backup),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.delete_forever,
            title: 'Hapus semua data',
            subtitle: 'Hapus transaksi, anggaran, dan akun',
            onTap: () => _wipeDialog(context, backup),
          ),
        ],
      ),
    );
  }
}

Future<void> _wipeDialog(BuildContext context, BackupService backup) async {
  final first = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus semua data?'),
      content: const Text(
        'Semua transaksi, anggaran, aturan berulang, dan akun akan dihapus. '
        'Master institusi & kategori tetap. Tindakan ini tidak bisa dibatalkan.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        NeoButton(
          label: 'Lanjut',
          color: Neo.expense,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (first != true || !context.mounted) return;
  // Konfirmasi kedua (FR-11.4).
  final second = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Yakin?'),
      content: const Text('Ketuk "Hapus sekarang" untuk benar-benar menghapus.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        NeoButton(
          label: 'Hapus sekarang',
          color: Neo.expense,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (second != true) return;
  await backup.wipeUserData();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Data transaksi, anggaran, dan akun dihapus.')),
  );
}

Future<void> _importDialog(BuildContext context, BackupService backup) async {
  final mode = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Impor cadangan'),
      content: const Text(
        'Pilih cara impor:\n• Ganti — data sekarang dihapus dulu\n• Gabung — tambahkan/update berdasarkan id',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, 'merge'), child: const Text('Gabung')),
        NeoButton(label: 'Ganti', onPressed: () => Navigator.pop(ctx, 'replace')),
      ],
    ),
  );
  if (mode == null || !context.mounted) return;
  final n = await backup.importFile(replace: mode == 'replace');
  if (!context.mounted) return;
  final msg = n == -1
      ? 'Impor dibatalkan'
      : (n == 0 ? 'Impor gagal / file tidak valid' : 'Berhasil impor $n baris');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: Neo.box(),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(subtitle, style: TextStyle(color: Neo.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
