import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/tasks/screens/add_edit_task_screen.dart';
import '../features/tasks/screens/task_list_screen.dart';
import '../features/streaks/screens/streaks_screen.dart';
import '../features/focus/screens/focus_screen.dart';
import '../features/checklist/screens/checklist_screen.dart';
import '../features/birthdays/screens/birthdays_screen.dart';

class WidgetActionHandler {
  static const _channel = MethodChannel('pylo/focus');

  /// Checks for a pending widget action and returns the route to navigate to.
  /// Call this once at app startup.
  static Future<void> handlePendingAction(BuildContext context) async {
    if (kIsWeb) return;
    try {
      final result = await _channel.invokeMethod<Map>('getWidgetAction');
      if (result == null) return;

      final action = result['action'] as String?;
      if (action == null || action.isEmpty) return;

      // Clear the action so it doesn't fire again
      await _channel.invokeMethod('clearWidgetAction');

      // Wait for the first frame to render before navigating
      await Future.delayed(const Duration(milliseconds: 500));

      if (!context.mounted) return;

      switch (action) {
        case 'open_task':
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TaskListScreen()),
          );
          break;
        case 'open_habits':
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StreaksScreen()),
          );
          break;
        case 'open_dashboard':
          // Already on dashboard, or navigate to it
          break;
        case 'add_task':
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditTaskScreen()),
          );
          break;
        case 'open_focus':
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FocusScreen()),
          );
          break;
        case 'open_checklist':
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChecklistScreen()),
          );
          break;
        case 'open_birthdays':
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BirthdaysScreen()),
          );
          break;
      }
    } catch (e) {
      debugPrint('WidgetActionHandler failed: $e');
    }
  }
}
