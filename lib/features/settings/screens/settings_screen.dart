import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/backup_helper_native.dart'
    if (dart.library.js) '../../../core/utils/backup_helper_web.dart' as backup_helper;
import '../../../core/utils/notification_helper.dart';
import '../../../core/widgets/dialog_disposer.dart';
import '../../../models/birthday_model.dart';
import '../../../providers/birthday_provider.dart';
import '../../../providers/checklist_provider.dart';
import '../../../providers/focus_provider.dart';
import '../../../providers/preferences_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/security_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../services/backup/backup_service.dart';
import '../../../services/backup/restore_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/home_widget_service.dart';
import '../../../services/security/biometric_service.dart';
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
                  const _BiometricTile(),
                  const _FaceIdTile(),
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
                  onChanged: (value) async {
                    await ref
                        .read(settingsPreferencesProvider.notifier)
                        .setBirthdayRemindersEnabled(value);
                    if (value) {
                      // Birthdays added while reminders were off have no
                      // scheduled notifications — schedule them all now.
                      await ref
                          .read(birthdayProvider.notifier)
                          .rescheduleAllReminders();
                    } else if (!kIsWeb) {
                      final birthdays = ref.read(birthdayProvider).maybeWhen(
                          data: (list) => list, orElse: () => <Birthday>[]);
                      for (final b in birthdays) {
                        await NotificationHelper.cancelAllForBirthday(b.id);
                      }
                    }
                  },
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
                        if (!ok) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Could not schedule the reminder — notifications may be disabled.'),
                              backgroundColor: Colors.orange));
                          return;
                        }
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
                  title: const Text('Add "Today\'s Tasks" widget'),
                  subtitle:
                      const Text('Shows today\'s tasks with progress'),
                  leading: const Icon(Icons.widgets_outlined),
                  onTap: () async {
                    await HomeWidgetService.requestPinWidget();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'If nothing appeared, add it from your launcher\'s widget menu.')));
                  },
                ),
                ListTile(
                  title: const Text('Add "Habits" widget'),
                  subtitle:
                      const Text('Shows habit streaks and progress'),
                  leading: const Icon(Icons.local_fire_department_outlined),
                  onTap: () async {
                    await HomeWidgetService.requestPinHabitsWidget();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'If nothing appeared, add it from your launcher\'s widget menu.')));
                  },
                ),
                ListTile(
                  title: const Text('Add "Progress" widget'),
                  subtitle:
                      const Text('Shows today\'s completion progress'),
                  leading: const Icon(Icons.pie_chart_outline),
                  onTap: () async {
                    await HomeWidgetService.requestPinProgressWidget();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'If nothing appeared, add it from your launcher\'s widget menu.')));
                  },
                ),
                ListTile(
                  title: const Text('Add "Quick Add" widget'),
                  subtitle:
                      const Text('Tap to quickly add a new task'),
                  leading: const Icon(Icons.add_circle_outline),
                  onTap: () async {
                    await HomeWidgetService.requestPinQuickAddWidget();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'If nothing appeared, add it from your launcher\'s widget menu.')));
                  },
                ),
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
    final security = ref.read(securityProvider);
    if (enable) {
      // New PIN + confirmation — a typo here would permanently lock the
      // user out of their own data.
      String? newPin;
      while (true) {
        if (!context.mounted) return;
        final first = await _promptPin(context, 'Set a 4-digit PIN');
        if (first == null) return;
        if (!context.mounted) return;
        final confirm = await _promptPin(context, 'Confirm your PIN');
        if (confirm == null) return;
        if (confirm == first) {
          newPin = confirm;
          break;
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('PINs did not match. Try again.'),
            backgroundColor: Colors.orange));
      }
      await ref.read(securityProvider.notifier).enableAppLock(newPin);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App Lock enabled')));
      }
    } else {
      // Require the current PIN before the lock can be removed. Use strict
      // verification so broken secure storage offers recovery instead of an
      // endless 'incorrect PIN' loop.
      if (security.hasPin) {
        String? pin;
        while (true) {
          if (!context.mounted) return;
          pin = await _promptPin(context, 'Enter current PIN to disable');
          if (pin == null) return;
          final result = await ref
              .read(securityProvider.notifier)
              .verifyPinStrict(pin);
          if (result == 'ok') break;
          if (!context.mounted) return;
          if (result == 'error') {
            final recover = await _offerStorageRecovery(context);
            if (!context.mounted) return;
            if (recover != true) return;
            // Recovery accepted: skip the PIN check and remove the lock.
            break;
          }
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Current PIN was incorrect'),
              backgroundColor: Colors.red));
        }
      }
      await ref.read(securityProvider.notifier).disableAppLock();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App Lock disabled')));
      }
    }
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final security = ref.read(securityProvider);

    String? oldPin;
    if (security.hasPin) {
      // Ask for the current PIN, retrying until correct or cancelled.
      while (true) {
        if (!context.mounted) return;
        final entered = await _promptPin(context, 'Enter current PIN');
        if (entered == null) return;
        final result = await ref
            .read(securityProvider.notifier)
            .verifyPinStrict(entered);
        if (result == 'ok') {
          oldPin = entered;
          break;
        }
        if (!context.mounted) return;
        if (result == 'error') {
          // Secure storage is broken — offer recovery instead of an
          // endless 'incorrect PIN' loop.
          final recover = await _offerStorageRecovery(context);
          if (!context.mounted) return;
          if (recover != true) return;
          oldPin = null; // fall through to fresh-PIN setup below.
          break;
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Current PIN is incorrect. Try again.'),
            backgroundColor: Colors.red));
      }
    }

    if (!context.mounted) return;

    // New PIN + confirmation so a typo can never lock the user out.
    String? newPin;
    while (true) {
      if (!context.mounted) return;
      final first = await _promptPin(context, 'Enter new 4-digit PIN');
      if (first == null) return;
      if (oldPin != null && first == oldPin) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('New PIN must be different from the current one'),
              backgroundColor: Colors.orange));
        }
        continue;
      }
      if (!context.mounted) return;
      final confirm = await _promptPin(context, 'Confirm new PIN');
      if (confirm == null) return;
      if (confirm != first) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('PINs did not match. Try again.'),
              backgroundColor: Colors.orange));
        }
        continue;
      }
      newPin = confirm;
      break;
    }
    if (!context.mounted) return;

    final String result;
    if (oldPin == null) {
      // No stored PIN (recovery path) — just set a fresh one.
      await ref.read(securityProvider.notifier).enableAppLock(newPin);
      result = 'ok';
    } else {
      result =
          await ref.read(securityProvider.notifier).changePin(oldPin, newPin);
    }

    if (!context.mounted) return;
    switch (result) {
      case 'ok':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('PIN updated'),
            backgroundColor: Colors.green));
      case 'wrong_pin':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Current PIN was incorrect'),
            backgroundColor: Colors.red));
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update PIN — secure storage error'),
            backgroundColor: Colors.red));
    }
  }

  Future<bool> _offerStorageRecovery(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIN storage problem'),
        content: const Text(
            'The saved PIN could not be read from secure storage. '
            'You can set a new PIN now — it will replace the old one.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Set new PIN')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _promptPin(BuildContext context, String title) async {
    final controller = TextEditingController();
    var canSave = controller.text.length == 4;
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => DisposeOnExit(
        controllers: [controller],
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) =>
                setDialogState(() => canSave = controller.text.length == 4),
            decoration: InputDecoration(
              labelText: 'PIN',
              helperText: 'Enter 4 digits',
              errorText: controller.text.isEmpty
                  ? null
                  : (canSave ? null : 'PIN must be 4 digits'),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed:
                  canSave ? () => Navigator.pop(dialogContext, controller.text) : null,
              child: const Text('Save'),
            ),
          ],
          ),
        ),
      ),
    );
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
      // Reload every other provider backed by the restored DB/prefs so the
      // whole UI reflects the import immediately (not just after restart).
      ref.invalidate(checklistProvider);
      ref.invalidate(birthdayProvider);
      ref.invalidate(focusProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(settingsPreferencesProvider);
      // Security prefs (app lock, biometrics, timeout) and the theme are
      // backed by prefs too; reload without re-locking an unlocked session.
      await ref.read(securityProvider.notifier).reloadAfterRestore();
      await ref.read(settingsProvider.notifier).ensureLoaded();

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

/// Biometric unlock toggle. Re-checks device biometric availability when it
/// becomes visible (so enrolling face/fingerprint later works without an app
/// restart) and names the enrolled method in the subtitle.
class _BiometricTile extends ConsumerStatefulWidget {
  const _BiometricTile();

  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool _prefersFace = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(securityProvider.notifier).refreshBiometrics();
      final face =
          await ref.read(securityProvider.notifier).prefersFaceBiometric();
      if (mounted) setState(() => _prefersFace = face);
    });
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    return SwitchListTile.adaptive(
      title: const Text('Biometric Unlock'),
      subtitle: Text(security.biometricAvailable
          ? (_prefersFace && !security.faceIdEnabled
              ? 'Use face recognition to unlock'
              : 'Use fingerprint or face to unlock')
          : 'No biometrics enrolled on this device'),
      value: security.biometricEnabled && security.biometricAvailable,
      onChanged: security.biometricAvailable
          ? (value) async {
              await ref
                  .read(securityProvider.notifier)
                  .setBiometricEnabled(value);
            }
          : null,
    );
  }
}

