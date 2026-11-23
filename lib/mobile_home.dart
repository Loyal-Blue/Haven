import 'package:material_ui/material_ui.dart';

import 'actions.dart';
import 'design.dart';
import 'domain.dart';
import 'mobile_preferences.dart';
import 'mobile_widgets.dart';
import 'screens.dart';
import 'town.dart';

class PhoneGreeting extends StatelessWidget {
  const PhoneGreeting({
    super.key,
    required this.name,
    required this.today,
    required this.onMore,
  });
  final String name, today;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final background = phoneCardColor(context, DashboardCard.hobbies);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: PhoneStyle.maxPageWidth + PhoneStyle.edge * 2,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PhoneStyle.edge,
            12,
            PhoneStyle.edge,
            6,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MaterialLocalizations.of(context)
                          .formatFullDate(dateFromKey(today)),
                      style: muted(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name.isEmpty ? 'Welcome to Haven' : 'Hi, $name',
                      style: displayStyle(context, size: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'More and settings',
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(PhoneStyle.touch),
                  backgroundColor: background,
                  foregroundColor: phoneInk(context, background),
                ),
                onPressed: onMore,
                icon: name.isEmpty
                    ? const Icon(Icons.person_outline_rounded)
                    : Text(
                        name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhoneDashboard extends StatelessWidget {
  const PhoneDashboard({
    super.key,
    required this.state,
    required this.actions,
    required this.today,
    required this.day,
    required this.district,
    required this.onDay,
    required this.onDistrict,
    required this.onCard,
    required this.onReports,
  });

  final HavenState state;
  final HavenActions actions;
  final String today, day;
  final int district;
  final ValueChanged<String> onDay;
  final ValueChanged<int> onDistrict;
  final VoidCallback onReports;
  final ValueChanged<DashboardCard> onCard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = palette(context);
    final week = localWeekStart(dateFromKey(today));
    final progress = weeklyProgress(state, week);
    final tasks = state.tasksFor(day, includeOverdue: day == today);
    bool done(Task task) =>
        day == today ? state.checked(task, day) : state.completed(task, day);
    final completed = tasks.where(done).length;
    final showing = [...tasks]
      ..sort((a, b) => (done(a) ? 1 : 0).compareTo(done(b) ? 1 : 0));
    final cards = state.mobile.order;
    final towns = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section('Your town', action: 'Progress', onTap: onReports),
        Material(
          color: phoneCardColor(context, DashboardCard.town),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PhoneStyle.radius),
            side: colors.monochrome
                ? BorderSide(color: scheme.outlineVariant)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 12, 8),
                child: _TownProgress(state: state, progress: progress),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: TownMap(
                  key: ValueKey(district),
                  district: district,
                  buildings: state.buildings
                      .where((building) => building.district == district)
                      .toList(),
                  title: state.townName,
                  level: 1 + (state.buildings.length - 1) ~/ 3,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 5, 7, 7),
                child: DistrictNavigation(
                  district: district,
                  count: state.districtCount,
                  nextMonday: state.expansion?.nextMonday,
                  onSelect: onDistrict,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    Widget shortcuts(List<DashboardCard> items) => _QuickCards(
      items: items,
      state: state,
      day: day,
      today: today,
      completed: completed,
      taskCount: tasks.length,
      onCard: onCard,
    );
    final index = cards.indexOf(DashboardCard.town);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhoneWeek(week: week, selected: day, today: today, onSelect: onDay),
        const SizedBox(height: PhoneStyle.section),
        if (index > 0) ...[
          shortcuts(cards.take(index).toList()),
          const SizedBox(height: PhoneStyle.section),
        ],
        towns,
        if (index < cards.length - 1) ...[
          const SizedBox(height: PhoneStyle.section),
          shortcuts(cards.skip(index + 1).toList()),
        ],
        const SizedBox(height: PhoneStyle.section),
        _Section(
          day == today
              ? 'Today’s tasks'
              : 'Tasks on ${formattedDate(context, day)}',
          action: 'View all',
          onTap: () => onCard(
            day == today ? DashboardCard.tasks : DashboardCard.calendar,
          ),
        ),
        if (tasks.isEmpty)
          const EmptyPanel(
            'Nothing scheduled',
            'Add a task to plan your day.',
            icon: Icons.event_available_outlined,
          )
        else
          TaskListPanel(
            tasks: showing.take(4).toList(),
            state: state,
            actions: actions,
            today: today,
            occurrence: day,
            canComplete: day == today,
          ),
      ],
    );
  }
}

