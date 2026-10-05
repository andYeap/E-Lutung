import 'package:elutung/features/design_style_screen.dart';
import 'package:elutung/theme/design_style.dart';
import 'package:elutung/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layar khusus pemilih gaya desain.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ThemeController> pasang(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final c = ThemeController();
    await tester.pumpWidget(
      MaterialApp(home: DesignStyleScreen(controller: c)),
    );
    await tester.pump();
    return c;
  }

  testWidgets('menampilkan semua gaya', (tester) async {
    await pasang(tester);
    for (final s in kDesignStyles) {
      expect(find.text(s.name), findsOneWidget);
    }
  });

  testWidgets('memilih gaya mengubah controller', (tester) async {
    final c = await pasang(tester);

    await tester.ensureVisible(find.text('Glass Morphism'));
    await tester.tap(find.text('Glass Morphism'));
    await tester.pump();

    expect(c.styleId, 'glass');
  });
}
