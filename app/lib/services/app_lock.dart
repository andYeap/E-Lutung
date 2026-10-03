import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci aplikasi dengan PIN/biometrik perangkat (Bagian FR-11.3).
/// Default nonaktif; dapat dinyalakan di Pengaturan.
class AppLock extends ChangeNotifier {
  AppLock._();
  static final AppLock instance = AppLock._();

  static const _key = 'app_lock_enabled';
  final LocalAuthentication _auth = LocalAuthentication();

  bool _enabled = false;
  bool get enabled => _enabled;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_key) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Buka E-Lutung',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }
}

/// Gerbang yang meminta autentikasi saat aplikasi dibuka/dilanjutkan
/// (jika kunci aktif).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AppLock.instance.enabled) return;
    if (state == AppLifecycleState.paused) {
      if (mounted) setState(() => _unlocked = false);
    } else if (state == AppLifecycleState.resumed && !_unlocked) {
      _tryUnlock();
    }
  }

  Future<void> _tryUnlock() async {
    if (!AppLock.instance.enabled) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }
    if (_busy) return;
    _busy = true;
    final ok = await AppLock.instance.authenticate();
    _busy = false;
    if (mounted) setState(() => _unlocked = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (!AppLock.instance.enabled || _unlocked) return widget.child;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 44),
              const SizedBox(height: 12),
              const Text(
                'E-Lutung terkunci',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Buka dengan PIN/biometrik perangkat.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _tryUnlock,
                icon: const Icon(Icons.lock_open, size: 18),
                label: const Text('Buka'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
