import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/receipt.dart';
import '../services/receipt_scanner.dart';
import '../theme/app_theme.dart';
import '../widgets/neo.dart';

/// Layar uji ketepatan scan (Fase 4): harness korpus gambar.
///
/// Diakses tersembunyi dari Pengaturan (ketuk 5× judul) supaya tidak
/// mengotori menu harian. Alur: pilih beberapa foto struk dari galeri →
/// aplikasi menjalankan pipeline penuh (pra-proses → OCR → parse) untuk
/// tiap foto → bandingkan dengan `harapan.json` (dibundel sebagai asset)
/// dengan kunci = nama berkas tanpa ekstensi.
///
/// Syarat lolos sama seperti korpus teks: **nominal salah = 0**; "kosong"
/// hanya angka acuan. Tombol salin per baris membantu mengisi korpus teks:
/// tempel teks OCR ke `app/tool/korpus/teks/<nama>.txt` lalu isi jawaban di
/// `harapan.json` (lihat `app/tool/korpus/README.md`).
class ScanAccuracyScreen extends StatefulWidget {
  const ScanAccuracyScreen({super.key});

  @override
  State<ScanAccuracyScreen> createState() => _ScanAccuracyScreenState();
}

class _HasilUji {
  _HasilUji({
    required this.nama,
    required this.harapan,
    required this.teks,
    required this.draft,
    required this.varian,
  });

  final String nama;
  final Map<String, dynamic>? harapan;
  final String teks;
  final ReceiptDraft draft;
  final String varian;

  String get statusNominal {
    final harap = harapan?['nominal'] as int?;
    if (draft.nominal == harap) return 'benar';
    if (draft.nominal == null) return 'kosong';
    return 'SALAH';
  }}

class _ScanAccuracyScreenState extends State<ScanAccuracyScreen> {
  final _picker = ImagePicker();
  var _jalan = false;
  var _sudahMuat = false;
  Map<String, dynamic> _harapan = const {};
  final _hasil = <_HasilUji>[];

  @override
  void initState() {
    super.initState();
    _muatHarapan();
  }

  Future<void> _muatHarapan() async {
    try {
      final raw = await rootBundle.loadString('tool/korpus/harapan.json');
      final isi = jsonDecode(raw);
      if (!mounted) return;
      setState(() {
        _harapan = isi is Map<String, dynamic> ? isi : const {};
        _sudahMuat = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sudahMuat = true);
    }
  }

  String _kunci(String path) {
    final nama = path.split('/').last;
    final titik = nama.lastIndexOf('.');
    return titik < 0 ? nama : nama.substring(0, titik);
  }

  Future<void> _pilihDanUji() async {
    if (_jalan) return;
    final daftar = await _picker.pickMultiImage();
    if (daftar.isEmpty || !mounted) return;
    setState(() {
      _jalan = true;
      _hasil.clear();
    });
    for (final x in daftar) {
      final hasil = await ReceiptScanner.scanTerbaik(x.path);
      if (!mounted) return;
      final kunci = _kunci(x.path);
      final harap = _harapan[kunci];
      setState(() {
        _hasil.add(
          _HasilUji(
            nama: kunci,
            harapan: harap is Map<String, dynamic> ? harap : null,
            teks: hasil.teks,
            draft: hasil.draft,
            varian: hasil.varian,
          ),
        );
      });
    }
    if (mounted) setState(() => _jalan = false);
  }

  @override
  Widget build(BuildContext context) {
    final salah = _hasil.where((h) => h.statusNominal == 'SALAH').length;
    final benar = _hasil.where((h) => h.statusNominal == 'benar').length;
    final kosong = _hasil.where((h) => h.statusNominal == 'kosong').length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uji ketepatan scan'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(Neo.borderW),
          child: SizedBox(height: Neo.borderW, child: ColoredBox(color: Neo.ink)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Pilih foto struk dari galeri. Tiap foto diproses pipeline penuh '
            '(pra-proses → OCR → parse) dan dibandingkan dengan harapan.json. '
            'Syarat lolos: nominal SALAH harus 0.',
            style: TextStyle(color: Neo.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          NeoButton(
            label: _jalan ? 'Menguji…' : 'Pilih foto & uji',
            icon: Icons.science_outlined,
            expand: true,
            onPressed: _jalan ? null : _pilihDanUji,
          ),
          if (!_sudahMuat)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: NeoLoading(message: 'Memuat harapan…'),
            ),
          if (_hasil.isNotEmpty) ...[
            const SizedBox(height: 12),
            NeoCard(
              child: Text(
                '${_hasil.length} foto: $benar benar, $salah SALAH, '
                '$kosong kosong (acuan)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: salah > 0 ? Neo.expense : Neo.ink,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final h in _hasil)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h.nama,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: Neo.box(),
                          child: Text(
                            h.statusNominal,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: h.statusNominal == 'SALAH'
                                  ? Neo.expense
                                  : Neo.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Varian: ${h.varian} • sumber: ${h.draft.sumber.name}',
                      style: TextStyle(color: Neo.muted, fontSize: 12),
                    ),
                    Text(
                      'Dapat: ${h.draft.nominal ?? '(kosong)'} '
                      '• harap: ${h.harapan?['nominal'] ?? '(belum ada jawaban)'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: h.teks));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Teks OCR ${h.nama} disalin — tempel ke '
                                'app/tool/korpus/teks/${h.nama}.txt',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Salin teks OCR'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
