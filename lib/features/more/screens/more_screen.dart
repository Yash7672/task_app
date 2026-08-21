import 'package:flutter/material.dart';
import '../../birthdays/screens/birthdays_screen.dart';
import '../../checklist/screens/checklist_screen.dart';
import '../../focus/screens/focus_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../stats/screens/stats_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MoreTile(
            icon: Icons.checklist_rounded,
            color: Colors.teal,
            title: 'Checklists',
            subtitle: 'Simple lists like shopping',
            onTap: () => _push(context, const ChecklistScreen()),
          ),
          _MoreTile(
            icon: Icons.cake_rounded,
            color: Colors.pink,
            title: 'Birthdays',
            subtitle: 'Never forget a birthday',
            onTap: () => _push(context, const BirthdaysScreen()),
          ),
          _MoreTile(
            icon: Icons.timer_outlined,
            color: Colors.deepPurple,
            title: 'Focus Mode',
            subtitle: 'Deep work sessions with a timer',
            onTap: () => _push(context, const FocusScreen()),
          ),
          _MoreTile(
            icon: Icons.bar_chart_rounded,
            color: Colors.blue,
            title: 'Stats',
            subtitle: 'Your productivity overview',
            onTap: () => _push(context, const StatsScreen()),
          ),
          _MoreTile(
            icon: Icons.person_outline_rounded,
            color: Colors.orange,
            title: 'Profile',
            subtitle: 'Your details',
            onTap: () => _push(context, const ProfileScreen()),
          ),
          _MoreTile(
            icon: Icons.settings_outlined,
            color: Colors.grey,
            title: 'Settings',
            subtitle: 'Theme, security, backup and more',
            onTap: () => _push(context, const SettingsScreen()),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
