import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../util/contrast.dart';

/// Kartu bergaya neobrutalism + efek "press" (Bagian 6b).
class NeoCard extends StatefulWidget {
  const NeoCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsets padding;

  @override
  State<NeoCard> createState() => _NeoCardState();
}

class _NeoCardState extends State<NeoCard> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(_down ? 2 : 0, _down ? 2 : 0, 0),
        padding: widget.padding,
        decoration: Neo.box(color: widget.color, shadow: _down ? 2 : 4),
        child: widget.child,
      ),
    );
  }
}

/// Tombol primer bergaya neobrutalism.
class NeoButton extends StatefulWidget {
  const NeoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Warna tombol; null berarti aksen tema aktif. Tidak boleh dijadikan nilai
  /// default parameter karena aksen kini ditentukan saat `build`.
  final Color? color;
  final bool expand;

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final background = enabled
        ? (widget.color ?? Neo.accent)
        : Color.alphaBlend(Neo.muted.withValues(alpha: 0.25), Neo.surface);
    // Teks tombol dipilih agar terbaca di atas latarnya. Sebelumnya selalu
    // memakai `Neo.ink`, yang di mode gelap menghasilkan teks terang di atas
    // aksen kuning terang — hanya berkontras 1.2:1.
    final foreground = readableOn(background);
    final btn = GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: Matrix4.translationValues(_down ? 2 : 0, _down ? 2 : 0, 0),
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: Neo.box(color: background, shadow: _down ? 2 : 4),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 18, color: foreground),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
    return btn;
  }
}

/// Input teks bergaya neobrutalism.
class NeoTextField extends StatelessWidget {
  const NeoTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.keyboardType,
    this.prefixText,
    this.inputFormatters,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            filled: true,
            fillColor: Neo.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Neo.radius),
              borderSide: BorderSide(color: Neo.ink, width: Neo.borderW),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Neo.radius),
              borderSide: BorderSide(color: Neo.ink, width: 3),
            ),
          ),
        ),
      ],
    );
  }
}

/// Keadaan memuat bergaya neobrutalism: blok warna keras, bukan shimmer
/// (Bagian 6b PRD).
class NeoLoading extends StatelessWidget {
  const NeoLoading({super.key, this.message = 'Memuat data…'});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _NeoBlock(widthFactor: 0.45, height: 18),
                  SizedBox(height: 10),
                  _NeoBlock(widthFactor: 1, height: 12),
                  SizedBox(height: 8),
                  _NeoBlock(widthFactor: 0.7, height: 12),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Neo.muted, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class _NeoBlock extends StatelessWidget {
  const _NeoBlock({required this.widthFactor, required this.height});
  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: Neo.bg,
        border: Border.all(color: Neo.ink, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

/// Keadaan gagal memuat, bergaya sama dengan kartu lain (Bagian 6b PRD).
class NeoError extends StatelessWidget {
  const NeoError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: NeoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Neo.muted, fontSize: 12),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              NeoButton(
                label: 'Coba lagi',
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Judul seksi.
class NeoSectionTitle extends StatelessWidget {
  const NeoSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
  );
}
