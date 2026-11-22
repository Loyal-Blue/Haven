enum ResetFrequency { off, daily, weekly }

class TaskReset {
  const TaskReset({
    this.frequency = ResetFrequency.off,
    this.weekday = 1,
    this.minute = 0,
    this.lastAt = 0,
    this.cutoff = 0,
    this.rechecked = const {},
  });

  final ResetFrequency frequency;
  final int weekday, minute, lastAt, cutoff;
  final Set<String> rechecked;

  DateTime? due(DateTime now) {
    if (frequency == ResetFrequency.off) return null;
    final offset = frequency == ResetFrequency.weekly
        ? (now.weekday - weekday) % 7
        : 0;
    var date = DateTime(
      now.year,
      now.month,
      now.day - offset,
      minute ~/ 60,
      minute % 60,
    );
    if (date.isAfter(now)) {
      date = DateTime(
        date.year,
        date.month,
        date.day - (frequency == ResetFrequency.weekly ? 7 : 1),
        minute ~/ 60,
        minute % 60,
      );
    }
    return date.millisecondsSinceEpoch <= lastAt ? null : date;
  }

  TaskReset after(DateTime now, int index) => TaskReset(
    frequency: frequency,
    weekday: weekday,
    minute: minute,
    lastAt: now.millisecondsSinceEpoch,
    cutoff: index,
  );

  TaskReset check(String id) => TaskReset(
    frequency: frequency,
    weekday: weekday,
    minute: minute,
    lastAt: lastAt,
    cutoff: cutoff,
    rechecked: {...rechecked, id},
  );

  Map<String, dynamic> toJson() => {
    'frequency': frequency.name,
    'weekday': weekday,
    'minute': minute,
    'lastAt': lastAt,
    'cutoff': cutoff,
    'rechecked': rechecked.toList(),
  };

  static TaskReset fromJson(Map<String, dynamic>? json) => json == null
      ? const TaskReset()
      : TaskReset(
          frequency: ResetFrequency.values.byName(json['frequency']),
          weekday: (json['weekday'] as int).clamp(1, 7),
          minute: (json['minute'] as int).clamp(0, 1439),
          lastAt: json['lastAt'],
          cutoff: json['cutoff'],
          rechecked: Set.unmodifiable(List<String>.from(json['rechecked'])),
        );
}

enum TaskPriority { normal, high, low }

class Project {
  const Project(this.id, this.title, {this.milestone});
  final String id, title;
  final String? milestone;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'milestone': milestone,
  };
  static Project fromJson(Map<String, dynamic> json) =>
      Project(json['id'], json['title'], milestone: json['milestone']);
}
