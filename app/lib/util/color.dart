import 'package:flutter/material.dart';

/// Ubah Color jadi hex "#RRGGBB".
String hexColor(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Seperti [parseHexColor], tapi mengembalikan null saat masukannya tidak sah.
/// Dipakai ketika pengguna mengetik hex sendiri, supaya bisa dibedakan dari
/// "warnanya hitam".
Color? tryParseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// Ubah hex ("#RRGGBB" / "RRGGBB" / "#AARRGGBB") jadi Color.
Color parseHexColor(String? hex, {Color fallback = const Color(0xFF94A3B8)}) {
  if (hex == null || hex.trim().isEmpty) return fallback;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}
