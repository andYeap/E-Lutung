import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'data/database.dart';
import 'features/onboarding_screen.dart';
import 'services/recurring_runner.dart';
import 'services/widget_sync.dart';
import 'theme/theme_controller.dart';
import 'util/format.dart';

const _uniqueTaskName = 'elutung-widget-refresh';
const _taskName = 'elutungWidgetRefresh';

/// Dipanggil WorkManager di isolate terpisah (Bagian FR-9.5): menyegarkan data
/// widget, terutama saat pergantian hari/bulan tanpa aplikasi dibuka.
@pragma('vm:entry-point')
void widgetCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final db = AppDatabase();
    try {
      // Susulkan dulu transaksi berulang yang terlewat, supaya widget dan
      // rekap menampilkannya walau aplikasi tidak dibuka (FR-12.2).
      await RecurringRunner.runDue(db);
      await WidgetSync.push(db);
    } catch (_) {
      // abaikan — widget hanya data ringkasan
    } finally {
      await db.close();
    }
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ukur waktu sampai frame pertama (NFR performa) — terlihat di logcat.
  final startup = Stopwatch()..start();
  // Muat locale id_ID (DateFormat) sebelum widget dibangun.
  await ensureIntlLocale();

  // Gambar sampai tepi layar supaya status bar dan bilah navigasi bisa ikut
  // warna tema, bukan memakai latar jendela bawaan (yang tampak abu-abu di
  // layar tanpa AppBar, seperti onboarding).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  if (Platform.isAndroid) {
    try {
      await Workmanager().initialize(widgetCallbackDispatcher);
    } catch (e) {
      debugPrint('[Workmanager] initialize gagal: $e');
    }
  }

  // Baca tema & status onboarding tersimpan sebelum runApp (hindari kedip).
  await ThemeController.instance.load();
  await Onboarding.load();
  runApp(const ProviderScope(child: ElutungApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('[Startup] frame pertama dalam ${startup.elapsedMilliseconds} ms');
  });

  if (Platform.isAndroid) {
    try {
      await Workmanager().registerPeriodicTask(
        _uniqueTaskName,
        _taskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('[Workmanager] registerPeriodicTask gagal: $e');
    }
  }
}
