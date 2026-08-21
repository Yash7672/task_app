import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/backup_helper_native.dart'
    if (dart.library.js) '../../../core/utils/backup_helper_web.dart' as backup_helper;
import '../../../providers/preferences_provider.dart';
import '../../../providers/security_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../services/backup/backup_service.dart';
import '../../../services/backup/restore_service.dart';
import '../../../services/notification_service.dart';
import '../../categories/screens/manage_categories_screen.dart';
import '../../profile/screens/profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider);
    final prefs = ref.watch(settingsPreferencesProvider);
    final security = ref.watch(securityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(context, 'Appearance'),
          Card(
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
          ),

          _sectionHeader(context, 'Security'),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('App Lock'),
                  subtitle: Text(security.appLockEnabled
                      ? 'PYLO is protected with a PIN'
                      : 'Keep the app protected with a PIN'),
                  value: security.appLockEnabled,
                  onChanged: (value) => _toggleAppLock(context, ref, value),
                ),
                if (security.appLockEnabled) ...[
                  SwitchListTile.adaptive(
                    title: const Text('Biometric Unlock'),
                    subtitle: Text(security.biometricAvailable
                        ? 'Use fingerprint or face to unlock'
                        : 'No biometrics available on this device'),
                    value: security.biometricEnabled &&
                        security.biometricAvailable,
                    onChanged: security.biometricAvailable
                        ? (value) => ref
                            .read(securityProvider.notifier)
                            .setBiometricEnabled(value)
                        : null,
                  ),
                  ListTile(
                    title: const Text('Change PIN'),
                    subtitle: const Text('Update your app lock PIN'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _changePin(context, ref),
                  ),
                  ListTile(
                    title: const Text('Lock when'),
                    subtitle: Text(security.lockTimeout.label),
                    trailing: DropdownButton<LockTimeout>(
                      value: security.lockTimeout,
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(securityProvider.notifier)
                              .setLockTimeout(value);
                        }
                      },
                      items: LockTimeout.values
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.label)))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          _sectionHeader(context, 'Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Task reminders'),
                  subtitle: const Text('Enable local reminder support'),
                  value: prefs.notificationsEnabled,
                  onChanged: (value) => ref
                      .read(settingsPreferencesProvider.notifier)
                      .setNotificationsEnabled(value),
                ),
                SwitchListTile.adaptive(
                  title: const Text('Birthday reminders'),
                  subtitle: const Text('Yearly birthday notifications'),
                  value: prefs.birthdayRemindersEnabled,
                  onChanged: (value) => ref
                      .read(settingsPreferencesProvider.notifier)
                      .setBirthdayRemindersEnabled(value),
                ),
                ListTile(
                  title: const Text('Default reminders'),
                  subtitle: Text(
                    prefs.reminderMinutes.isEmpty
                        ? 'No default reminders'
                        : prefs.reminderMinutes
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
                  title: const Text('Daily habit reminder'),
                  subtitle:
                      const Text('Get a nudge to complete your habits'),
                  value: prefs.dailyReminderEnabled,
                  onChanged: (value) async {
                    if (value) {
                      if (!kIsWeb) {
                        final ok = await NotificationService.scheduleDailyReminder(
                          hour: prefs.dailyReminderHour,
                          minute: prefs.dailyReminderMinute,
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
                if (prefs.dailyReminderEnabled)
                  ListTile(
                    title: const Text('Reminder time'),
                    subtitle: Text(
                        '${prefs.dailyReminderHour.toString().padLeft(2, '0')}:${prefs.dailyReminderMinute.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: prefs.dailyReminderHour,
                          minute: prefs.dailyReminderMinute,
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
              ],
            ),
          ),

          _sectionHeader(context, 'Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Export Backup'),
                  subtitle: const Text('Save a .pylobackup file anywhere you choose'),
                  leading: const Icon(Icons.backup_outlined),
                  onTap: () => _exportBackup(context, ref),
                ),
                ListTile(
                  title: const Text('Import Backup'),
                  subtitle: const Text('Restore from a PYLO backup file'),
                  leading: const Icon(Icons.restore_outlined),
                  onTap: () => _importBackup(context, ref),
                ),
                ListTile(
                  title: const Text('Export JSON'),
                  subtitle: const Text('Portable format for the long term'),
                  leading: const Icon(Icons.data_object_outlined),
                  onTap: () => _exportJson(context, ref),
                ),
                ListTile(
                  title: const Text('Legacy DB copy'),
                  subtitle: const Text('Quick copy of the SQLite database'),
                  leading: const Icon(Icons.copy_all_outlined),
                  onTap: () => _legacyBackup(context),
                ),
              ],
            ),
          ),

          _sectionHeader(context, 'Categories & Profile'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Manage Categories'),
                  subtitle: const Text('Add, rename or remove categories'),
                  leading: const Icon(Icons.category_outlined),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ManageCategoriesScreen())),
                ),
                ListTile(
                  title: const Text('Profile'),
                  subtitle: const Text('Your name, email and bio'),
                  leading: const Icon(Icons.person_outline),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen())),
                ),
              ],
            ),
          ),

          _sectionHeader(context, 'About'),
          Card(
            child: ListTile(
              title: const Text('PYLO'),
              subtitle: const Text(
                  'Offline • Local • Private • Fast\nv2.0.0 — your data never leaves your device.'),
              leading: ClipOval(
                child: Image.asset('assets/logo.png',
                    width: 40, height: 40, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[600])),
    );
  }

  Future<void> _toggleAppLock(
      BuildContext context, WidgetRef ref, bool enable) async {
    if (enable) {
      final pin = await _promptPin(context, 'Set a 4-digit PIN');
      if (pin == null) return;
      await ref.read(securityProvider.notifier).enableAppLock(pin);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App Lock enabled')));
      }
    } else {
      await ref.read(securityProvider.notifier).disableAppLock();
    }
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final oldPin = await _promptPin(context, 'Enter current PIN');
    if (oldPin == null || !context.mounted) return;
    final newPin = await _promptPin(context, 'Enter new 4-digit PIN');
    if (newPin == null) return;

    final ok =
        await ref.read(securityProvider.notifier).changePin(oldPin, newPin);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'PIN updated' : 'Current PIN was incorrect')));
    }
  }

  Future<String?> _promptPin(BuildContext context, String title) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.length == 4) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return pin;
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await BackupService.exportBackup();
      if (!context.mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export cancelled.')));
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: result.path));
      messenger.showSnackBar(SnackBar(
          content:
              Text('Backup saved (${result.itemCount} records):\n${result.path}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    try {
      final result = await BackupService.exportJson();
      if (!context.mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export cancelled.')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('JSON exported (${result.itemCount} records)')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text(
            'This will REPLACE all current tasks, habits, birthdays, checklists and focus history with the backup contents.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final result = await RestoreService.restore(ref);
      if (!context.mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import cancelled.')));
        return;
      }

      await ref.read(taskProvider.notifier).loadTasks();
      await ref.read(categoriesProvider.notifier).loadCategories();
      await ref.read(habitsProvider.notifier).loadHabits();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Restored ${result.itemCount} records. All your data is back!')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _legacyBackup(BuildContext context) async {
    if (kIsWeb) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Backup is not available in the browser.')));
      return;
    }
    try {
      final file = await backup_helper.performBackup();
      if (!context.mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No database exists yet.')));
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: file));
      messenger.showSnackBar(
          SnackBar(content: Text('DB copied to: $file')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }
}
