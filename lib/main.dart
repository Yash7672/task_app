import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'core/utils/notification_helper.dart';
import 'core/utils/startup_benchmark.dart';
import 'features/auth/screens/app_lock_screen.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  StartupBenchmark.reset();
  StartupBenchmark.mark('main_entered');

  // Initialize timezones synchronously — cheap, needed by notifications later.
  tz_data.initializeTimeZones();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    const ProviderScope(
      child: TaskFlowApp(),
    ),
  );

  StartupBenchmark.mark('run_app_called');
}

class TaskFlowApp extends ConsumerStatefulWidget {
  const TaskFlowApp({super.key});

  @override
  ConsumerState<TaskFlowApp> createState() => _TaskFlowAppState();
}

class _TaskFlowAppState extends ConsumerState<TaskFlowApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initBackgroundServices());
    });
  }

  Future<void> _initBackgroundServices() async {
    final sw = Stopwatch()..start();

    try {
      await ref.read(settingsProvider.notifier).ensureLoaded();
    } catch (e) {
      debugPrint('Settings load failed: $e');
    }
    StartupBenchmark.mark('preferences_loaded (${sw.elapsedMilliseconds}ms)');

    if (!kIsWeb) {
      sw.reset();
      // Initialize both notification services in parallel — independent work.
      await Future.wait([
        NotificationHelper.init().catchError((e) =>
            debugPrint('NotificationHelper init failed: $e')),
        NotificationService.initialize().catchError((e) =>
            debugPrint('NotificationService init failed: $e')),
      ]);
      StartupBenchmark
          .mark('notifications_initialized (${sw.elapsedMilliseconds}ms)');
    }

    if (kDebugMode) {
      debugPrint(StartupBenchmark.report());
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider);

    final ThemeMode mode = switch (themeMode) {
      AppThemeMode.dark || AppThemeMode.amoled => ThemeMode.dark,
      AppThemeMode.light => ThemeMode.light,
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PYLO',
      theme: AppTheme.lightTheme,
      darkTheme: themeMode == AppThemeMode.amoled
          ? AppTheme.amoledTheme
          : AppTheme.darkTheme,
      themeMode: mode,
      home: const AppLockGate(),
    );
  }
}
