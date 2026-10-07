import 'package:elutung/theme/neo_palette.dart';
import 'package:elutung/util/contrast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pengaman tema (Bagian 6c): peringatan kontras dan peringatan warna yang
/// terlalu mirip makna pemasukan/pengeluaran.
void main() {
  group('rasio kontras', () {
    test('sesuai rumus WCAG', () {
      expect(contrastRatio(Colors.white, Colors.black), closeTo(21, 0.01));
      expect(contrastRatio(Colors.black, Colors.black), closeTo(1, 0.001));
      // Simetris terhadap urutan argumen.
      const arang = Color(0xFF3A3934);
      expect(
        contrastRatio(Colors.white, arang),
        closeTo(contrastRatio(arang, Colors.white), 0.0001),
      );
    });

    test('ambang AA berbeda untuk teks biasa dan teks besar', () {
      const abuLolos = Color(0xFF767676); // sekitar 4.5 terhadap putih
      const abuTengah = Color(0xFF8A8A8A); // sekitar 3.4: gagal biasa, lolos besar
      const abuGagal = Color(0xFF999999); // sekitar 2.8
      expect(meetsWcagAA(abuLolos, Colors.white), isTrue);
      expect(meetsWcagAA(abuTengah, Colors.white), isFalse);
      expect(meetsWcagAA(abuTengah, Colors.white, largeText: true), isTrue);
      expect(meetsWcagAA(abuGagal, Colors.white, largeText: true), isFalse);
    });
  });

  group('readableOn', () {
    test('memilih teks yang terbaca di atas latar apa pun', () {
      // Menyapu seluruh rentang kecerahan: hasilnya tidak boleh pernah jatuh di
      // bawah ambang WCAG AA (4.5) untuk teks normal.
      for (var i = 0; i <= 100; i++) {
        final latar = Color.fromARGB(255, i * 2, i * 2, i * 2);
        final teks = readableOn(latar);
        expect(
          contrastRatio(teks, latar),
          greaterThanOrEqualTo(4.5),
          reason: 'latar $latar',
        );
      }
    });

    test('aksen terang memakai teks gelap, aksen gelap memakai teks terang', () {
      expect(readableOn(const Color(0xFFF2CE6B)), Colors.black);
      expect(readableOn(const Color(0xFF2A2C30)), Colors.white);
    });
  });

  group('kemiripan makna', () {
    test('abu gelap tidak pernah dianggap mirip warna semantik', () {
      // Jarak RGB mentah akan menganggap arang ini "dekat" dengan hijau.
      const arang = Color(0xFF3A3934);
      for (final semantik in kSemanticColors) {
        expect(
          miripWarnaSemantik(arang, semantik),
          isFalse,
          reason: 'arang vs $semantik',
        );
      }
    });

    test('warna yang benar-benar sama terdeteksi mirip', () {
      for (final semantik in kSemanticColors) {
        expect(miripWarnaSemantik(semantik, semantik), isTrue);
      }
    });

    test('rona berbeda tidak dianggap mirip walau sama-sama biru', () {
      // Cyan lembut vs indigo transfer.
      expect(
        miripWarnaSemantik(const Color(0xFF7FC4D6), kTransferColor),
        isFalse,
      );
    });
  });

  group('paletteWarnings', () {
    test('semua preset bawaan bersih tanpa peringatan', () {
      for (final preset in kThemePresets) {
        expect(paletteWarnings(preset.light), isEmpty, reason: '${preset.id} terang');
        expect(paletteWarnings(preset.dark), isEmpty, reason: '${preset.id} gelap');
      }
    });

    test('varian gelap bawaan nyaman: tidak hitam pekat, kontrasnya tidak ekstrem', () {
    for (final preset in kThemePresets) {
      final gelap = preset.dark;
      // Latar hitam pekat membuat teks terang terasa menyala di mata.
      expect(
        gelap.bg.computeLuminance(),
        greaterThan(0.012),
        reason: '${preset.id}: latar terlalu pekat',
      );

      // Ambang bawah demi keterbacaan, ambang atas demi kenyamanan: di atas
      // sekitar 12:1 huruf terang di latar gelap mulai melelahkan.
      final rasio = contrastRatio(gelap.ink, gelap.bg);
      expect(
        rasio,
        greaterThanOrEqualTo(4.5),
        reason: '${preset.id}: teks terlalu redup (${rasio.toStringAsFixed(1)}:1)',
      );
      expect(
        rasio,
        lessThanOrEqualTo(11),
        reason: '${preset.id}: teks terlalu menyala (${rasio.toStringAsFixed(1)}:1)',
      );
    }
  });

  test('kontras rendah memunculkan peringatan', () {
      const p = NeoPalette(
        bg: Color(0xFFF6F5F1),
        surface: Color(0xFFFCFCFA),
        ink: Color(0xFFEDEDE8), // nyaris sama dengan latar
        appBar: Color(0xFFF2CE6B),
        accent: Color(0xFFF2CE6B),
      );
      final peringatan = paletteWarnings(p);
      expect(peringatan, isNotEmpty);
      expect(peringatan.any((s) => s.contains('latar')), isTrue);
    });

    test('aksen senada warna pengeluaran diperingatkan', () {
      const p = NeoPalette(
        bg: Color(0xFFF1F1EE),
        surface: Color(0xFFFBFBF9),
        ink: Color(0xFF33322E),
        appBar: Color(0xFFC9C9CE),
        accent: kExpenseColor,
      );
      expect(
        paletteWarnings(p).any((s) => s.contains('pengeluaran')),
        isTrue,
      );
    });
  });
}
