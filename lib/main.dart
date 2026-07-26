import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'core/utils/notification_helper.dart';
import 'database/database_helper.dart';
import 'navigation/app_navigation.dart';
import 'providers/settings_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  try {
    await DatabaseHelper.instance.initDatabase();
  } catch (e, stackTrace) {
    debugPrint('Database init failed: $e\n$stackTrace');
  }

  if (!kIsWeb) {
    await NotificationHelper.init();
  }

  runApp(
    const ProviderScope(
      child: TaskFlowApp(),
    ),
  );
}

class TaskFlowApp extends ConsumerWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider);

    ThemeMode mode;

    switch (themeMode) {
      case AppThemeMode.dark:
        mode = ThemeMode.dark;
        break;

      case AppThemeMode.amoled:
        mode = ThemeMode.dark;
        break;

      case AppThemeMode.light:
      default:
        mode = ThemeMode.light;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaskFlow',
      theme: AppTheme.lightTheme,
      darkTheme: themeMode == AppThemeMode.amoled
          ? AppTheme.amoledTheme
          : AppTheme.darkTheme,
      themeMode: mode,
      home: const AppNavigation(),
    );
  }
}
