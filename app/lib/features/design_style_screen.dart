import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/design_style.dart';
import '../theme/neo_palette.dart';
import '../theme/theme_controller.dart';
import '../widgets/neo.dart';

/// Memilih gaya desain aplikasi (Flat, Material, Neobrutalism, Neomorphism,
/// Glass Morphism, Skeuomorphic, Minimalism).
///
/// Terpisah dari "Tema & warna" supaya warna dan bentuk tidak saling
/// mengganggu: layar ini hanya mengubah struktur, bukan palet.
class DesignStyleScreen extends StatefulWidget {
  const DesignStyleScreen({super.key, this.controller});

  /// Injeksi untuk pengujian.
  final ThemeController? controller;

  @override
  State<DesignStyleScreen> createState() => _DesignStyleScreenState();
}

class _DesignStyleScreenState extends State<DesignStyleScreen> {
  ThemeController get _c => widget.controller ?? ThemeController.instance;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final palette = _c.paletteFor(brightness);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Gaya desain'),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(Neo.borderW),
              child: SizedBox(
                height: Neo.borderW,
                child: ColoredBox(color: Neo.ink),
              ),
            ),
          ),
          // Ruang untuk bilah navigasi sistem; tanpa ini kartu terbawah tertutup.
          bottomNavigationBar: SizedBox(
            height: MediaQuery.viewPaddingOf(context).bottom,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Bentuk kartu, border, dan bayangan. Warna tidak ikut berubah — '
                'atur di "Tema & warna".',
                style: TextStyle(color: Neo.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final s in kDesignStyles) ...[
                _StyleTile(
                  style: s,
                  palette: palette,
                  selected: s.id == _c.styleId,
                  onTap: () => _c.setStyle(s.id),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.style,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final DesignStyle style;
  final NeoPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      onTap: onTap,
      child: Row(
        children: [
          _preview(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  style.description,
                  style: TextStyle(color: Neo.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check, size: 18),
        ],
      ),
    );
  }

  /// Pratinjau kecil yang dibentuk murni dari gaya ini, bukan dari gaya aktif.
  Widget _preview() => Container(
    width: 92,
    height: 60,
    padding: const EdgeInsets.all(8),
    decoration: styleDecoration(
      style: style,
      surface: palette.surface,
      ink: palette.ink,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 40,
          height: 7,
          decoration: styleDecoration(
            style: style,
            surface: palette.surface,
            ink: palette.ink,
            color: Color.alphaBlend(
              palette.ink.withValues(alpha: 0.25),
              palette.surface,
            ),
            shadowIntensity: 0,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 34,
            height: 16,
            decoration: styleDecoration(
              style: style,
              surface: palette.surface,
              ink: palette.ink,
              color: palette.accent,
              radius: style.buttonPill ? 999 : style.buttonRadius,
              shadowIntensity: 0,
            ),
          ),
        ),
      ],
    ),
  );
}
