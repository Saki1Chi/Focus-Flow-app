enum RepeatType { daily, weekly, monthly, yearly }
enum EndType { never, afterOccurrences, onDate }

class RecurrenceRule {
  final RepeatType repeatType;
  final int interval; // every N days/weeks/months
  final List<int> skipDays; // 0=Mon ... 6=Sun
  final EndType endType;
  final int? occurrences;
  final DateTime? endDate;

  const RecurrenceRule({
    required this.repeatType,
    this.interval = 1,
    this.skipDays = const [],
    this.endType = EndType.never,
    this.occurrences,
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
        'repeatType': repeatType.index,
        'interval': interval,
        'skipDays': skipDays,
        'endType': endType.index,
        'occurrences': occurrences,
        'endDate': endDate?.toIso8601String(),
      };

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) => RecurrenceRule(
        repeatType: RepeatType.values[json['repeatType'] as int],
        interval: json['interval'] as int? ?? 1,
        skipDays: List<int>.from(json['skipDays'] ?? []),
        endType: EndType.values[json['endType'] as int],
        occurrences: json['occurrences'] as int?,
        endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      );

  DateTime? nextOccurrence(DateTime from) {
    DateTime candidate = _advance(from);
    while (_shouldSkip(candidate)) {
      candidate = _advance(candidate);
    }
    if (endType == EndType.onDate && endDate != null && candidate.isAfter(endDate!)) {
      return null;
    }
    return candidate;
  }

  DateTime _advance(DateTime date) {
    switch (repeatType) {
      case RepeatType.daily:
        return date.add(Duration(days: interval));
      case RepeatType.weekly:
        return date.add(Duration(days: 7 * interval));
      case RepeatType.monthly:
        return DateTime(date.year, date.month + interval, date.day);
      case RepeatType.yearly:
        return DateTime(date.year + interval, date.month, date.day);
    }
  }

  bool _shouldSkip(DateTime date) {
    // weekday: 1=Monday, 7=Sunday → convert to 0=Mon, 6=Sun
    final wd = date.weekday - 1;
    return skipDays.contains(wd);
  }
}