/// Face ID unlock toggle shown below Biometric Unlock. Only interactive
/// when a face biometric is enrolled on the device; enabling runs one
/// verification scan so Face ID can't be turned on without proving it's
/// really you.
class _FaceIdTile extends ConsumerStatefulWidget {
  const _FaceIdTile();

  @override
  ConsumerState<_FaceIdTile> createState() => _FaceIdTileState();
}

class _FaceIdTileState extends ConsumerState<_FaceIdTile> {
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(securityProvider.notifier).refreshBiometrics();
    });
  }

  Future<void> _onToggle(bool enable) async {
    final notifier = ref.read(securityProvider.notifier);
    if (!enable) {
      await notifier.setFaceIdEnabled(false);
      return;
    }
    // Prove identity once before trusting Face ID for future unlocks.
    setState(() => _verifying = true);
    final ok = await BiometricService.authenticate(
      reason: 'Confirm your face to enable Face ID unlock',
    );
    if (!mounted) return;
    setState(() => _verifying = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Face not verified — Face ID stayed off'),
          backgroundColor: Colors.orange));
      return;
    }
    await notifier.setFaceIdEnabled(true);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Face ID enabled')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    return SwitchListTile.adaptive(
      title: const Text('Face ID'),
      subtitle: Text(_verifying
          ? 'Verifying your face…'
          : security.faceIdAvailable
              ? 'Use face recognition to unlock PYLO'
              : 'No face recognition enrolled on this device'),
      value: security.faceIdEnabled && security.faceIdAvailable,
      onChanged: (!_verifying && security.faceIdAvailable) ? _onToggle : null,
    );
  }
}
