import 'package:material_ui/material_ui.dart';

import 'actions.dart';
import 'design.dart';
import 'domain.dart';
import 'planner_data.dart';
import 'screens.dart';
import 'theme_settings.dart';

Future<void> showResetSettings(
  BuildContext context,
  HavenActions actions,
) async {
  final current = actions.store.state.taskReset;
  var frequency = current.frequency;
  var weekday = current.weekday;
  var time = TimeOfDay(hour: current.minute ~/ 60, minute: current.minute % 60);
  final resetNow = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        scrollable: true,
        title: const Text('Reset task checkmarks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Resets uncheck tasks. Your completion history and town progress are preserved.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ResetFrequency>(
              initialValue: frequency,
              decoration: const InputDecoration(labelText: 'Automatic reset'),
              items: const [
                DropdownMenuItem(value: ResetFrequency.off, child: Text('Off')),
                DropdownMenuItem(
                  value: ResetFrequency.daily,
                  child: Text('Daily'),
                ),
                DropdownMenuItem(
                  value: ResetFrequency.weekly,
                  child: Text('Weekly'),
                ),
              ],
              onChanged: (value) =>
                  refresh(() => frequency = value ?? frequency),
            ),
            if (frequency == ResetFrequency.weekly) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: weekday,
                decoration: const InputDecoration(labelText: 'Day'),
                items: [
                  for (var day = 1; day <= 7; day++)
                    DropdownMenuItem(
                      value: day,
                      child: Text(
                        MaterialLocalizations.of(context)
                            .formatFullDate(DateTime(2024, 1, day))
                            .split(',')
                            .first,
                      ),
                    ),
                ],
                onChanged: (value) => refresh(() => weekday = value ?? weekday),
              ),
            ],
            if (frequency != ResetFrequency.off) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (selected != null && context.mounted) {
                    refresh(() => time = selected);
                  }
                },
                icon: const Icon(Icons.schedule),
                label: Text(time.format(context)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Save schedule'),
          ),
        ],
      ),
    ),
  );
  if (resetNow == null || !context.mounted) return;
  await actions.run(
    context,
    (state) => state.copyWith(
      taskReset: TaskReset(
        frequency: frequency,
        weekday: weekday,
        minute: time.hour * 60 + time.minute,
        lastAt: DateTime.now().millisecondsSinceEpoch,
        cutoff: resetNow ? state.ledger.length : state.taskReset.cutoff,
        rechecked: resetNow ? const {} : state.taskReset.rechecked,
      ),
    ),
    success: resetNow
        ? 'Checkmarks reset. History kept.'
        : 'Reset schedule saved.',
  );
}

class DashboardOverview extends StatelessWidget {
  const DashboardOverview({
    super.key,
    required this.state,
    required this.today,
    required this.onCalendar,
    required this.onProjects,
    required this.onMoney,
  });
  final HavenState state;
  final String today;
  final VoidCallback onCalendar, onProjects, onMoney;

