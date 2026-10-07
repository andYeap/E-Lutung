import 'dart:convert';
import 'dart:io';

import 'package:elutung/data/receipt.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mengukur ketepatan `parseReceipt` atas korpus struk **nyata**.
///
/// Teks di `tool/korpus/teks/` berasal dari hasil scan di HP (ML Kit), bukan
/// teks contoh yang dipakai menulis aturannya sendiri — justru itu gunanya.
/// Jawaban benar ada di `tool/korpus/harapan.json`; `null` berarti "harus
/// kosong", sengaja dibedakan dari salah.
///
/// Aturan lolos: **nominal salah = 0**. "Kosong" tidak dihitung salah, tetapi
/// jumlahnya dicetak sebagai angka acuan untuk dibandingkan sebelum-sesudah
/// setiap perubahan parser. Tanggal dan merchant dinilai terpisah.
///
/// Cara menambah berkas baru ada di `tool/korpus/README.md`.
void main() {
  final korpus = _muatKorpus();

  test('korpus struk: nominal salah harus nol', () {
    if (korpus.entri.isEmpty) {
      markTestSkipped(
        'Korpus masih kosong. Tambahkan teks OCR ke tool/korpus/teks/ dan '
        'harapannya di harapan.json (lihat tool/korpus/README.md).',
      );
      return;
    }

    final hasil = [for (final e in korpus.entri) _nilai(e)];
    stdout.writeln(_laporan(hasil));

    expect(
      korpus.masalah,
      isEmpty,
      reason: 'Struktur korpus tidak lengkap:\n${korpus.masalah.join('\n')}',
    );

    final nominalSalah =
        hasil.where((h) => h.nominal.nilai == _Nilai.salah).toList();
    expect(
      nominalSalah.map((h) => h.nama).toList(),
      isEmpty,
      reason:
          'Nominal salah pada: ${nominalSalah.map((h) => h.nama).join(', ')}. '
          'Dalam aplikasi uang, angka yang yakin tetapi salah lebih berbahaya '
          'daripada kosong.',
    );
  });
}

enum _Nilai { benar, salah, kosong }

/// Satu baris korpus: teks OCR beserta jawaban benarnya.
class _Entri {
  _Entri({
    required this.nama,
    required this.teks,
    required this.nominal,
    required this.tanggal,
    required this.merchant,
  });

  final String nama;
  final String teks;
  final int? nominal;
  final DateTime? tanggal;
  final String? merchant;
}

/// Hasil penilaian satu field.
class _Penilaian {
  const _Penilaian(this.nilai, this.dapat);

  final _Nilai nilai;
  final String dapat;

  String get label => switch (nilai) {
    _Nilai.benar => 'benar',
    _Nilai.salah => 'SALAH',
    _Nilai.kosong => 'kosong',
  };
}

class _Hasil {
  _Hasil({
    required this.nama,
    required this.nominal,
    required this.tanggal,
    required this.merchant,
  });

  final String nama;
  final _Penilaian nominal;
  final _Penilaian tanggal;
  final _Penilaian merchant;
}

class _KorpusData {
  _KorpusData(this.entri, this.masalah);

  final List<_Entri> entri;
  final List<String> masalah;
}

/// Folder korpus, dicoba relatif terhadap akar paket (`flutter test` dijalankan
/// dari `app/`). Bila tidak ditemukan, korpus dianggap kosong.
Directory? _cariKorpus() {
  for (final kandidat in ['tool/korpus', 'app/tool/korpus']) {
    final dir = Directory(kandidat);
    if (dir.existsSync()) return dir;
  }
  return null;
}

_KorpusData _muatKorpus() {
  final dir = _cariKorpus();
  if (dir == null) {
    return _KorpusData(const [], const ['Folder tool/korpus tidak ditemukan.']);
  }

  final masalah = <String>[];
  final teksDir = Directory('${dir.path}/teks');

  final berkasTeks = <String, String>{};
  if (teksDir.existsSync()) {
    for (final f in teksDir.listSync()) {
      if (f is! File) continue;
      final nama = f.uri.pathSegments.last;
      if (!nama.endsWith('.txt')) continue;
      final kunci = nama.substring(0, nama.length - 4);
      if (kunci.isEmpty) continue;
      berkasTeks[kunci] = f.readAsStringSync();
    }
  }

  final harapanFile = File('${dir.path}/harapan.json');
  Map<String, dynamic> harapan = const {};
  if (harapanFile.existsSync()) {
    try {
      final isi = jsonDecode(harapanFile.readAsStringSync());
      if (isi is Map<String, dynamic>) harapan = isi;
    } catch (e) {
      masalah.add('harapan.json tidak bisa dibaca: $e');
    }
  }

  final namaSemua = <String>{...berkasTeks.keys, ...harapan.keys}.toList()
    ..sort();
  final entri = <_Entri>[];
  for (final nama in namaSemua) {
    final teks = berkasTeks[nama];
    final harap = harapan[nama];
    if (teks == null) {
      masalah.add('$nama: ada di harapan.json tetapi teks/$nama.txt tidak ada.');
      continue;
    }
    if (harap == null) {
      masalah.add('$nama: teks ada tetapi tidak ada di harapan.json.');
      continue;
    }
    if (harap is! Map<String, dynamic>) {
      masalah.add('$nama: entri harapan bukan objek.');
      continue;
    }
    if (!harap.containsKey('nominal') ||
        !harap.containsKey('tanggal') ||
        !harap.containsKey('merchant')) {
      masalah.add(
        '$nama: harapan harus memuat nominal, tanggal, dan merchant '
        '(nilai null berarti "harus kosong").',
      );
      continue;
    }
    entri.add(
      _Entri(
        nama: nama,
        teks: teks,
        nominal: harap['nominal'] as int?,
        tanggal: _tanggalDari(harap['tanggal']),
        merchant: harap['merchant'] as String?,
      ),
    );
  }

  return _KorpusData(entri, masalah);
}

