import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'domain.dart';

class TaskReminders {
  static const _channel = MethodChannel('app.havenlife.haven/reminders');
  static bool get native => Platform.isAndroid || Platform.isIOS;
  String? _previous;

  Future<void> sync(
    HavenState state,
    DateTime now, {
    bool askPermission = false,
  }) async {
    if (!native) return;
    final schedule = <Map<String, Object>>[];
    for (final task in state.tasks) {
      final minute = task.reminderMinute;
      if (task.archived || minute == null) continue;
      final due = dateFromKey(task.due);
      final start = due.isAfter(now) ? due : now;
      final days = task.repeat == Repeat.weekly
          ? 7 * task.interval
          : task.interval;
      for (var offset = 0; offset <= days * 2; offset++) {
        final occurrence = calendarDay(start, offset);
        final day = dayKey(occurrence);
        final at = DateTime(
          occurrence.year,
          occurrence.month,
          occurrence.day,
          minute ~/ 60,
          minute % 60,
        );
        if (at.isAfter(now) &&
            task.occursOn(day) &&
            !state.completed(task, day)) {
          schedule.add({
            'id': task.id,
            'title': task.title,
            'at': at.millisecondsSinceEpoch,
            'repeat': task.repeat == Repeat.once ? 0 : days,
          });
          break;
        }
        if (task.repeat == Repeat.once) break;
      }
    }
    schedule.sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
    final limited = schedule.take(50).toList();
    final serialized = jsonEncode(limited);
    if (_previous == serialized && !askPermission) return;
    try {
      await _channel.invokeMethod<void>('schedule', {
        'tasks': limited,
        'permission': askPermission,
      });
      _previous = serialized;
    } on PlatformException {
      // Reminders do not block saving a task.
    } on MissingPluginException {
      // Widget tests and unsupported platforms use the in-app view.
    }
  }
}

Future<bool> openSystemCalendar(Task task, String day) async {
  if (!Platform.isAndroid) return false;
  final date = dateFromKey(day);
  final minutes = task.reminderMinute;
  final start = minutes == null
      ? DateTime.utc(date.year, date.month, date.day)
      : DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
  try {
    return await const MethodChannel('app.havenlife.haven/reminders')
            .invokeMethod<bool>('calendar', {
              'title': task.title,
              'notes': task.notes,
              'start': start.millisecondsSinceEpoch,
              'end': start
                  .add(Duration(minutes: minutes == null ? 1440 : 30))
                  .millisecondsSinceEpoch,
              'allDay': minutes == null,
            }) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