  @override
  Widget build(BuildContext context) {
    final date = dateFromKey(today);
    String? upcoming;
    for (var i = 0; i <= 30 && upcoming == null; i++) {
      final day = dayKey(calendarDay(date, i));
      final task = state
          .tasksFor(day)
          .where((task) => !state.completed(task, day))
          .firstOrNull;
      if (task != null && (i > 0 || task.reminderMinute != null)) {
        upcoming = '${task.title} · ${formattedDate(context, day)}';
      }
    }
    final month = today.substring(0, 7);
    final total = state.money
        .where((e) => e.day.startsWith(month))
        .fold(
          0,
          (sum, e) => sum + (e.kind == MoneyKind.income ? e.cents : -e.cents),
        );
    final done = state.projects.fold(
      0,
      (total, project) => total + state.projectCompleted(project.id),
    );
    final tasks = state.projects.fold(
      0,
      (total, project) => total + state.projectTasks(project.id).length,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, subtitle, icon, callback) in [
          (
            'Upcoming',
            upcoming ?? 'Nothing scheduled',
            Icons.event_outlined,
            onCalendar,
          ),
          (
            'Projects',
            state.projects.isEmpty
                ? 'No projects yet'
                : '$done of $tasks subtasks complete',
            Icons.folder_outlined,
            onProjects,
          ),
          (
            'Finances',
            '${euro(total)} net this month',
            Icons.account_balance_wallet_outlined,
            onMoney,
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                title: Text(title),
                subtitle: Text(subtitle, style: muted(context)),
                trailing: const Icon(Icons.chevron_right),
                onTap: callback,
              ),
            ),
          ),
      ],
    );
  }
}

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({
    super.key,
    required this.state,
    required this.actions,
    required this.today,
  });
  final HavenState state;
  final HavenActions actions;
  final String today;

  Future<void> edit(BuildContext context, [Project? item]) async {
    var title = item?.title ?? '';
    var due = item?.milestone;
    final project = await showDialog<Project>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          scrollable: true,
          title: Text(item == null ? 'New project' : 'Edit project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: title,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Project name'),
                onChanged: (value) => refresh(() => title = value),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.flag_outlined),
                label: Text(
                  due == null
                      ? 'Set milestone date'
                      : formattedDate(context, due!),
                ),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: dateFromKey(due ?? today),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100, 12, 31),
                  );
                  if (date != null && context.mounted) {
                    refresh(() => due = dayKey(date));
                  }
                },
              ),
              if (due != null)
                TextButton(
                  onPressed: () => refresh(() => due = null),
                  child: const Text('Clear milestone'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: title.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      Project(
                        item?.id ?? newId(),
                        title.trim(),
                        milestone: due,
                      ),
                    ),
              child: const Text('Save project'),
            ),
          ],
        ),
      ),
    );
    if (project == null || !context.mounted) return;
    await actions.run(
      context,
      (state) => state.copyWith(
        projects: [
          for (final old in state.projects)
            old.id == project.id ? project : old,
          if (item == null) project,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageIntro(
        'Projects',
        '',
        action: FilledButton.icon(
          onPressed: () => edit(context),
          icon: const Icon(Icons.add),
          label: const Text('New project'),
        ),
      ),
      if (state.projects.isEmpty)
        const EmptyPanel(
          'No projects yet',
          'Group related tasks and give your project a milestone.',
          icon: Icons.folder_outlined,
        ),
      for (final project in state.projects) ...[
        Panel(
          padding: const EdgeInsets.all(9),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 7),
            title: Text(project.title, style: displayStyle(context, size: 22)),
            subtitle: Text(
              [
                '${state.projectCompleted(project.id)} of ${state.projectTasks(project.id).length} complete',
                if (project.milestone case final day?)
                  formattedDate(context, day),
              ].join(' · '),
            ),
            children: [
              for (final task in state.projectTasks(project.id))
                TaskRow(
                  task,
                  today: today,
                  state: state,
                  actions: actions,
                  canComplete:
                      task.due.compareTo(today) <= 0 &&
                      (task.repeat == Repeat.once || task.occursOn(today)),
                ),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        actions.changeTask(context, today, null, project.id),
                    icon: const Icon(Icons.add),
                    label: const Text('Add subtask'),
                  ),
                  TextButton(
                    onPressed: () => edit(context, project),
                    child: const Text('Edit project'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
      ],
    ],
  );
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.state, required this.today});
  final HavenState state;
  final String today;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool monthly = false;
  int offset = 0;

  @override
  Widget build(BuildContext context) {
    final now = dateFromKey(widget.today);
    final from = monthly
        ? DateTime(now.year, now.month + offset)
        : calendarDay(localWeekStart(now), offset * 7);
    final days = monthly ? DateTime(from.year, from.month + 1, 0).day : 7;
    final until = dayKey(calendarDay(from, days));
    final first = dayKey(from);
    final state = widget.state;
    final progress = periodProgress(state, from, days, useSettlement: !monthly);
    final countByDay = <String, int>{};
    for (final entry in state.ledger) {
      if (entry.kind == LedgerKind.task &&
          entry.day.compareTo(first) >= 0 &&
          entry.day.compareTo(until) < 0) {
        countByDay.update(entry.day, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final peak = countByDay.values.fold(
      1,
      (highest, count) => count > highest ? count : highest,
    );
    final practices = state.sessions.where((e) {
      final day = dayKey(e.at.toLocal());
      return day.compareTo(first) >= 0 && day.compareTo(until) < 0;
    }).toList();
    final growth = state.expansion?.history ?? [];
    final history = growth.isEmpty && state.expansion?.lastWeek != null
        ? [state.expansion!.lastWeek!]
        : growth;
    final milestones = state.projects
        .where(
          (p) =>
              p.milestone != null &&
              p.milestone!.compareTo(first) >= 0 &&
              p.milestone!.compareTo(until) < 0,
        )
        .toList();
    final theme = Theme.of(context);
    final colors = palette(context);
    final bars = readableColor(
      colors[ThemeToken.progress],
      theme.colorScheme.surface,
      minRatio: 3,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageIntro(
          monthly ? 'Monthly report' : 'Weekly report',
          '',
          action: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Weekly'),
                selected: !monthly,
                onSelected: (_) => setState(() {
                  monthly = false;
                  offset = 0;
                }),
              ),
              ChoiceChip(
                label: const Text('Monthly'),
                selected: monthly,
                onSelected: (_) => setState(() {
                  monthly = true;
                  offset = 0;
                }),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous period',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => offset--),
                  ),
                  Expanded(
                    child: Text(
                      monthly
                          ? MaterialLocalizations.of(context)
                                .formatMonthYear(from)
                          : '${formattedDate(context, first)} to ${formattedDate(context, dayKey(calendarDay(from, 6)))}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next period',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: offset == 0
                        ? null
                        : () => setState(() => offset++),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 9,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${progress.percent}%',
                    style: displayStyle(context, size: 37),
                  ),
                  Text(
                    '${progress.completed} of ${progress.planned} tasks complete',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.fraction,
                semanticsLabel: 'Completion percentage',
              ),
              const SizedBox(height: 16),
              Text('Task activity', style: displayStyle(context, size: 21)),
              const SizedBox(height: 9),
              SizedBox(
                height: 83,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < days; i++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final day = dayKey(calendarDay(from, i));
                            final count = countByDay[day] ?? 0;
                            final label =
                                '${formattedDate(context, day)} · $count completed';
                            return Tooltip(
                              message: label,
                              child: Semantics(
                                label: label,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  height: count == 0 ? 3 : 83 * count / peak,
                                  decoration: BoxDecoration(
                                    color: count == 0 ? null : bars,
                                    border: Border.all(
                                      color: count == 0
                                          ? theme.colorScheme.outlineVariant
                                          : bars,
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
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
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${from.day}', style: muted(context)),
                  Text(
                    '${calendarDay(from, days - 1).day}',
                    style: muted(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Habit consistency', style: displayStyle(context, size: 23)),
              const SizedBox(height: 7),
              Text(
                '${practices.map((p) => dayKey(p.at.toLocal())).toSet().length} of $days days practiced',
              ),
              for (final hobby in state.hobbies.where((h) => !h.archived))
                Text(
                  '${hobby.name} · ${practices.where((e) => e.hobbyId == hobby.id).fold(0, (total, e) => total + e.minutes)} min',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Project milestones',
                style: displayStyle(context, size: 23),
              ),
              const SizedBox(height: 7),
              if (milestones.isEmpty)
                const Text('No milestones in this period.'),
              for (final project in milestones)
                Text(
                  '${project.title} · ${formattedDate(context, project.milestone!)}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Town growth history',
                style: displayStyle(context, size: 23),
              ),
              const SizedBox(height: 7),
              if (history.isEmpty)
                const Text('Growth is recorded at the end of each week.'),
              for (final week in history.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.holiday_village_outlined),
                  title: Text(formattedDate(context, week.week)),
                  subtitle: Text(
                    '${week.percent}% complete · ${week.buildings} built',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
