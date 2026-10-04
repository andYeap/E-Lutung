import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/app_theme.dart';
import 'transaction_form_screen.dart';

/// Lembar pilihan tipe transaksi.
///
/// Dipakai **bersama** oleh Dashboard dan Riwayat supaya keduanya punya satu
/// tombol tambah yang sama. Sebelumnya Riwayat menumpuk tiga FAB sekaligus,
/// yang menutupi isi daftar.
Future<void> showAddTransactionSheet(BuildContext context) async {
  final tipe = await showModalBottomSheet<TxType>(
    context: context,
    backgroundColor: Neo.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Neo.radius),
      side: BorderSide(color: Neo.ink, width: Neo.borderW),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.south_west, color: Neo.income),
            title: const Text('Pemasukan'),
            onTap: () => Navigator.pop(ctx, TxType.pemasukan),
          ),
          ListTile(
            leading: Icon(Icons.north_east, color: Neo.expense),
            title: const Text('Pengeluaran'),
            onTap: () => Navigator.pop(ctx, TxType.pengeluaran),
          ),
          ListTile(
            leading: Icon(Icons.swap_horiz, color: Neo.transfer),
            title: const Text('Transfer'),
            onTap: () => Navigator.pop(ctx, TxType.transfer),
          ),
        ],
      ),
    ),
  );

  if (tipe == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => TransactionFormScreen(tipe: tipe)),
  );
}
