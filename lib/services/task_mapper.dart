import 'dart:convert';
import '../data/models/task_model.dart';

/// Conversión Task ↔ JSON del backend (snake_case).
///
/// Mantener sincronizado con los schemas de Python en backend/schemas.py.
/// Cada campo aquí corresponde a un campo en TaskBase / TaskResponse.

Map<String, dynamic> taskToSnake(Task task) => {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'date': task.date.toIso8601String(),
      'start_time': task.startTime?.toIso8601String(),
      'end_time': task.endTime?.toIso8601String(),
      'status': task.status.index,
      'mode': task.mode.index,
      'recurrence':
          task.recurrence != null ? jsonEncode(task.recurrence!.toJson()) : null,
      'is_carried_over': task.isCarriedOver,
      'day_order': task.dayOrder,
      'parent_id': task.parentId,
      'is_recurring_parent': task.isRecurringParent,
      'category_id': task.categoryId,
    };

Map<String, dynamic> snakeToCamel(dynamic json) {
  final m = Map<String, dynamic>.from(json as Map);
  return {
    'id': m['id'],
    'title': m['title'],
    'description': m['description'] ?? '',
    'date': m['date'],
    'startTime': m['start_time'],
    'endTime': m['end_time'],
    'status': m['status'],
    'mode': m['mode'],
    'recurrence': _parseRecurrence(m['recurrence']),
    'isCarriedOver': m['is_carried_over'] ?? false,
    'dayOrder': m['day_order'] ?? 0,
    'parentId': m['parent_id'],
    'isRecurringParent': m['is_recurring_parent'] ?? false,
    'categoryId': m['category_id'],
  };
}

dynamic _parseRecurrence(dynamic value) {
  if (value == null) return null;
  try {
    return jsonDecode(value as String);
  } catch (_) {
    return null;
  }
}
