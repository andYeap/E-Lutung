import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/neo.dart';

/// Penanda onboarding sudah dilihat (Bagian 6b PRD) — disimpan lokal.
class Onboarding {
  Onboarding._();

  static const _key = 'onboarding_done';
  static bool _done = false;
  static bool get done => _done;

  /// Dipanggil di `main()` sebelum `runApp` supaya tidak ada kedip.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _done = prefs.getBool(_key) ?? false;
    } catch (_) {
      // Preferensi tak tersedia — tampilkan onboarding.
      _done = false;
    }
  }

  static Future<void> complete() async {
    _done = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {}
  }
}

/// Menampilkan onboarding sekali saja, lalu menyerahkan ke [child].
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late bool _show = !Onboarding.done;

  Future<void> _finish() async {
    await Onboarding.complete();
    if (mounted) setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return widget.child;
    return OnboardingScreen(onDone: _finish);
  }
}

/// 2–3 kartu singkat bergaya neobrutalism, bisa dilewati (Bagian 6b PRD).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <_OnboardPage>[
    _OnboardPage(
      icon: Icons.bolt,
      title: 'Catat dalam hitungan detik',
      body: 'Tekan tombol Tambah untuk mencatat pemasukan, pengeluaran, '
          'atau transfer. Nominal otomatis berformat ribuan.',
    ),
    _OnboardPage(
      icon: Icons.pie_chart,
      title: 'Tahu ke mana uang pergi',
      body: 'Rekap bulanan, donut persentase per kategori, dan batas '
          'anggaran yang berubah hijau → kuning → merah.',
    ),
    _OnboardPage(
      icon: Icons.widgets,
      title: 'Pantau dari beranda',
      body: 'Pasang widget untuk melihat aktivitas terbaru, total bulan ini, '
          'dan sisa anggaran tanpa membuka aplikasi.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: Text('Lewati', style: TextStyle(color: Neo.muted)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _card(_pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == _page ? Neo.accent : Neo.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: Neo.ink, width: Neo.borderW),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: NeoButton(
                label: last ? 'Mulai' : 'Lanjut',
                icon: last ? Icons.check : Icons.arrow_forward,
                expand: true,
                onPressed: () {
                  if (last) {
                    widget.onDone();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(_OnboardPage p) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: NeoCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(p.icon, size: 48),
            const SizedBox(height: 16),
            Text(
              p.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              p.body,
              textAlign: TextAlign.center,
              style: TextStyle(color: Neo.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OnboardPage {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}
