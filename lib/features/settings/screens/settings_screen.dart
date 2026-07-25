import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Theme'),
            subtitle: const Text('Choose a local theme for the app'),
            trailing: DropdownButton<AppThemeMode>(
              value: themeMode,
              onChanged: (value) async {
                if (value != null) {
                  await ref.read(settingsProvider.notifier).setTheme(value);
                }
              },
              items: const [
                DropdownMenuItem(
                    value: AppThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: AppThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(
                    value: AppThemeMode.amoled, child: Text('AMOLED')),
              ],
            ),
          ),
          const ListTile(
              title: Text('Notifications'),
              subtitle: Text('Local reminders are enabled offline')),
          ListTile(
            title: const Text('Backup Database'),
            subtitle:
                const Text('Copy your local SQLite database path for backup'),
            onTap: () async {
              if (kIsWeb) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Backup is not available in the browser.')));
                return;
              }

              try {
                final appDir = await getApplicationDocumentsDirectory();
                final source = File(p.join(appDir.path, 'taskflow.db'));
                if (!await source.exists()) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No database exists yet.')));
                  return;
                }
                await Clipboard.setData(ClipboardData(text: source.path));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Database path copied to clipboard.')));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Backup failed: $e')));
              }
            },
          ),
          const ListTile(
              title: Text('App Lock'),
              subtitle: Text('PIN and biometric support can be added next')),
        ],
      ),
    );
  }
}