DateTime? _tanggalDari(Object? raw) {
  if (raw is! String) return null;
  final d = DateTime.tryParse(raw);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

_Hasil _nilai(_Entri e) {
  final draft = parseReceipt(e.teks);
  return _Hasil(
    nama: e.nama,
    nominal: _bandingAngka(e.nominal, draft.nominal),
    tanggal: _bandingTanggal(e.tanggal, draft.tanggal),
    merchant: _bandingMerchant(e.merchant, draft.merchant),
  );
}

_Penilaian _bandingAngka(int? harap, int? dapat) {
  if (dapat == harap) return _Penilaian(_Nilai.benar, '$dapat');
  if (dapat == null) return const _Penilaian(_Nilai.kosong, '(kosong)');
  return _Penilaian(_Nilai.salah, '$dapat');
}

_Penilaian _bandingTanggal(DateTime? harap, DateTime? dapat) {
  if (dapat == harap) {
    return _Penilaian(_Nilai.benar, dapat == null ? '(kosong)' : _iso(dapat));
  }
  if (dapat == null) return const _Penilaian(_Nilai.kosong, '(kosong)');
  return _Penilaian(_Nilai.salah, _iso(dapat));
}

_Penilaian _bandingMerchant(String? harap, String? dapat) {
  if (dapat == null) {
    return harap == null
        ? const _Penilaian(_Nilai.benar, '(kosong)')
        : const _Penilaian(_Nilai.kosong, '(kosong)');
  }
  if (harap == null) return _Penilaian(_Nilai.salah, dapat);
  // Merchant dinilai lentur: yang penting pedagangnya terbaca, bukan ejaannya
  // sama persis dengan cetakan struk.
  final a = _rapi(harap);
  final b = _rapi(dapat);
  if (a.contains(b) || b.contains(a)) return _Penilaian(_Nilai.benar, dapat);
  return _Penilaian(_Nilai.salah, dapat);
}

String _rapi(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _laporan(List<_Hasil> hasil) {
  final buf = StringBuffer()
    ..writeln('')
    ..writeln('=== Matriks korpus struk (${hasil.length} berkas) ===');
  for (final h in hasil) {
    buf.writeln(
      '${h.nama.padRight(24)} '
      'nominal: ${h.nominal.label.padRight(7)} (${h.nominal.dapat})  '
      'tanggal: ${h.tanggal.label.padRight(7)} (${h.tanggal.dapat})  '
      'merchant: ${h.merchant.label.padRight(7)} (${h.merchant.dapat})',
    );
  }
  int jumlah(_Nilai n, _Penilaian Function(_Hasil) f) =>
      hasil.where((h) => f(h).nilai == n).length;
  buf.writeln('---');
  buf.writeln(
    'nominal: ${jumlah(_Nilai.benar, (h) => h.nominal)} benar, '
    '${jumlah(_Nilai.salah, (h) => h.nominal)} SALAH, '
    '${jumlah(_Nilai.kosong, (h) => h.nominal)} kosong '
    '(kosong adalah angka acuan, bukan kegagalan)',
  );
  buf.writeln(
    'tanggal: ${jumlah(_Nilai.benar, (h) => h.tanggal)} benar, '
    '${jumlah(_Nilai.salah, (h) => h.tanggal)} salah, '
    '${jumlah(_Nilai.kosong, (h) => h.tanggal)} kosong',
  );
  buf.writeln(
    'merchant: ${jumlah(_Nilai.benar, (h) => h.merchant)} benar, '
    '${jumlah(_Nilai.salah, (h) => h.merchant)} salah, '
    '${jumlah(_Nilai.kosong, (h) => h.merchant)} kosong',
  );
  buf.writeln('================================================');
  return buf.toString();
}
