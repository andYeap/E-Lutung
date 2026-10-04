import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'format.dart';

/// Tingkat pemakaian anggaran (Bagian 8.2).
enum BudgetLevel { aman, waspada, menipis, lewat }

/// persentase terpakai = pengeluaran / nominal.
BudgetLevel budgetLevel(double usedFraction) {
  if (usedFraction >= 1.0) return BudgetLevel.lewat;
  if (usedFraction >= 0.85) return BudgetLevel.menipis;
  if (usedFraction >= 0.60) return BudgetLevel.waspada;
  return BudgetLevel.aman;
}

Color budgetColor(BudgetLevel level) => switch (level) {
  BudgetLevel.aman => Neo.income,
  BudgetLevel.waspada => const Color(0xFFEAB308),
  BudgetLevel.menipis => const Color(0xFFF97316),
  BudgetLevel.lewat => Neo.expense,
};

/// Teks sisa anggaran dengan tanda minus yang sama seperti tampilan transaksi
/// (U+2212), bukan tanda hubung dari formatter mata uang.
String sisaAnggaranTeks(int remaining) =>
    remaining < 0 ? '−${rupiah(-remaining)}' : rupiah(remaining);

String budgetLevelLabel(BudgetLevel level) => switch (level) {
  BudgetLevel.aman => 'Aman',
  BudgetLevel.waspada => 'Waspada',
  BudgetLevel.menipis => 'Menipis',
  BudgetLevel.lewat => 'Lewat batas',
};
