import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'actions.dart';
import 'appearance.dart';
import 'cloud_appearance.dart';
import 'design.dart';
import 'domain.dart';
import 'planner_data.dart';
import 'planning.dart';
import 'reminders.dart';
import 'update_widgets.dart';
import 'updates.dart';

enum _TaskMenu { edit, archive, calendar }

class TaskRow extends StatelessWidget {
  const TaskRow(
    this.task, {
    super.key,
    required this.today,
    required this.state,
    required this.actions,
    this.occurrence,
    this.canComplete = true,
  });
  final Task task;
  final String today;
  final HavenState state;
  final HavenActions actions;
  final String? occurrence;
  final bool canComplete;

  @override
  Widget build(BuildContext context) {
    final day = occurrence ?? today;
    final done = day == today
        ? state.checked(task, day)
        : state.completed(task, day);
    final subtitle = [
      if (done) 'Completed',
      task.category.label,
      if (task.repeat != Repeat.once)
        task.interval == 1
            ? task.repeat.label
            : 'Every ${task.interval} ${task.repeat == Repeat.daily ? 'days' : 'weeks'}',
      if (task.priority == TaskPriority.high) 'High priority',
      if (task.priority == TaskPriority.low) 'Low priority',
      if (task.reminderMinute case final time?)
        TimeOfDay(hour: time ~/ 60, minute: time % 60).format(context),
      if (!done && task.repeat == Repeat.once && task.due.compareTo(today) < 0)
        'Overdue',
      if (!done && task.due.compareTo(today) > 0)
        formattedDate(context, task.due),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        children: [
          IconButton(
            tooltip: done
                ? '${task.title} completed'
                : 'Complete ${task.title}',
            onPressed: done || !canComplete
                ? null
                : () => actions.finishTask(context, task),
            icon: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? Theme.of(context).colorScheme.primary : null,
              size: 23,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: task.archived
                  ? null
                  : () => actions.changeTask(context, today, task),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: muted(context, size: 12)),
                  ],
                ),
              ),
            ),
          ),
          if (!task.archived)
            PopupMenuButton<_TaskMenu>(
              tooltip: 'Options for ${task.title}',
              onSelected: (value) {
                switch (value) {
                  case _TaskMenu.edit:
                    actions.changeTask(context, today, task);
                  case _TaskMenu.archive:
                    actions.archiveTask(context, task);
                  case _TaskMenu.calendar:
                    openSystemCalendar(task, occurrence ?? task.due).then((
                      opened,
                    ) {
                      if (!opened && context.mounted) {
                        showNotice(
                          context,
                          'No calendar app could open this task.',
                        );
                      }
                    });
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _TaskMenu.edit,
                  child: Text('Edit task'),
                ),
                if (Platform.isAndroid)
                  const PopupMenuItem(
                    value: _TaskMenu.calendar,
                    child: Text('Add to device calendar'),
                  ),
                const PopupMenuItem(
                  value: _TaskMenu.archive,
                  child: Text('Archive task'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class TaskListPanel extends StatelessWidget {
  const TaskListPanel({
    super.key,
    required this.tasks,
    required this.state,
    required this.actions,
    required this.today,
    this.occurrence,
    this.canComplete = true,
  });
  final List<Task> tasks;
  final HavenState state;
  final HavenActions actions;
  final String today;
  final String? occurrence;
  final bool canComplete;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        for (var i = 0; i < tasks.length; i++) ...[
          if (i != 0) const Divider(height: 1, indent: 50, endIndent: 12),
          TaskRow(
            tasks[i],
            state: state,
            actions: actions,
            today: today,
            canComplete: canComplete,
            occurrence: occurrence,
          ),
        ],
      ],
    ),
  );
}

enum _TaskFilter { today, upcoming, completed }

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.state,
    required this.actions,
    required this.today,
    this.routines = false,
    this.onPhoto,
  });
  final HavenState state;
  final HavenActions actions;
  final String today;
  final bool routines;
  final VoidCallback? onPhoto;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  _TaskFilter filter = _TaskFilter.today;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final today = widget.today;
    final tasks = switch (filter) {
      _TaskFilter.today => state.tasksFor(today, includeOverdue: true),
      _TaskFilter.upcoming =>
        state.tasks
            .where(
              (task) =>
                  !task.archived &&
                  (widget.routines || task.due.compareTo(today) > 0) &&
                  !state.completed(task, today),
            )
            .toList()
          ..sort((a, b) => a.due.compareTo(b.due)),
      _TaskFilter.completed => <Task>[],
    };
    if (widget.routines) {
      tasks.removeWhere((task) => task.repeat == Repeat.once);
    }
    final completed = state.ledger
        .where(
          (entry) =>
              entry.kind == LedgerKind.task &&
              (!widget.routines ||
                  state.tasks.any(
                    (task) =>
                        task.id == entry.sourceId && task.repeat != Repeat.once,
                  )),
        )
        .toList()
        .reversed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageIntro(
          widget.routines ? 'Routines' : 'Tasks',
          '',
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => widget.actions.changeTask(
                  context,
                  today,
                  null,
                  null,
                  widget.routines ? Repeat.daily : Repeat.once,
                ),
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              ),
              if (!widget.routines && widget.onPhoto != null)
                OutlinedButton.icon(
                  onPressed: widget.onPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Photo tasks'),
                ),
              OutlinedButton.icon(
                onPressed: () => showResetSettings(context, widget.actions),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 7,
          children: [
            for (final item in _TaskFilter.values)
              ChoiceChip(
                label: Text(switch (item) {
                  _TaskFilter.today => 'Today',
                  _TaskFilter.upcoming =>
                    widget.routines ? 'All routines' : 'Upcoming',
                  _TaskFilter.completed => 'Completed',
                }),
                selected: filter == item,
                onSelected: (_) => setState(() => filter = item),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (filter == _TaskFilter.completed && completed.isNotEmpty)
          Panel(
            child: Column(
              children: [
                for (final entry in completed)
                  ListTile(
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      state.tasks
                              .where((task) => task.id == entry.sourceId)
                              .firstOrNull
                              ?.title ??
                          'Task',
                    ),
                    subtitle: Text(formattedDate(context, entry.day)),
                  ),
              ],
            ),
          )
        else if (tasks.isNotEmpty)
          TaskListPanel(
            tasks: tasks,
            state: state,
            actions: widget.actions,
            today: today,
            canComplete: filter == _TaskFilter.today,
          )
        else
          EmptyPanel(
            filter == _TaskFilter.completed
                ? 'No completed tasks'
                : 'No tasks here',
            filter == _TaskFilter.completed
                ? 'Your completed tasks will appear here.'
                : 'Add a task when you have something to do.',
            icon: Icons.checklist_rounded,
          ),
      ],
    );
  }
}

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({
    super.key,
    required this.state,
    required this.actions,
    required this.today,
  });
  final HavenState state;
  final HavenActions actions;
  final String today;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime? picked;
  bool showMonth = false;

  void select(DateTime day) => setState(() => picked = day);

  @override
  Widget build(BuildContext context) {
    final now = dateFromKey(widget.today);
    final selected = picked ?? now;
    final day = dayKey(selected);
    final monday = calendarDay(selected, 1 - selected.weekday);
    final tasks = widget.state.tasksFor(
      day,
      includeOverdue: day == widget.today,
    );
    final labels = MaterialLocalizations.of(context).narrowWeekdays;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageIntro(
          'Calendar',
          '',
          action: FilledButton.icon(
            onPressed: () => widget.actions.changeTask(context, day),
            icon: const Icon(Icons.add),
            label: const Text('Schedule task'),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Week'),
              selected: !showMonth,
              onSelected: (_) => setState(() => showMonth = false),
            ),
            ChoiceChip(
              label: const Text('Month'),
              selected: showMonth,
              onSelected: (_) => setState(() => showMonth = true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (showMonth)
          Panel(
            padding: EdgeInsets.zero,
            child: CalendarDatePicker(
              initialDate: selected,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100, 12, 31),
              currentDate: now,
              onDateChanged: select,
            ),
          )
        else
          Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous week',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => select(calendarDay(selected, -7)),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 20,
                        ),
                        label: Text(
                          MaterialLocalizations.of(context)
                              .formatMonthYear(selected),
                        ),
                        onPressed: () async {
                          final value = await showDatePicker(
                            context: context,
                            initialDate: selected,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (value != null && mounted) select(value);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next week',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => select(calendarDay(selected, 7)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final date = calendarDay(monday, i);
                            final key = dayKey(date);
                            final active = key == day;
                            return Semantics(
                              selected: active,
                              button: true,
                              label: formattedDate(context, key),
                              child: InkWell(
                                onTap: () => select(date),
                                borderRadius: BorderRadius.circular(12),
                                child: ExcludeSemantics(
                                  child: Container(
                                    margin: const EdgeInsets.all(1),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? scheme.primaryContainer
                                          : null,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          labels[date.weekday % 7],
                                          style: muted(context, size: 12)
                                              .copyWith(
                                                color: active
                                                    ? scheme.onPrimaryContainer
                                                    : null,
                                              ),
                                        ),
                                        Text(
                                          '${date.day}',
                                          style: TextStyle(
                                            color: active
                                                ? scheme.onPrimaryContainer
                                                : null,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 19),
        Text(
          day == widget.today ? 'Today' : formattedDate(context, day),
          style: displayStyle(context, size: 24),
        ),
        const SizedBox(height: 10),
        for (final project in widget.state.projects.where(
          (item) => item.milestone == day,
        ))
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(project.title),
            subtitle: const Text('Project milestone'),
          ),
        if (tasks.isEmpty)
          const EmptyPanel(
            'Nothing scheduled',
            'Add a task for this day.',
            icon: Icons.event_available_outlined,
          )
        else
          TaskListPanel(
            tasks: tasks,
            state: widget.state,
            actions: widget.actions,
            today: widget.today,
            occurrence: day,
            canComplete: day == widget.today,
          ),
      ],
    );
  }
}

enum _MoneyMenu { edit, delete }

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({
    super.key,
    required this.state,
    required this.actions,
    required this.today,
  });
  final HavenState state;
  final HavenActions actions;
  final String today;

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  DateTime? month;

  @override
  Widget build(BuildContext context) {
    final now = dateFromKey(widget.today);
    final currentMonth = month ?? DateTime(now.year, now.month);
    final prefix = dayKey(currentMonth).substring(0, 7);
    final entries =
        widget.state.money
            .where((entry) => entry.day.startsWith('$prefix-'))
            .toList()
          ..sort((a, b) => b.day.compareTo(a.day));
    final income = entries
        .where((entry) => entry.kind == MoneyKind.income)
        .fold(0, (sum, item) => sum + item.cents);
    final expense = entries
        .where((entry) => entry.kind == MoneyKind.expense)
        .fold(0, (sum, item) => sum + item.cents);
    final categories = <String, int>{};
    for (final item in entries.where(
      (entry) => entry.kind == MoneyKind.expense,
    )) {
      categories.update(
        item.category,
        (sum) => sum + item.cents,
        ifAbsent: () => item.cents,
      );
    }
    final breakdown = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final budget = widget.state.budgets[prefix] ?? 0;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageIntro(
          'Money',
          'Your manually recorded income and expenses in EUR.',
          action: FilledButton.icon(
            onPressed: () => widget.actions.changeMoney(
              context,
              prefix == widget.today.substring(0, 7)
                  ? widget.today
                  : dayKey(currentMonth),
            ),
            icon: const Icon(Icons.add),
            label: const Text('New transaction'),
          ),
        ),
        Panel(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(
                      () => month = DateTime(
                        currentMonth.year,
                        currentMonth.month - 1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      MaterialLocalizations.of(context)
                          .formatMonthYear(currentMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(
                      () => month = DateTime(
                        currentMonth.year,
                        currentMonth.month + 1,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net cash flow', style: muted(context)),
                      Text(
                        euro(income - expense),
                        style: displayStyle(context, size: 36),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: _MoneyMetric('Income', income)),
                    Expanded(child: _MoneyMetric('Expenses', expense)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Monthly budget',
                    style: displayStyle(context, size: 23),
                  ),
                  TextButton(
                    onPressed: () =>
                        widget.actions.changeBudget(context, prefix, budget),
                    child: Text(budget == 0 ? 'Set budget' : 'Edit budget'),
                  ),
                ],
              ),
              if (budget > 0) ...[
                Text(
                  '${euro(expense)} of ${euro(budget)} spent',
                  style: muted(context),
                ),
                const SizedBox(height: 9),
                LinearProgressIndicator(
                  value: (expense / budget).clamp(0.0, 1.0),
                  color: expense > budget ? scheme.error : null,
                  borderRadius: BorderRadius.circular(12),
                  minHeight: 8,
                ),
              ] else
                Text(
                  'Add a spending limit for this month.',
                  style: muted(context),
                ),
            ],
          ),
        ),
        if (breakdown.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(
            child: Column(
              children: [
                for (final item in breakdown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.key)),
                        Text(
                          euro(item.value),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 21),
        Text('Transactions', style: displayStyle(context, size: 25)),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          const EmptyPanel(
            'No transactions this month',
            'Add an income or expense to get started.',
            icon: Icons.receipt_long_outlined,
          )
        else
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final entry in entries)
                  ListTile(
                    title: Text(
                      entry.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${entry.category} · ${formattedDate(context, entry.day)}'
                      '\n${entry.kind == MoneyKind.income ? '+' : '−'}${euro(entry.cents)}',
                    ),
                    trailing: PopupMenuButton<_MoneyMenu>(
                      tooltip: 'Options for ${entry.label}',
                      onSelected: (value) {
                        switch (value) {
                          case _MoneyMenu.edit:
                            widget.actions.changeMoney(
                              context,
                              widget.today,
                              entry,
                            );
                          case _MoneyMenu.delete:
                            widget.actions.deleteMoney(context, entry);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _MoneyMenu.edit,
                          child: Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: _MoneyMenu.delete,
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MoneyMetric extends StatelessWidget {
  const _MoneyMetric(this.label, this.cents);
  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: muted(context)),
      Text(
        euro(cents),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
    ],
  );
}

enum _HobbyMenu { edit, archive }

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.state,
    required this.actions,
    required this.today,
    this.updates,
    this.cloud,
  });
  final HavenState state;
  final HavenActions actions;
  final String today;
  final UpdateController? updates;
  final AppearanceCloud? cloud;

  @override
  Widget build(BuildContext context) {
    final hobbies = state.hobbies.where((hobby) => !hobby.archived);
    final now = dateFromKey(today);
    final weekStart = dayKey(calendarDay(now, 1 - now.weekday));
    final weekEnd = dayKey(calendarDay(now, 8 - now.weekday));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Settings', style: displayStyle(context, size: 28)),
        const SizedBox(height: 10),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_location_alt_outlined),
                contentPadding: EdgeInsets.zero,
                title: const Text('Town name'),
                subtitle: Text(state.townName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => actions.rename(context, state.townName),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                contentPadding: EdgeInsets.zero,
                title: const Text('Appearance'),
                subtitle: Text(
                  state.appearance.mono.name == 'off'
                      ? state.appearance.preset.label
                      : 'Black & White',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppearanceScreen(actions: actions),
                  ),
                ),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.phone_android_outlined),
                contentPadding: EdgeInsets.zero,
                title: Text('Local save'),
                subtitle: Text('Progress is stored on this device.'),
              ),
            ],
          ),
        ),
        if (cloud case final controller?) ...[
          const SizedBox(height: 12),
          _CloudPanel(controller),
        ],
        if (updates case final controller?) ...[
          const SizedBox(height: 12),
          UpdatesPanel(controller),
        ],
        const SizedBox(height: 22),
        PageIntro(
          'Hobbies',
          'Track practice and set weekly goals.',
          action: FilledButton.icon(
            onPressed: () => actions.changeHobby(context),
            icon: const Icon(Icons.add),
            label: const Text('New hobby'),
          ),
        ),
        if (hobbies.isEmpty)
          const EmptyPanel(
            'No hobbies yet',
            'Add something you like doing.',
            icon: Icons.palette_outlined,
          ),
        for (final hobby in hobbies) ...[
          Builder(
            builder: (context) {
              final sessions =
                  state.sessions
                      .where((session) => session.hobbyId == hobby.id)
                      .toList()
                    ..sort((a, b) => b.at.compareTo(a.at));
              final minutes = sessions
                  .where((session) {
                    final day = dayKey(session.at.toLocal());
                    return day.compareTo(weekStart) >= 0 &&
                        day.compareTo(weekEnd) < 0;
                  })
                  .fold(0, (value, session) => value + session.minutes);
              return Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hobby.name,
                            style: displayStyle(context, size: 26),
                          ),
                        ),
                        PopupMenuButton<_HobbyMenu>(
                          tooltip: 'Options for ${hobby.name}',
                          onSelected: (value) {
                            switch (value) {
                              case _HobbyMenu.edit:
                                actions.changeHobby(context, hobby);
                              case _HobbyMenu.archive:
                                actions.archiveHobby(context, hobby);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: _HobbyMenu.edit,
                              child: Text('Edit hobby'),
                            ),
                            PopupMenuItem(
                              value: _HobbyMenu.archive,
                              child: Text('Archive hobby'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '$minutes of ${hobby.weeklyMinutes} min this week',
                      style: muted(context),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (minutes / hobby.weeklyMinutes).clamp(0.0, 1.0),
                      borderRadius: BorderRadius.circular(5),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => actions.practice(context, hobby),
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: const Text('Log practice'),
                    ),
                    if (sessions.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text('Session history (${sessions.length})'),
                        children: [
                          for (final session in sessions)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${session.minutes} min · ${formattedDate(context, dayKey(session.at.toLocal()))}',
                              ),
                              subtitle: session.notes.isEmpty
                                  ? null
                                  : Text(session.notes),
                            ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CloudPanel extends StatelessWidget {
  const _CloudPanel(this.cloud);
  final AppearanceCloud cloud;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: cloud,
    builder: (context, _) => Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance sync', style: displayStyle(context, size: 22)),
          const SizedBox(height: 6),
          Text(
            cloud.email ??
                (cloud.supported
                    ? (cloud.configured
                          ? 'Sign in to sync appearance preferences.'
                          : 'Google sign-in needs a Firebase configuration.')
                    : 'Google sign-in is available on configured Android and iOS builds.'),
          ),
          if (cloud.status case final status?) ...[
            const SizedBox(height: 4),
            Text(status, style: muted(context)),
          ],
          if (cloud.connected)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: cloud.busy ? null : cloud.sync,
                  child: const Text('Sync now'),
                ),
                TextButton(
                  onPressed: cloud.busy ? null : cloud.signOut,
                  child: const Text('Sign out'),
                ),
              ],
            )
          else if (cloud.configured && cloud.supported)
            OutlinedButton.icon(
              onPressed: cloud.busy ? null : cloud.signIn,
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Sign in with Google'),
            ),
        ],
      ),
    ),
  );
}
