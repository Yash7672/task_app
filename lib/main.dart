import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'core/utils/notification_helper.dart';
import 'database/database_helper.dart';
import 'features/auth/screens/app_lock_screen.dart';
import 'providers/settings_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(
    const ProviderScope(
      child: TaskFlowApp(),
    ),
  );

  _initBackgroundServices();
}

Future<void> _initBackgroundServices() async {
  try {
    await DatabaseHelper.instance.initDatabase();
  } catch (e, stackTrace) {
    debugPrint('Database init failed: $e\n$stackTrace');
  }

  if (!kIsWeb) {
    try {
      await NotificationHelper.init();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }
}

class TaskFlowApp extends ConsumerWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
