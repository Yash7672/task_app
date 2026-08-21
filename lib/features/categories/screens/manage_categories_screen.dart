import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/category_model.dart';
import '../../../providers/task_provider.dart';

const _palette = [
  '#4CAF50', '#2196F3', '#9C27B0', '#FF9800', '#E91E63',
  '#607D8B', '#F44336', '#FFC107', '#795548', '#00BCD4',
];

const _emojis = ['🧘', '🎓', '📚', '💪', '🛍️', '💼', '🩺', '💰', '👨‍👩‍👧‍👦', '✈️', '🏠', '🎵', '🎮', '🐶', '⭐'];

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: state.when(
        data: (categories) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _parseColor(category.colorHex)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(category.icon ?? '🏷️',
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                title: Text(category.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () =>
                          _showCategoryDialog(context, ref, category: category),
                    ),
                    if (category.name != 'Personal')
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: Colors.red),
                        onPressed: () => _confirmDelete(
                            context, ref, category),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showCategoryDialog(BuildContext context, WidgetRef ref,
      {TaskCategory? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedColor = category?.colorHex ?? _palette.first;
    String selectedEmoji = category?.icon ?? _emojis.first;

    final result = await showDialog<TaskCategory>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text(category == null ? 'Add Category' : 'Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Category name'),
                ),
                const SizedBox(height: 16),
                const Text('Icon'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _emojis
                      .map((e) => ChoiceChip(
                            label: Text(e),
                            selected: selectedEmoji == e,
                            onSelected: (_) =>
                                setDialogState(() => selectedEmoji = e),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text('Color'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _palette
                      .map((hex) => GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedColor = hex),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _parseColor(hex),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == hex
                                      ? Colors.black87
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
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
                  TaskCategory(
                    id: category?.id,
                    name: nameController.text.trim(),
                    colorHex: selectedColor,
                    icon: selectedEmoji,
                  ),
                );
              },
              child: Text(category == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final notifier = ref.read(categoriesProvider.notifier);
    if (category == null) {
      await notifier.addCategory(result);
    } else {
      await notifier.updateCategory(result);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TaskCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
            '"${category.name}" will be removed. Tasks in this category move to "Personal".'),
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
      await ref.read(categoriesProvider.notifier).deleteCategory(category);
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}
