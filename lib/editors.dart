import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'design.dart';
import 'domain.dart';
import 'planner_data.dart';

Future<T?> _edit<T>(
  BuildContext context,
  String title,
  String submit,
  List<Widget> Function(BuildContext context, StateSetter refresh) fields,
  T Function() result,
) {
  final form = GlobalKey<FormState>();
  return showDialog<T>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: Text(title, style: displayStyle(context, size: 29)),
        content: SizedBox(
          width: 380,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final field in fields(context, refresh))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: field,
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                form.currentState!.save();
                Navigator.pop(context, result());
              }
            },
            child: Text(submit),
          ),
        ],
      ),
    ),
  );
}

String? _required(String? value) =>
    (value ?? '').trim().isEmpty ? 'This field is required.' : null;

Widget _textField(
  String label,
  String initial,
  ValueChanged<String> save, {
  String? hint,
  int max = 80,
  int lines = 1,
  bool required = true,
}) => TextFormField(
  initialValue: initial,
  maxLength: max,
  minLines: lines,
  maxLines: lines,
  textCapitalization: TextCapitalization.sentences,
  decoration: InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: '',
  ),
  validator: required ? _required : null,
  onSaved: (value) => save((value ?? '').trim()),
);

Widget _choice<T>(
  String label,
  T current,
  Iterable<T> options,
  String Function(T) name,
  ValueChanged<T>? changed,
) => DropdownButtonFormField<T>(
  initialValue: current,
  isExpanded: true,
  decoration: InputDecoration(labelText: label),
  items: [
    for (final option in options)
      DropdownMenuItem(value: option, child: Text(name(option))),
  ],
  onChanged: changed == null
      ? null
      : (value) {
          if (value != null) changed(value);
        },
);

Widget _dayField(
  BuildContext context,
  String label,
  String day,
  ValueChanged<String> update,
) => OutlinedButton.icon(
  icon: const Icon(Icons.event_outlined, size: 19),
  label: Text('$label · ${formattedDate(context, day)}'),
  onPressed: () async {
    final selected = await showDatePicker(
      context: context,
      initialDate: dateFromKey(day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && context.mounted) update(dayKey(selected));
  },
);

Future<Task?> editTask(
  BuildContext context,
  String initialDay, [
  Task? existing,
  List<Project> projects = const [],
  String? selectedProject,
  Repeat initialRepeat = Repeat.once,
]) {
  var title = existing?.title ?? '';
  var notes = existing?.notes ?? '';
  var due = existing?.due ?? initialDay;
  var effort = existing?.effort ?? Effort.steady;
  var category = existing?.category ?? TaskCategory.personal;
  var repeat = existing?.repeat ?? initialRepeat;
  var interval = existing?.interval ?? 1;
  var priority = existing?.priority ?? TaskPriority.normal;
  var projectId = existing?.projectId ?? selectedProject ?? '';
  var reminderMinute = existing?.reminderMinute;
  if (!projects.any((project) => project.id == projectId)) projectId = '';
  return _edit(
    context,
    existing == null ? 'New task' : 'Edit task',
    'Save task',
    (context, refresh) => [
      _textField(
        'Task name',
        title,
        (value) => title = value,
        hint: 'Clean my room',
      ),
      _dayField(context, 'Due', due, (value) => refresh(() => due = value)),
      _choice(
        'Category',
        category,
        TaskCategory.values,
        (value) => value.label,
        (value) => refresh(() => category = value),
      ),
      _choice(
        'Effort',
        effort,
        Effort.values,
        (value) => value.label,
        (value) => refresh(() => effort = value),
      ),
      _choice<Repeat>(
        'Repeat',
        repeat,
        Repeat.values,
        (value) => value.label,
        existing != null ? null : (value) => refresh(() => repeat = value),
      ),
      if (repeat != Repeat.once)
        _choice(
          repeat == Repeat.daily
              ? 'Repeat every (days)'
              : 'Repeat every (weeks)',
          interval,
          List.generate(99, (index) => index + 1),
          (value) => '$value',
          (value) => refresh(() => interval = value),
        ),
      _choice(
        'Priority',
        priority,
        TaskPriority.values,
        (value) => '${value.name[0].toUpperCase()}${value.name.substring(1)}',
        (value) => refresh(() => priority = value),
      ),
      if (projects.isNotEmpty)
        _choice(
          'Project',
          projectId,
          ['', ...projects.map((item) => item.id)],
          (id) => id.isEmpty
              ? 'None'
              : projects.firstWhere((item) => item.id == id).title,
          (value) => refresh(() => projectId = value),
        ),
      OutlinedButton.icon(
        icon: const Icon(Icons.notifications_outlined),
        label: Text(
          reminderMinute == null
              ? 'Set reminder'
              : 'Reminder · ${TimeOfDay(hour: reminderMinute! ~/ 60, minute: reminderMinute! % 60).format(context)}',
        ),
        onPressed: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: reminderMinute == null
                ? const TimeOfDay(hour: 9, minute: 0)
                : TimeOfDay(
                    hour: reminderMinute! ~/ 60,
                    minute: reminderMinute! % 60,
                  ),
          );
          if (time != null && context.mounted) {
            refresh(() => reminderMinute = time.hour * 60 + time.minute);
          }
        },
      ),
      if (reminderMinute != null)
        TextButton(
          onPressed: () => refresh(() => reminderMinute = null),
          child: const Text('Remove reminder'),
        ),
      _textField(
        'Notes',
        notes,
        (value) => notes = value,
        max: 400,
        lines: 2,
        required: false,
      ),
    ],
    () => Task(
      id: existing?.id ?? newId(),
      title: title,
      createdOn: existing == null ? dayKey(DateTime.now()) : existing.createdOn,
      due: due,
      category: category,
      effort: effort,
      repeat: repeat,
      notes: notes,
      interval: interval,
      priority: priority,
      projectId: projectId.isEmpty ? null : projectId,
      reminderMinute: reminderMinute,
    ),
  );
}

