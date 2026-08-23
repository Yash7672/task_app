import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/dialog_disposer.dart';

import '../../../models/birthday_model.dart';
import '../../../providers/birthday_provider.dart';
import '../../../providers/preferences_provider.dart';
import '../widgets/birthday_card.dart';

class BirthdaysScreen extends ConsumerWidget {
  const BirthdaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(birthdayProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('🎂 Birthdays')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'birthdays_fab',
        onPressed: () => _showBirthdayDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Birthday'),
      ),
      body: state.when(
        data: (birthdays) {
          if (birthdays.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.pink.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cake_rounded,
                          size: 48, color: Colors.pink),
                    ),
                    const SizedBox(height: 20),
                    Text('No birthdays yet',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Add birthdays once — PYLO reminds you every year.',
                      textAlign: TextAlign.center,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            itemCount: birthdays.length,
            itemBuilder: (context, index) => BirthdayCard(
              birthday: birthdays[index],
              onEdit: () => _showBirthdayDialog(context, ref,
                  birthday: birthdays[index]),
              onDelete: () => _confirmDelete(context, ref, birthdays[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _showBirthdayDialog(BuildContext context, WidgetRef ref,
      {Birthday? birthday}) async {
    final nameController = TextEditingController(text: birthday?.name ?? '');
    final phoneController = TextEditingController(text: birthday?.phone ?? '');
    final notesController = TextEditingController(text: birthday?.notes ?? '');
    DateTime selectedDate =
        birthday?.birthDate ?? DateTime(2000, 1, 1);
    List<int> selectedReminders =
        birthday != null ? List.from(birthday.reminderDaysBefore) : [0];
    final notificationsEnabled =
        ref.read(settingsPreferencesProvider).birthdayRemindersEnabled;

    final result = await showDialog<Birthday>(
      context: context,
      builder: (dialogContext) => DisposeOnExit(
        controllers: [nameController, phoneController, notesController],
        child: StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(birthday == null ? 'Add Birthday' : 'Edit Birthday'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake_outlined),
                  title: const Text('Date'),
                  subtitle: Text(
                      '${selectedDate.day} ${_monthName(selectedDate.month)}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      prefixIcon: Icon(Icons.phone_outlined)),
                ),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Remind me',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Wrap(
                  spacing: 6,
                  children: [0, 1, 3, 7].map((days) {
                    final selected = selectedReminders.contains(days);
                    return FilterChip(
                      label: Text(switch (days) {
                        0 => 'On day',
                        1 => '1 day before',
                        3 => '3 days',
                        _ => '7 days',
                      }),
                      selected: selected,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            selectedReminders.add(days);
                          } else {
                            selectedReminders.remove(days);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  Birthday(
                    id: birthday?.id,
                    name: nameController.text.trim(),
                    birthDate: selectedDate,
                    phone: phoneController.text.trim(),
                    notes: notesController.text.trim(),
                    reminderDaysBefore: selectedReminders.isEmpty
                        ? [0]
                        : selectedReminders..sort(),
                    createdAt: birthday?.createdAt,
                  ),
                );
              },
              child: Text(birthday == null ? 'Add' : 'Save'),
            ),
          ],
        ),
        ),
      ),
    );

    if (result == null) return;
    final notifier = ref.read(birthdayProvider.notifier);
    if (birthday == null) {
      await notifier.addBirthday(result,
          notificationsEnabled: notificationsEnabled);
    } else {
      await notifier.updateBirthday(result,
          notificationsEnabled: notificationsEnabled);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Birthday birthday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete birthday?'),
        content: Text('Remove ${birthday.name} from your reminders?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(birthdayProvider.notifier).deleteBirthday(birthday.id);
    }
  }

  String _monthName(int month) => switch (month) {
        1 => 'Jan', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr',
        5 => 'May', 6 => 'Jun', 7 => 'Jul', 8 => 'Aug',
        9 => 'Sep', 10 => 'Oct', 11 => 'Nov', _ => 'Dec',
      };
}
