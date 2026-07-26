import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../providers/preferences_provider.dart';
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
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notifications'),
            subtitle: const Text('Enable local reminder support'),
            value: ref.watch(settingsPreferencesProvider).notificationsEnabled,
            onChanged: (value) => ref
                .read(settingsPreferencesProvider.notifier)
                .setNotificationsEnabled(value),
          ),
          ListTile(
            title: const Text('Reminder default'),
            subtitle: Text(
              ref.watch(settingsPreferencesProvider).reminderMinutesBefore == 0
                  ? 'No default reminder'
                  : '${ref.watch(settingsPreferencesProvider).reminderMinutesBefore} minutes before',
            ),
            trailing: DropdownButton<int>(
              value:
                  ref.watch(settingsPreferencesProvider).reminderMinutesBefore,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsPreferencesProvider.notifier)
                      .setReminderMinutesBefore(value);
                }
              },
              items: const [0, 5, 10, 15, 30, 60]
                  .map((minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text(
                            minutes == 0 ? 'None' : '$minutes mins before'),
                      ))
                  .toList(),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('App Lock'),
            subtitle: const Text('Keep the app protected with a PIN'),
            value: ref.watch(settingsPreferencesProvider).appLockEnabled,
            onChanged: (value) async {
              if (value) {
                final pinController = TextEditingController();
                final newPin = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Set a PIN'),
                    content: TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: '4-digit PIN'),
                      obscureText: true,
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () {
                          if (pinController.text.length == 4) {
                            Navigator.pop(context, pinController.text);
                          }
                        },
                        child: const Text('Save PIN'),
                      ),
                    ],
                  ),
                );

                if (newPin != null) {
                  await ref
                      .read(settingsPreferencesProvider.notifier)
                      .setAppLockPin(newPin);
                  await ref
                      .read(settingsPreferencesProvider.notifier)
                      .setAppLockEnabled(true);
                }
              } else {
                await ref
                    .read(settingsPreferencesProvider.notifier)
                    .setAppLockEnabled(false);
              }
            },
          ),
          if (ref.watch(settingsPreferencesProvider).appLockEnabled)
            ListTile(
              title: const Text('Change PIN'),
              subtitle: const Text('Update your app lock PIN'),
              onTap: () async {
                final pinController = TextEditingController();
                final newPin = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Change PIN'),
                    content: TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'New 4-digit PIN'),
                      obscureText: true,
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () {
                          if (pinController.text.length == 4) {
                            Navigator.pop(context, pinController.text);
                          }
                        },
                        child: const Text('Save PIN'),
                      ),
                    ],
                  ),
                );
                if (newPin != null) {
                  await ref
                      .read(settingsPreferencesProvider.notifier)
                      .setAppLockPin(newPin);
                }
              },
            ),
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
        ],
      ),
    );
  }
}
