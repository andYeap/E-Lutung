import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/neo_palette.dart';
import '../../theme/theme_controller.dart';
import '../../util/color.dart';
import '../../util/contrast.dart';
import '../../widgets/neo.dart';

/// Tema yang dapat disesuaikan (Bagian 6c, FR-11.6).
///
/// Preset dipakai sebagai titik awal, lalu tiap token bisa disetel sendiri.
/// Warna semantik tidak muncul di sini karena memang tidak dapat diubah.
class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key, this.controller});

  /// Injeksi untuk pengujian.
  final ThemeController? controller;

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  /// Mode mana yang sedang disunting warnanya.
  Brightness _edit = Brightness.light;

  ThemeController get _c => widget.controller ?? ThemeController.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final palette = _c.paletteFor(_edit);
        final warnings = paletteWarnings(palette);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tema & warna'),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(Neo.borderW),
              child: SizedBox(
                height: Neo.borderW,
                child: ColoredBox(color: Neo.ink),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const NeoSectionTitle('Mode tampilan'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ThemeMode.values
                    .map(
                      (m) => _chip(
                        themeModeLabel(m),
                        _c.mode == m,
                        () => _c.setMode(m),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              const NeoSectionTitle('Preset palet'),
              const SizedBox(height: 8),
              ...kThemePresets.map(_presetRow),
              const SizedBox(height: 20),
              const NeoSectionTitle('Warna'),
              const SizedBox(height: 4),
              Text(
                'Disunting terpisah untuk tiap mode.',
                style: TextStyle(color: Neo.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip(
                    'Warna terang',
                    _edit == Brightness.light,
                    () => setState(() => _edit = Brightness.light),
                  ),
                  const SizedBox(width: 8),
                  _chip(
                    'Warna gelap',
                    _edit == Brightness.dark,
                    () => setState(() => _edit = Brightness.dark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              NeoCard(
                child: Column(
                  children: [
                    for (final token in NeoToken.values)
                      _tokenRow(palette, token),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NeoButton(
                label: 'Kembalikan mode ini ke preset',
                icon: Icons.restart_alt,
                expand: true,
                onPressed: _c.isCustomized(_edit)
                    ? () => _c.resetBrightness(_edit)
                    : null,
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 20),
                NeoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, size: 18, color: Neo.expense),
                          const SizedBox(width: 8),
                          const Text(
                            'Perhatian',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...warnings.map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $w', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ini saran saja — pilihanmu tetap tersimpan.',
                        style: TextStyle(color: Neo.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
          ],
          ),
        );
      },
    );
  }

  Widget _presetRow(ThemePreset p) {
    final selected = p.id == _c.presetId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeoCard(
        onTap: () => _c.applyPreset(p.id),
        child: Row(
          children: [
            for (final c in [p.light.bg, p.light.accent, p.light.ink, p.dark.bg, p.dark.accent])
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: c,
                  border: Border.all(color: Neo.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            if (selected) const Icon(Icons.check, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _tokenRow(NeoPalette palette, NeoToken token) {
    final value = neoTokenValue(palette, token);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              neoTokenLabel(token),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Text(
            hexColor(value),
            style: TextStyle(color: Neo.muted, fontSize: 11),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _pick(token, value),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: value,
                border: Border.all(color: Neo.ink, width: Neo.borderW),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(NeoToken token, Color current) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _ColorDialog(initial: current),
    );
    if (picked != null) await _c.setToken(_edit, token, picked);
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: Neo.accent,
    backgroundColor: Neo.surface,
    side: BorderSide(color: Neo.ink, width: Neo.borderW),
    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
  );
}

/// Warna cepat: nada lembut, sesuai selera neobrutalism yang tidak menyilaukan.
const List<Color> _swatches = [
  Color(0xFFF6F5F1),
  Color(0xFFFCFCFA),
  Color(0xFFE8E4DA),
  Color(0xFFD8D3C4),
  Color(0xFFB4B2AA),
  Color(0xFF7C7B75),
  Color(0xFF5A574F),
  Color(0xFF3A3934),
  Color(0xFFF2CE6B),
  Color(0xFFE0B36B),
  Color(0xFFD98C7A),
  Color(0xFF8FB8DE),
  Color(0xFF7FA0CC),
  Color(0xFF5B6BB5),
  Color(0xFFB9A5D9),
  Color(0xFFA08CC0),
  Color(0xFF8FC7C0),
  Color(0xFF6FBFA8),
  Color(0xFF1E1F22),
  Color(0xFF2A2C30),
  Color(0xFF222B33),
  Color(0xFF1B1B1D),
];

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late final TextEditingController _hex = TextEditingController(
    text: hexColor(widget.initial),
  );
  late Color _value = widget.initial;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _dariTeks(String raw) {
    final parsed = tryParseHexColor(raw);
    if (parsed != null) setState(() => _value = parsed);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pilih warna'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 44, decoration: Neo.box(color: _value)),
          const SizedBox(height: 14),
          NeoTextField(
            controller: _hex,
            label: 'Kode hex',
            hint: '#RRGGBB',
            onChanged: _dariTeks,
          ),
          const SizedBox(height: 14),
          const Text(
            'Pilihan cepat',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _swatches
                .map(
                  (c) => GestureDetector(
                    onTap: () => setState(() {
                      _value = c;
                      _hex.text = hexColor(c);
                    }),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        border: Border.all(color: Neo.ink, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      NeoButton(
        label: 'Pakai',
        onPressed: () {
          final parsed = tryParseHexColor(_hex.text);
          if (parsed == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kode hex tidak sah, contoh yang benar: #8FB8DE'),
              ),
            );
            return;
          }
          Navigator.pop(context, parsed);
        },
      ),
    ],
  );
}
