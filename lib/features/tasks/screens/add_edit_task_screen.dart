import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/notification_helper.dart';
import '../../../models/task_model.dart';
import '../../../providers/preferences_provider.dart';
import '../../../providers/task_provider.dart';

class AddEditTaskScreen extends ConsumerStatefulWidget {
  final Task? taskToEdit;

  const AddEditTaskScreen({super.key, this.taskToEdit});

  @override
  ConsumerState<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends ConsumerState<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _notesController;
  late TextEditingController _durationController;
  late TextEditingController _checklistController;

  String _selectedCategory = 'Personal';
  String _selectedPriority = 'Medium';
  String _repeatRule = 'Never';
  DateTime _dueDate = DateTime.now();
  DateTime? _startTime;
  DateTime? _endTime;
  List<int> _selectedReminders = [];
  List<String> _checklist = [];

  final List<String> _categories = [
    'Personal',
    'College',
    'Study',
    'Gym',
    'Shopping',
    'Work',
    'Health',
    'Finance',
    'Family',
    'Travel'
  ];

  final List<String> _priorities = [
    'Critical',
    'High',
    'Medium',
    'Low',
    'No Priority'
  ];
  final List<String> _repeatRules = [
    'Never',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly'
  ];
  final List<int> _reminderOptions = [1, 5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.taskToEdit?.title ?? '');
    _descController =
        TextEditingController(text: widget.taskToEdit?.description ?? '');
    _notesController =
        TextEditingController(text: widget.taskToEdit?.notes ?? '');
    _durationController =
        TextEditingController(text: widget.taskToEdit?.estimatedDuration ?? '');
    _checklistController = TextEditingController();
    if (widget.taskToEdit != null) {
      _selectedCategory = widget.taskToEdit!.category;
      _selectedPriority = widget.taskToEdit!.priority;
      _repeatRule = widget.taskToEdit!.repeatRule;
      _dueDate = widget.taskToEdit!.dueDate;
      _startTime = widget.taskToEdit!.startTime;
      _endTime = widget.taskToEdit!.endTime;
      _selectedReminders = List<int>.from(widget.taskToEdit!.reminderMinutes);
      _checklist = List<String>.from(widget.taskToEdit!.checklist);
    } else {
      _selectedReminders = List<int>.from(
          ref.read(settingsPreferencesProvider).reminderMinutes);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    _checklistController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = TimeOfDay.fromDateTime(isStart
        ? (_startTime ?? DateTime.now())
        : (_endTime ?? DateTime.now()));
    final picked =
        await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null && mounted) {
      final dateTime = DateTime(_dueDate.year, _dueDate.month, _dueDate.day,
          picked.hour, picked.minute);
      setState(() {
        if (isStart) {
          _startTime = dateTime;
        } else {
          _endTime = dateTime;
        }
      });
    }
  }

  void _addChecklistItem() {
    final item = _checklistController.text.trim();
    if (item.isEmpty) return;
    setState(() {
      _checklist.add(item);
      _checklistController.clear();
    });
  }

  Future<void> _saveTask() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final hasReminders = _selectedReminders.isNotEmpty &&
        ref.read(settingsPreferencesProvider).notificationsEnabled;
    final task = Task(
      id: widget.taskToEdit?.id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      priority: _selectedPriority,
      dueDate: _dueDate,
      startTime: _startTime,
      endTime: _endTime,
      notes: _notesController.text.trim(),
      repeatRule: _repeatRule,
      checklist: _checklist,
      reminderMinutes: _selectedReminders,
      estimatedDuration: _durationController.text.trim(),
      isCompleted: widget.taskToEdit?.isCompleted ?? false,
      isArchived: widget.taskToEdit?.isArchived ?? false,
      isDeleted: widget.taskToEdit?.isDeleted ?? false,
      isFavorite: widget.taskToEdit?.isFavorite ?? false,
      isPinned: widget.taskToEdit?.isPinned ?? false,
      createdAt: widget.taskToEdit?.createdAt,
      color: widget.taskToEdit?.color ?? '',
    );

    if (widget.taskToEdit != null) {
      await NotificationHelper.cancelAllForTask(task.id);
      await ref.read(taskProvider.notifier).updateTask(task);
    } else {
      await ref.read(taskProvider.notifier).addTask(task);
    }

    if (hasReminders) {
      final taskDateTime = _startTime ??
          DateTime(_dueDate.year, _dueDate.month, _dueDate.day, 9, 0);
      await NotificationHelper.scheduleTaskReminders(
        taskId: task.id,
        taskTitle: task.title,
        taskDateTime: taskDateTime,
        reminderMinutes: _selectedReminders,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskToEdit == null ? 'Add Task' : 'Edit Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                          labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPriority,
                      decoration: const InputDecoration(
                          labelText: 'Priority', border: OutlineInputBorder()),
                      items: _priorities
                          .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPriority = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _repeatRule,
                decoration: const InputDecoration(
                    labelText: 'Repeat Rule', border: OutlineInputBorder()),
                items: _repeatRules
                    .map((rule) =>
                        DropdownMenuItem(value: rule, child: Text(rule)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _repeatRule = val);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due Date'),
                subtitle: Text(
                    '${_dueDate.year}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Time'),
                subtitle: Text(_startTime == null
                    ? 'Not set'
                    : '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _pickTime(isStart: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Time'),
                subtitle: Text(_endTime == null
                    ? 'Not set'
                    : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.access_time),
                onTap: () => _pickTime(isStart: false),
              ),
              const SizedBox(height: 12),
              Text('Reminders (before task)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _reminderOptions.map((minutes) {
                  final isSelected = _selectedReminders.contains(minutes);
                  final label = minutes == 1 ? '1 min' : '$minutes min';
                  return FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedReminders.add(minutes);
                          _selectedReminders.sort();
                        } else {
                          _selectedReminders.remove(minutes);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                    labelText: 'Estimated Duration',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Notes', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _checklistController,
                      decoration: const InputDecoration(
                          labelText: 'Checklist Item',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                      onPressed: _addChecklistItem, child: const Text('Add')),
                ],
              ),
              const SizedBox(height: 8),
              if (_checklist.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _checklist
                      .map((item) => Chip(
                            label: Text(item),
                            onDeleted: () =>
                                setState(() => _checklist.remove(item)),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(
                    widget.taskToEdit == null ? 'Create Task' : 'Update Task',
                    style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
