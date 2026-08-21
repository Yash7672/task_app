import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'core/utils/notification_helper.dart';
import 'core/utils/startup_benchmark.dart';
import 'database/database_helper.dart';
import 'features/auth/screens/app_lock_screen.dart';
import 'providers/settings_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  StartupBenchmark.reset();
  StartupBenchmark.mark('main_entered');

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
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

    sw.reset();
    try {
      await DatabaseHelper.instance.initDatabase();
    } catch (e, stackTrace) {
      debugPrint('Database init failed: $e\n$stackTrace');
    }
    StartupBenchmark.mark('database_initialized (${sw.elapsedMilliseconds}ms)');

    if (!kIsWeb) {
      sw.reset();
      try {
        await NotificationHelper.init();
      } catch (e) {
        debugPrint('Notification init failed: $e');
      }
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
