import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/onboarding_screen.dart';
import 'features/shell.dart';
import 'services/app_lock.dart';
import 'theme/app_theme.dart';
import 'theme/neo_palette.dart';
import 'theme/theme_controller.dart';
import 'util/contrast.dart';

class ElutungApp extends StatefulWidget {
  const ElutungApp({super.key, this.themeController});

  /// Injeksi untuk pengujian.
  final ThemeController? themeController;

  @override
  State<ElutungApp> createState() => _ElutungAppState();
}

class _ElutungAppState extends State<ElutungApp> with WidgetsBindingObserver {
  late final ThemeController _ctl =
      widget.themeController ?? ThemeController.instance;

  @override
  void initState() {
    super.initState();
    // Ikut perubahan tema terang/gelap sistem selagi aplikasi hidup, supaya
    // token `Neo` tidak tertinggal dari kerangka Material.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() {});
  }

  Brightness get _brightness => switch (_ctl.mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctl,
      builder: (context, _) {
        // Token neobrutalism mengikuti tema aktif sebelum widget dibangun.
        final palet = _ctl.paletteFor(_brightness);
        Neo.apply(palet);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _sistemUi(palet),
          child: MaterialApp(
            title: 'E-Lutung',
            debugShowCheckedModeBanner: false,
            // Kedua tema dibangun dari paletnya masing-masing, bukan dari palet
            // global, supaya warna terang dan gelap tidak saling tertukar.
            theme: AppTheme.light(_ctl.paletteFor(Brightness.light)),
            darkTheme: AppTheme.dark(_ctl.paletteFor(Brightness.dark)),
            themeMode: _ctl.mode,
            // Material (date picker dll) memakai Bahasa Indonesia.
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('id'), Locale('en')],
            // Batasi pembesaran font (0.8x-1.4x) supaya layout tidak pecah
            // pada setelan aksesibilitas ekstrem (NFR aksesibilitas).
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(
                    minScaleFactor: 0.8,
                    maxScaleFactor: 1.4,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const AuthGate(child: OnboardingGate(child: ShellScreen())),
          ),
        );
      },
    );
  }

  /// Warna status bar dan bilah navigasi mengikuti palet aktif.
  ///
  /// Transparan supaya AppBar (atau latar layar bila tidak ada AppBar) yang
  /// tampak di belakangnya; kecerahan ikon dipilih dari kontras latarnya.
  SystemUiOverlayStyle _sistemUi(NeoPalette palet) {
    final ikonStatusTerang = readableOn(palet.appBar).computeLuminance() > 0.5;
    final ikonNavTerang = readableOn(palet.surface).computeLuminance() > 0.5;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: ikonStatusTerang
          ? Brightness.light
          : Brightness.dark,
      statusBarBrightness: ikonStatusTerang
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: palet.surface,
      systemNavigationBarIconBrightness: ikonNavTerang
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}
