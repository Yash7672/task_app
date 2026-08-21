import 'package:flutter_test/flutter_test.dart';
import 'package:task_app/models/checklist_model.dart';

void main() {
  test('checklist round-trips through the database map', () {
    final checklist = Checklist(title: 'Shopping');
    final map = checklist.toMap();
    final restored = Checklist.fromMap(map);

    expect(restored.title, 'Shopping');
    expect(restored.id, checklist.id);
  });

  test('checklist item round-trips with completion and position', () {
    final item = ChecklistItem(
      checklistId: 'list-1',
      text: 'Buy oat milk',
      position: 3,
      completed: true,
    );

    final restored = ChecklistItem.fromMap(item.toMap());

    expect(restored.checklistId, 'list-1');
    expect(restored.text, 'Buy oat milk');
    expect(restored.position, 3);
    expect(restored.completed, isTrue);
  });

  test('item copyWith toggles completion without mutating original', () {
    final item = ChecklistItem(checklistId: 'l', text: 'Call mom');
    final toggled = item.copyWith(completed: true);

    expect(item.completed, isFalse);
    expect(toggled.completed, isTrue);
    expect(toggled.text, 'Call mom');
  });
}
