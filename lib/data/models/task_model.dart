import 'dart:convert';
import 'recurrence_rule.dart';

enum TaskStatus { pending, inProgress, completed }
enum TaskMode { calendar, smart }

class Task {
  final String id;
  String title;
  String description;
  DateTime date;
  DateTime? startTime;
  DateTime? endTime;
  TaskStatus status;
  TaskMode mode;
  RecurrenceRule? recurrence;
  bool isCarriedOver;
  int dayOrder; // sequential order within the day
  String? parentId; // for recurring instances
  bool isRecurringParent;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.startTime,
    this.endTime,
    this.status = TaskStatus.pending,
    this.mode = TaskMode.calendar,
    this.recurrence,
    this.isCarriedOver = false,
    this.dayOrder = 0,
    this.parentId,
    this.isRecurringParent = false,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    TaskStatus? status,
    TaskMode? mode,
    RecurrenceRule? recurrence,
    bool? isCarriedOver,
    int? dayOrder,
    String? parentId,
    bool? isRecurringParent,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      recurrence: recurrence ?? this.recurrence,
      isCarriedOver: isCarriedOver ?? this.isCarriedOver,
      dayOrder: dayOrder ?? this.dayOrder,
      parentId: parentId ?? this.parentId,
      isRecurringParent: isRecurringParent ?? this.isRecurringParent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'status': status.index,
        'mode': mode.index,
        'recurrence': recurrence?.toJson(),
        'isCarriedOver': isCarriedOver,
        'dayOrder': dayOrder,
        'parentId': parentId,
        'isRecurringParent': isRecurringParent,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        date: DateTime.parse(json['date']),
        startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
        status: TaskStatus.values[json['status'] as int],
        mode: TaskMode.values[json['mode'] as int],
        recurrence: json['recurrence'] != null
            ? RecurrenceRule.fromJson(Map<String, dynamic>.from(json['recurrence']))
            : null,
        isCarriedOver: json['isCarriedOver'] as bool? ?? false,
        dayOrder: json['dayOrder'] as int? ?? 0,
        parentId: json['parentId'] as String?,
        isRecurringParent: json['isRecurringParent'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory Task.fromJsonString(String jsonStr) => Task.fromJson(jsonDecode(jsonStr));

  bool get isOverdue {
    if (status == TaskStatus.completed) return false;
    if (endTime == null) return false;
    return DateTime.now().isAfter(endTime!);
  }

  bool get isStartingSoon {
    if (startTime == null) return false;
    final now = DateTime.now();
    final diff = startTime!.difference(now).inMinutes;
    return diff >= 0 && diff <= 15;
  }

  String get statusEmoji {
    switch (status) {
      case TaskStatus.completed:
        return '✅';
      case TaskStatus.inProgress:
        return '🔄';
      case TaskStatus.pending:
        return '⬜';
    }
  }
}