Widget _amount(String label, int existing, ValueChanged<int> save) =>
    TextFormField(
      initialValue: existing == 0 ? '' : (existing / 100).toStringAsFixed(2),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '€ ',
        hintText: '12.50',
      ),
      validator: (value) => parseCents(value ?? '') == null
          ? 'Enter a positive EUR amount.'
          : null,
      onSaved: (value) => save(parseCents(value!)!),
    );

Future<MoneyEntry?> editMoney(
  BuildContext context,
  String initialDay, [
  MoneyEntry? existing,
]) {
  var name = existing?.label ?? '';
  var category = existing?.category ?? '';
  var kind = existing?.kind ?? MoneyKind.expense;
  var cents = existing?.cents ?? 0;
  var day = existing?.day ?? initialDay;
  return _edit(
    context,
    existing == null ? 'New transaction' : 'Edit transaction',
    'Save transaction',
    (context, refresh) => [
      _choice(
        'Type',
        kind,
        MoneyKind.values,
        (value) => value.label,
        (value) => refresh(() => kind = value),
      ),
      _textField(
        'Description',
        name,
        (value) => name = value,
        hint: 'Groceries',
      ),
      _amount('Amount', cents, (value) => cents = value),
      _textField(
        'Category',
        category,
        (value) => category = value,
        hint: 'Food',
        max: 32,
        required: false,
      ),
      _dayField(context, 'Date', day, (value) => refresh(() => day = value)),
    ],
    () => MoneyEntry(
      existing?.id ?? newId(),
      name,
      category.isEmpty ? 'Uncategorized' : category,
      cents,
      kind,
      day,
    ),
  );
}

Future<int?> editBudget(BuildContext context, int current) {
  var cents = current;
  return _edit(
    context,
    'Monthly budget',
    'Save budget',
    (_, _) => [_amount('Spending limit', current, (value) => cents = value)],
    () => cents,
  );
}

Widget _minutes(String label, int current, int max, ValueChanged<int> save) =>
    TextFormField(
      initialValue: current == 0 ? '' : '$current',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, suffixText: 'min'),
      validator: (value) {
        final minutes = int.tryParse(value ?? '');
        return minutes == null || minutes < 1 || minutes > max
            ? 'Enter 1 to $max minutes.'
            : null;
      },
      onSaved: (value) => save(int.parse(value!)),
    );

Future<Hobby?> editHobby(BuildContext context, [Hobby? existing]) {
  var name = existing?.name ?? '';
  var goal = existing?.weeklyMinutes ?? 60;
  return _edit(
    context,
    existing == null ? 'New hobby' : 'Edit hobby',
    'Save hobby',
    (_, _) => [
      _textField('Hobby name', name, (value) => name = value, hint: 'Coding'),
      _minutes('Weekly goal', goal, 10080, (value) => goal = value),
    ],
    () => Hobby(existing?.id ?? newId(), name, goal),
  );
}

Future<PracticeSession?> logPractice(BuildContext context, Hobby hobby) {
  var minutes = 25;
  var notes = '';
  return _edit(
    context,
    'Log ${hobby.name}',
    'Log session',
    (_, _) => [
      _minutes('Duration', minutes, 720, (value) => minutes = value),
      _textField(
        'Notes',
        notes,
        (value) => notes = value,
        max: 400,
        lines: 2,
        required: false,
      ),
    ],
    () => PracticeSession(newId(), hobby.id, minutes, notes, DateTime.now()),
  );
}

Future<String?> renameTown(BuildContext context, String name) {
  var result = name;
  return _edit(
    context,
    'Rename town',
    'Save name',
    (_, _) => [
      _textField('Town name', name, (value) => result = value, max: 35),
    ],
    () => result,
  );
}

Future<bool> confirmRemoval(
  BuildContext context,
  String title,
  String text,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