class _TownProgress extends StatelessWidget {
  const _TownProgress({required this.state, required this.progress});
  final HavenState state;
  final WeekProgress progress;

  @override
  Widget build(BuildContext context) {
    final background = phoneCardColor(context, DashboardCard.town);
    final ink = phoneInk(context, background);
    return DefaultTextStyle.merge(
      style: TextStyle(color: ink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weekly progress',
                  style: displayStyle(context, size: 21).copyWith(color: ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${progress.percent}%',
                style: displayStyle(context, size: 26).copyWith(color: ink),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PhoneProgress(
            value: progress.fraction,
            label: 'Weekly task completion',
            color: ink,
          ),
          const SizedBox(height: 8),
          Text(
            '${progress.completed} of ${progress.planned} tasks complete',
            style: muted(context),
          ),
          Text(
            '${progress.buildings} projected ${progress.buildings == 1 ? 'building' : 'buildings'} for Sunday night',
            style: muted(context),
          ),
          if (state.expansion?.lastWeek case final previous?)
            Text(
              'Last week · ${previous.buildings} built · ${previous.percent}%',
              style: muted(context),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(title, style: displayStyle(context, size: 23))),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}

class _QuickCards extends StatelessWidget {
  const _QuickCards({
    required this.items,
    required this.state,
    required this.today,
    required this.day,
    required this.completed,
    required this.taskCount,
    required this.onCard,
  });

  final List<DashboardCard> items;
  final HavenState state;
  final String today, day;
  final int completed, taskCount;
  final ValueChanged<DashboardCard> onCard;

  @override
  Widget build(BuildContext context) {
    final month = today.substring(0, 7);
    final balance = state.money
        .where((entry) => entry.day.startsWith('$month-'))
        .fold(
          0,
          (sum, entry) =>
              sum +
              (entry.kind == MoneyKind.income ? entry.cents : -entry.cents),
        );
    final hobbies = state.hobbies.where((hobby) => !hobby.archived).length;
    final routines = state.tasks
        .where((task) => !task.archived && task.repeat != Repeat.once)
        .length;
    final planned = state.tasksFor(day).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Section('Quick access'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final card in items) ...[
                  if (card != items.first) const SizedBox(width: 10),
                  Builder(
                    builder: (context) {
                      final (icon, subtitle) = switch (card) {
                        DashboardCard.town => (
                          Icons.holiday_village_outlined,
                          state.townName,
                        ),
                        DashboardCard.tasks => (
                          Icons.task_alt_outlined,
                          '$completed of $taskCount complete',
                        ),
                        DashboardCard.money => (
                          Icons.account_balance_wallet_outlined,
                          '${euro(balance)} this month',
                        ),
                        DashboardCard.hobbies => (
                          Icons.eco_outlined,
                          '$hobbies hobbies · $routines routines',
                        ),
                        DashboardCard.assistant => (
                          Icons.auto_awesome_outlined,
                          'Plan your day or add photo tasks',
                        ),
                        DashboardCard.calendar => (
                          Icons.event_outlined,
                          '$planned planned · ${formattedDate(context, day)}',
                        ),
                      };
                      final color = phoneCardColor(context, card);
                      final ink = phoneInk(context, color);
                      return SizedBox(
                        width: 154,
                        child: Material(
                          color: color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              PhoneStyle.radius,
                            ),
                            side: palette(context).monochrome
                                ? BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  )
                                : BorderSide.none,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onCard(card),
                            child: Padding(
                              padding: const EdgeInsets.all(13),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: ink.withValues(alpha: .09),
                                    foregroundColor: ink,
                                    child: Icon(icon, size: 19),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    card.label,
                                    style: TextStyle(
                                      color: ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(color: ink, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
