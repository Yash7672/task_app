import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/habit_model.dart';
import '../../../providers/task_provider.dart';

class HabitDetailPopup extends ConsumerStatefulWidget {
  final Habit habit;

  const HabitDetailPopup({
    super.key,
    required this.habit,
  });

  @override
  ConsumerState createState() => _HabitDetailPopupState();
}

class _HabitDetailPopupState extends ConsumerState<HabitDetailPopup> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _logs = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await ref.read(habitLogsProvider(widget.habit.id).future);
      if (!mounted) return;
      _groupLogsByDate(logs);
    } catch (e) {
      debugPrint('Error loading logs: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _groupLogsByDate(List<Map<String, dynamic>> logs) {
    _logs = {};
    for (var log in logs) {
      final dateStr = log['date'] as String;
      final date = DateTime.parse(dateStr);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (!_logs.containsKey(dateOnly)) {
        _logs[dateOnly] = [];
      }
      _logs[dateOnly]!.add(log);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.habit.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.habit.description.isNotEmpty)
                        Text(
                          widget.habit.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    '🔥 Current',
                    '${widget.habit.currentStreak}',
                    Colors.orange,
                  ),
                  _buildStatItem(
                    '⭐ Best',
                    '${widget.habit.bestStreak}',
                    Colors.amber,
                  ),
                  _buildStatItem(
                    '📊 Total',
                    '${_logs.values.length}',
                    Colors.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime.now(),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) {
                  return _selectedDay != null &&
                      day.year == _selectedDay!.year &&
                      day.month == _selectedDay!.month &&
                      day.day == _selectedDay!.day;
                },
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 1,
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, date, _) {
                    return _buildCalendarDay(date);
                  },
                  todayBuilder: (context, date, _) {
                    return _buildCalendarDay(date, isToday: true);
                  },
                  selectedBuilder: (context, date, _) {
                    return _buildCalendarDay(date, isSelected: true);
                  },
                ),
              ),
            const SizedBox(height: 16),
            if (_selectedDay != null && _logs.containsKey(_selectedDay!))
              _buildDayDetails(_selectedDay!),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDay(DateTime date,
      {bool isToday = false, bool isSelected = false}) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final hasLogs = _logs.containsKey(dateOnly);
    final logCount = hasLogs ? _logs[dateOnly]!.length : 0;

    final isFuture = date.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? Colors.blue
            : isToday
                ? Colors.blue.shade100
                : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : isFuture
                        ? Colors.grey[400]
                        : Colors.black87,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (hasLogs && !isFuture)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: logCount > 1 ? Colors.orange : Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: logCount > 1
                    ? Text(
                        '🔥$logCount',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '🔥',
                        style: TextStyle(
                          fontSize: 10,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayDetails(DateTime date) {
    final logs = _logs[date]!;
    final formattedDate = '${date.day}/${date.month}/${date.year}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 $formattedDate',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Completed ${logs.length} time${logs.length > 1 ? 's' : ''}'),
          if (logs.length > 1)
            Row(
              children: [
                const Text('🔥'),
                const SizedBox(width: 4),
                Text(
                  '× ${logs.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
