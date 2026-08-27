import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/calendar/screens/calendar_screen.dart';
import '../features/checklist/screens/checklist_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/more/screens/more_screen.dart';
import '../features/streaks/screens/streaks_screen.dart';
import '../features/tasks/screens/task_list_screen.dart';
import '../providers/focus_provider.dart';

class AppNavigation extends ConsumerStatefulWidget {
  const AppNavigation({super.key});

  @override
  ConsumerState<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends ConsumerState<AppNavigation> {
  int _currentIndex = 0;

  /// IndexedStack keeps all visited screens alive so switching tabs doesn't
  /// rebuild screens from scratch — preserving scroll position, loaded data,
  /// and avoiding duplicate provider watches.
  late final List<Widget> _screens = [
    const DashboardScreen(),
    const TaskListScreen(),
    const CalendarScreen(),
    const StreaksScreen(),
    const ChecklistScreen(),
    const MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final focus = ref.watch(focusProvider);
    final hasActiveFocus = focus.active != null;

    if (hasActiveFocus) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Tasks'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar'),
          NavigationDestination(
              icon: Icon(Icons.local_fire_department_outlined),
              selectedIcon: Icon(Icons.local_fire_department),
              label: 'Habits'),
          NavigationDestination(
              icon: Icon(Icons.checklist_rounded),
              selectedIcon: Icon(Icons.checklist),
              label: 'Lists'),
          NavigationDestination(
              icon: Icon(Icons.apps_outlined),
              selectedIcon: Icon(Icons.apps),
              label: 'More'),
        ],
      ),
    );
  }
}
