import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../models/checklist_model.dart';
import '../services/home_widget_service.dart';
import 'database_provider.dart';

class ChecklistsState {
  final List<Checklist> checklists;
  final Map<String, List<ChecklistItem>> items;

  const ChecklistsState({
    this.checklists = const [],
    this.items = const {},
  });

  int completedCount(String checklistId) =>
      (items[checklistId] ?? const []).where((i) => i.completed).length;

  int totalCount(String checklistId) => (items[checklistId] ?? const []).length;
}

final checklistProvider =
    StateNotifierProvider<ChecklistNotifier, ChecklistsState>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  return ChecklistNotifier(dbHelper);
});

class ChecklistNotifier extends StateNotifier<ChecklistsState> {
  final DatabaseHelper dbHelper;

  ChecklistNotifier(this.dbHelper) : super(const ChecklistsState()) {
    loadChecklists();
  }

  void _updateChecklistWidget() {
    // Push the first checklist's data to the widget
    if (state.checklists.isNotEmpty) {
      final first = state.checklists.first;
      final items = state.items[first.id] ?? const [];
      HomeWidgetService.refreshChecklist(title: first.title, items: items);
    } else {
      HomeWidgetService.refreshChecklist(title: '', items: []);
    }
  }

  Future<void> loadChecklists() async {
    try {
      final checklists = await dbHelper.getAllChecklists();
      final items = await dbHelper.getAllChecklistItems();
      state = ChecklistsState(checklists: checklists, items: items);
    } catch (e) {
      debugPrint('Error loading checklists: $e');
    }
  }

  Future<Checklist?> createChecklist(String title) async {
    try {
      final checklist =
          await dbHelper.createChecklist(Checklist(title: title));
      state = ChecklistsState(
        checklists: [checklist, ...state.checklists],
        items: {...state.items, checklist.id: []},
      );
      return checklist;
    } catch (e) {
      debugPrint('Error creating checklist: $e');
      return null;
    }
  }

  Future<void> renameChecklist(Checklist checklist, String title) async {
    try {
      final updated = checklist.copyWith(title: title);
      await dbHelper.updateChecklist(updated);
      final list = [...state.checklists];
      final index = list.indexWhere((c) => c.id == checklist.id);
      if (index != -1) {
        list[index] = updated;
        state = ChecklistsState(checklists: list, items: state.items);
      }
    } catch (e) {
      debugPrint('Error renaming checklist: $e');
    }
  }

  Future<void> deleteChecklist(String id) async {
    try {
      await dbHelper.deleteChecklist(id);
      final items = {...state.items}..remove(id);
      state = ChecklistsState(
        checklists:
            state.checklists.where((c) => c.id != id).toList(),
        items: items,
      );
    } catch (e) {
      debugPrint('Error deleting checklist: $e');
    }
  }

  Future<void> addItem(String checklistId, String text) async {
    if (text.trim().isEmpty) return;
    try {
      final position = (state.items[checklistId] ?? const []).length;
      final item = await dbHelper.createChecklistItem(
        ChecklistItem(
          checklistId: checklistId,
          text: text.trim(),
          position: position,
        ),
      );
      _upsertItem(item);
      _updateChecklistWidget();
    } catch (e) {
      debugPrint('Error adding checklist item: $e');
    }
  }

  Future<void> toggleItem(ChecklistItem item) async {
    try {
      final updated = item.copyWith(completed: !item.completed);
      await dbHelper.updateChecklistItem(updated);
      _upsertItem(updated);
      _updateChecklistWidget();
    } catch (e) {
      debugPrint('Error toggling checklist item: $e');
    }
  }

  Future<void> updateItemText(ChecklistItem item, String text) async {
    try {
      final updated = item.copyWith(text: text.trim());
      await dbHelper.updateChecklistItem(updated);
      _upsertItem(updated);
      _updateChecklistWidget();
    } catch (e) {
      debugPrint('Error updating checklist item: $e');
    }
  }

  Future<void> deleteItem(ChecklistItem item) async {
    // Optimistic update first so the swiped row leaves the tree on the same
    // frame (avoids 'dismissed Dismissible still part of the tree').
    final items = {...state.items};
    final list = [...(items[item.checklistId] ?? const <ChecklistItem>[])];
    list.removeWhere((i) => i.id == item.id);
    items[item.checklistId] = list;
    state = ChecklistsState(checklists: state.checklists, items: items);
    _updateChecklistWidget();
    try {
      await dbHelper.deleteChecklistItem(item.id, item.checklistId);
    } catch (e) {
      debugPrint('Error deleting checklist item: $e');
      await loadChecklists();
    }
  }

  void _upsertItem(ChecklistItem item) {
    final items = {...state.items};
    final list = [...(items[item.checklistId] ?? const <ChecklistItem>[])];
    final index = list.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      list[index] = item;
    } else {
      list.add(item);
    }
    items[item.checklistId] = list;
    state = ChecklistsState(checklists: state.checklists, items: items);
  }
}
