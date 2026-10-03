import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/finance.dart';
import '../util/budget.dart';
import '../util/format.dart';

/// Menulis ringkasan ke data widget lalu memicu render ulang (Bagian FR-9).
///
/// Kunci yang dikirim dibaca oleh `ElutungWidgetProvider` (Android) dan harus
/// sama dengan `android/app/src/main/res/layout/widget_elutung.xml`:
/// `widget_income_month`, `widget_expense_month`, `widget_budget_remaining`,
/// `widget_budget_pct`, `widget_budget_color`, `widget_latest_1..3`.
///
/// Penamaan mengikuti Bagian 12 PRD; `widget_budget_color` adalah tambahan
/// untuk indikator warna Bagian 8.2 (FR-9.3).
class WidgetSync {
  WidgetSync._();

  static const _qualifiedAndroidName =
      'com.elutung.elutung.ElutungWidgetProvider';

  /// Minta sistem memasang widget ke beranda (Android API 26+, launcher yang
  /// mendukung). Mengembalikan pesan untuk ditampilkan ke pengguna.
  static Future<String> requestPin(AppDatabase db) async {
    await push(db);
    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (supported) {
        await HomeWidget.requestPinWidget(
          qualifiedAndroidName: _qualifiedAndroidName,
        );
        return 'Ikuti dialog untuk menaruh widget di beranda.';
      }
    } catch (_) {
      // jatuh ke instruksi manual
    }
    return 'Launcher ini tidak mendukung pemasangan otomatis. '
        'Tahan lama di beranda → Widget → E-Lutung.';
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Future<void> push(AppDatabase db) async {
    try {
      final txs = await (db.select(db.transactions)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      final accounts = await (db.select(db.accounts)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      final budgets = await (db.select(db.budgets)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      final categories = await db.select(db.categories).get();

      final ownIds = accounts
          .where((a) => a.milikSendiri)
          .map((a) => a.id)
          .toSet();

      final now = DateTime.now();
      final monthTx = txs
          .where((t) => t.tanggal.year == now.year && t.tanggal.month == now.month)
          .toList();
      final totals = computeTotals(monthTx, ownIds);

      await HomeWidget.saveWidgetData<String>(
        'widget_income_month',
        'Masuk: ${rupiah(totals.income)}',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_expense_month',
        'Keluar: ${rupiah(totals.expense)}',
      );

      var budgetRemaining = 'Anggaran: belum disetel';
      var budgetPct = '';
      var budgetColorHex = '#3A3934';
      for (final b in budgets) {
        if (!b.aktif || b.lingkup != BudgetScope.total) continue;
        final end = DateTime(
          b.periodeSelesai.year,
          b.periodeSelesai.month,
          b.periodeSelesai.day,
          23,
          59,
          59,
        );
        if (now.isBefore(b.periodeMulai) || now.isAfter(end)) continue;
        final usage = budgetUsageOf(b, txs, ownIds);
        final level = budgetLevel(usage.fraction);
        budgetRemaining = 'Sisa ${rupiah(usage.remaining)}';
        budgetPct = '${(usage.fraction * 100).toStringAsFixed(0)}%';
        budgetColorHex = _hex(budgetColor(level));
        break;
      }
      await HomeWidget.saveWidgetData<String>(
        'widget_budget_remaining',
        budgetRemaining,
      );
      await HomeWidget.saveWidgetData<String>('widget_budget_pct', budgetPct);
      await HomeWidget.saveWidgetData<String>(
        'widget_budget_color',
        budgetColorHex,
      );

      final catName = {for (final c in categories) c.id: c.nama};
      final latest = <String>[];
      if (txs.isNotEmpty) {
        final sorted = [...txs]..sort((a, b) => b.tanggal.compareTo(a.tanggal));
        for (final t in sorted.take(3)) {
          final label = t.tipe == TxType.transfer
              ? 'Transfer'
              : (catName[t.kategoriId] ?? 'Transaksi');
          final sign = switch (t.tipe) {
            TxType.pemasukan => '+',
            TxType.pengeluaran => '−',
            TxType.transfer => '',
          };
          latest.add(
            '$label $sign${rupiah(t.nominal)} • ${DateFormat('d MMM', 'id_ID').format(t.tanggal)}',
          );
        }
      }
      await HomeWidget.saveWidgetData<String>(
        'widget_latest_1',
        latest.isNotEmpty ? latest[0] : 'Belum ada transaksi',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_latest_2',
        latest.length > 1 ? latest[1] : '',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_latest_3',
        latest.length > 2 ? latest[2] : '',
      );

      await HomeWidget.updateWidget(
        qualifiedAndroidName: _qualifiedAndroidName,
      );
    } catch (e) {
      debugPrint('[WidgetSync] gagal memperbarui widget: $e');
    }
  }
}
