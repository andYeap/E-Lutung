import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _decimal = NumberFormat.decimalPattern('id_ID');

bool _intlReady = false;

/// Muat data locale `id_ID` untuk DateFormat/NumberFormat.
///
/// WAJIB dipanggil sebelum memakai `DateFormat(..., 'id_ID')` — tanpa ini intl
/// melempar `LocaleDataException` (mis. saat membuka dialog Anggaran).
Future<void> ensureIntlLocale([String locale = 'id_ID']) async {
  if (_intlReady) return;
  await initializeDateFormatting(locale);
  Intl.defaultLocale = locale;
  _intlReady = true;
}

/// Format rupiah untuk tampilan (Bagian 6 teknologi: IDR, locale id_ID).
String rupiah(num value) => _idr.format(value);

/// Angka dengan pemisah ribuan gaya Indonesia ("25.000").
String formatThousands(int value) => _decimal.format(value);

/// Baca angka dari input berformat apa pun ("Rp 50.000" -> 50000).
int parseRupiah(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  // `tryParse`: input yang sangat panjang (di luar jangkauan int) dianggap 0,
  // bukan melempar FormatException.
  return int.tryParse(digits) ?? 0;
}

/// Waktu relatif untuk daftar transaksi terbaru (FR-1.2), mis. "2 jam lalu".
String relativeTime(DateTime when, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(when);
  if (d.isNegative) return DateFormat('d MMM yyyy', 'id_ID').format(when);
  if (d.inMinutes < 1) return 'Baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  if (d.inDays == 1) return 'Kemarin';
  if (d.inDays < 7) return '${d.inDays} hari lalu';
  return DateFormat('d MMM yyyy', 'id_ID').format(when);
}

/// Formatter input: hanya angka, otomatis diberi pemisah ribuan (FR-2.6).
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final value = int.tryParse(digits);
    if (value == null) return oldValue;
    final formatted = formatThousands(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
