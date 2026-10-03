import 'package:flutter/material.dart';

/// Ubah hex ("#RRGGBB" / "RRGGBB" / "#AARRGGBB") jadi Color.
Color parseHexColor(String? hex, {Color fallback = const Color(0xFF94A3B8)}) {
  if (hex == null || hex.trim().isEmpty) return fallback;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}
