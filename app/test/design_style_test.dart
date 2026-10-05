import 'package:elutung/theme/app_theme.dart';
import 'package:elutung/theme/design_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gaya desain aplikasi (bentuk, border, bayangan, isian, tipografi).
void main() {
  tearDown(() => Neo.applyStyle(kDesignStyles.first));

  test('menyediakan tujuh gaya dari daftar gaya UI', () {
    expect(kDesignStyles.map((s) => s.id).toList(), [
      'brutal',
      'flat',
      'material',
      'neumorph',
      'glass',
      'skeuo',
      'minimal',
    ]);
    expect(kDesignStyles.first.id, 'brutal');
  });

  test('designStyleById jatuh ke gaya pertama bila tak dikenal', () {
    expect(designStyleById('glass').id, 'glass');
    expect(designStyleById('tidak-ada').id, kDesignStyles.first.id);
    expect(designStyleById(null).id, kDesignStyles.first.id);
  });

  test('token struktural Neo mengikuti gaya', () {
    Neo.applyStyle(designStyleById('brutal'));
    expect(Neo.borderW, 2);
    expect(Neo.radius, 4);
    expect(Neo.blur, 0);

    Neo.applyStyle(designStyleById('glass'));
    expect(Neo.borderW, 0);
    expect(Neo.radius, 18);
    expect(Neo.blur, greaterThan(0));
  });

  test('tipografi kembali ke bawaan; bentuk tombol & nav tetap khas', () {
    // Huruf dan kapitalisasi dikembalikan ke bawaan agar tidak menyakitkan mata.
    expect(kDesignStyles.every((s) => s.fontFamily == null), isTrue);
    expect(kDesignStyles.every((s) => !s.uppercase), isTrue);
    expect(kDesignStyles.every((s) => s.letterSpacing == 0), isTrue);

    final material = designStyleById('material');
    expect(material.buttonPill, isTrue);
    expect(material.navIndicator, NavIndicator.pill);

    final minimal = designStyleById('minimal');
    expect(minimal.navIndicator, NavIndicator.none);

    // Gaya pil memakai radius besar supaya bulat penuh.
    Neo.applyStyle(material);
    expect(Neo.buttonRadius, 999);
    Neo.applyStyle(designStyleById('brutal'));
    expect(Neo.buttonRadius, designStyleById('brutal').buttonRadius);
  });

  test('box() mengikuti isian permukaan dan bayangan gaya', () {
    Neo.applyStyle(designStyleById('brutal'));
    final brutal = Neo.box();
    expect(brutal.border, isNotNull);
    expect(brutal.boxShadow, isNotEmpty);

    Neo.applyStyle(designStyleById('flat'));
    final flat = Neo.box();
    expect(flat.border, isNull);
    expect(flat.boxShadow, isNull);

    Neo.applyStyle(designStyleById('skeuo'));
    expect(Neo.box().gradient, isNotNull);

    Neo.applyStyle(designStyleById('neumorph'));
    expect(Neo.box().boxShadow, hasLength(2));

    Neo.applyStyle(designStyleById('glass'));
    final glass = Neo.box();
    expect(glass.border, isNotNull);
    expect(glass.color!.a, lessThan(1));
  });

  test('gradien latar hanya untuk gaya yang memintanya', () {
    const bg = Color(0xFFF6F5F1);
    const accent = Color(0xFFF2CE6B);
    expect(
      styleBackgroundGradient(designStyleById('glass'), bg, accent),
      isNotNull,
    );
    expect(
      styleBackgroundGradient(designStyleById('flat'), bg, accent),
      isNull,
    );
  });

  test('efek tekan mengikuti gaya', () {
    Neo.applyStyle(designStyleById('brutal'));
    expect(Neo.pressShadow(true, 4), lessThan(4));
    expect(Neo.pressOpacity(true), 1.0);

    Neo.applyStyle(designStyleById('minimal'));
    expect(Neo.pressOpacity(true), lessThan(1.0));
  });
}
