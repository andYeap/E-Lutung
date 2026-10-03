import 'package:flutter/material.dart';

import '../data/database.dart';

String institutionTypeLabel(InstitutionType t) => switch (t) {
  InstitutionType.bank => 'Bank',
  InstitutionType.ewallet => 'E-Wallet',
  InstitutionType.tunai => 'Tunai',
  InstitutionType.lain => 'Lain-lain',
};

IconData institutionTypeIcon(InstitutionType t) => switch (t) {
  InstitutionType.bank => Icons.account_balance,
  InstitutionType.ewallet => Icons.account_balance_wallet,
  InstitutionType.tunai => Icons.payments,
  InstitutionType.lain => Icons.more_horiz,
};
