import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/preferences_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/notification_service.dart';
import '../../../core/utils/backup_helper_native.dart'
    if (dart.library.js) '../../../core/utils/backup_helper_web.dart' as backup_helper;

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
            title: const Text('Default reminders'),
            subtitle: Text(
              ref.watch(settingsPreferencesProvider).reminderMinutes.isEmpty
                  ? 'No default reminders'
                  : ref.watch(settingsPreferencesProvider).reminderMinutes
                      .map((m) => '$m min')
                      .join(', '),
            ),
            trailing: DropdownButton<String>(
              value: null,
              hint: const Text('Edit'),
              onChanged: (value) {
                if (value != null) {
                  final current = List<int>.from(
                      ref.read(settingsPreferencesProvider).reminderMinutes);
                  final mins = int.tryParse(value) ?? 0;
                  if (mins > 0 && !current.contains(mins)) {
                    current.add(mins);
                    current.sort();
                  } else if (mins > 0 && current.contains(mins)) {
                    current.remove(mins);
                  } else if (mins == 0) {
                    current.clear();
                  }
                  ref
                      .read(settingsPreferencesProvider.notifier)
                      .setReminderMinutes(current);
                }
              },
              items: const [
                DropdownMenuItem(value: '0', child: Text('Clear all')),
                DropdownMenuItem(value: '1', child: Text('1 min')),
                DropdownMenuItem(value: '5', child: Text('5 min')),
                DropdownMenuItem(value: '10', child: Text('10 min')),
                DropdownMenuItem(value: '15', child: Text('15 min')),
                DropdownMenuItem(value: '30', child: Text('30 min')),
                DropdownMenuItem(value: '60', child: Text('60 min')),
              ],
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily habit reminder'),
            subtitle: const Text('Get a nudge to complete your habits'),
            value:
                ref.watch(settingsPreferencesProvider).dailyReminderEnabled,
            onChanged: (value) async {
              if (value) {
                if (!kIsWeb) {
                  final ok = await NotificationService.scheduleDailyReminder(
                    hour: ref
                        .watch(settingsPreferencesProvider)
                        .dailyReminderHour,
                    minute: ref
                        .watch(settingsPreferencesProvider)
                        .dailyReminderMinute,
                  );
                  if (!ok) return;
                }
                await ref
                    .read(settingsPreferencesProvider.notifier)
                    .setDailyReminderEnabled(true);
              } else {
                if (!kIsWeb) {
                  await NotificationService.cancelDailyReminder();
                }
                await ref
                    .read(settingsPreferencesProvider.notifier)
                    .setDailyReminderEnabled(false);
              }
            },
          ),
          if (ref.watch(settingsPreferencesProvider).dailyReminderEnabled)
            ListTile(
              title: const Text('Reminder time'),
              subtitle: Text(
                '${ref.watch(settingsPreferencesProvider).dailyReminderHour.toString().padLeft(2, '0')}:${ref.watch(settingsPreferencesProvider).dailyReminderMinute.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: ref
                        .watch(settingsPreferencesProvider)
                        .dailyReminderHour,
                    minute: ref
                        .watch(settingsPreferencesProvider)
                        .dailyReminderMinute,
                  ),
                );
                if (picked != null) {
                  await ref
                      .read(settingsPreferencesProvider.notifier)
                      .setDailyReminderTime(picked.hour, picked.minute);
                  if (!kIsWeb) {
                    await NotificationService.scheduleDailyReminder(
                      hour: picked.hour,
                      minute: picked.minute,
                    );
                  }
                }
              },
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
                pinController.dispose();
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
                pinController.dispose();
              },
            ),
          ListTile(
            title: const Text('Backup Database'),
            subtitle: const Text('Save a copy of your local database'),
            onTap: () async {
              if (kIsWeb) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Backup is not available in the browser.')));
                return;
              }

              try {
                final result = await backup_helper.performBackup();
                if (result == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('No database exists yet.')));
                  return;
                }
                await Clipboard.setData(ClipboardData(text: result));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup saved to: $result')));
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
