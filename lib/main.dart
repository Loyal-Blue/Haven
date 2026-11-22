import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'actions.dart';
import 'assistant.dart';
import 'assistant_screen.dart';
import 'cloud_appearance.dart';
import 'design.dart';
import 'planning.dart';
import 'reminders.dart';
import 'theme_settings.dart';
import 'domain.dart';
import 'screens.dart';
import 'store.dart';
import 'town.dart';
import 'update_widgets.dart';
import 'updates.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HavenBootstrap());
}

class HavenBootstrap extends StatefulWidget {
  const HavenBootstrap({super.key});

  @override
  State<HavenBootstrap> createState() => _HavenBootstrapState();
}

class _HavenBootstrapState extends State<HavenBootstrap> {
  late Future<(HavenStore, UpdateController?)> startup = _open();

  Future<(HavenStore, UpdateController?)> _open() async {
    final support = await getApplicationSupportDirectory();
    final store = await HavenStore.open(support);
    UpdateController? updates;
    try {
      updates = await UpdateController.load(
        support,
        await getTemporaryDirectory(),
      );
    } on Object {
      // Updater initialization is independent of the game save.
    }
    return (store, updates);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<(HavenStore, UpdateController?)>(
        future: startup,
        builder: (context, result) {
          if (result.hasData) {
            final (store, updates) = result.requireData;
            return HavenApp(store: store, updates: updates);
          }
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Haven',
            theme: havenTheme(Brightness.light),
            darkTheme: havenTheme(Brightness.dark),
            home: Scaffold(
              body: Center(
                child: result.hasError
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_off_outlined, size: 40),
                            const SizedBox(height: 12),
                            const Text(
                              'Haven could not open the local save.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () =>
                                  setState(() => startup = _open()),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : const CircularProgressIndicator(
                        semanticsLabel: 'Opening Haven',
                      ),
              ),
            ),
          );
        },
      );
}

class HavenApp extends StatelessWidget {
  const HavenApp({super.key, required this.store, this.updates});
  final HavenStore store;
  final UpdateController? updates;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final state = store.state;
      final appearance = state.appearance;
      final reduce =
          appearance.reducedMotion ||
          MediaQueryData.fromView(View.of(context)).disableAnimations;
      return MaterialApp(
        title: 'Haven',
        debugShowCheckedModeBanner: false,
        theme: havenTheme(Brightness.light, appearance),
        darkTheme: havenTheme(Brightness.dark, appearance),
        themeAnimationDuration: reduce || appearance.mono != Mono.off
            ? Duration.zero
            : const Duration(milliseconds: 220),
        themeMode: switch ((appearance.mono, appearance.preset, state.theme)) {
          (Mono.white, _, _) => ThemeMode.light,
          (Mono.black, _, _) => ThemeMode.dark,
          (_, ThemePreset.dark, _) => ThemeMode.dark,
          (_, _, ThemePreference.system) => ThemeMode.system,
          (_, _, ThemePreference.light) => ThemeMode.light,
          (_, _, ThemePreference.dark) => ThemeMode.dark,
        },
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  media.disableAnimations || appearance.reducedMotion,
              textScaler: _FontScaler(media.textScaler, appearance.fontScale),
            ),
            child: child!,
          );
        },
        home: HavenShell(store: store, updates: updates),
      );
    },
  );
}

class _FontScaler extends TextScaler {
  const _FontScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => system.scale(1) * factor;
  @override
  bool operator ==(Object other) =>
      other is _FontScaler && other.system == system && other.factor == factor;
  @override
  int get hashCode => Object.hash(system, factor);
}

enum Destination {
  town('Town', Icons.holiday_village_outlined, ThemeToken.primary),
  tasks('Todo', Icons.check_circle_outline_rounded, ThemeToken.todo),
  routine('Routine', Icons.repeat_rounded, ThemeToken.routine),
  planner('Event', Icons.calendar_month_outlined, ThemeToken.event),
  my('My', Icons.person_outline_rounded, ThemeToken.my),
  more('More', Icons.grid_view_outlined, ThemeToken.more),
  money('Money', Icons.account_balance_wallet_outlined, ThemeToken.my),
  projects('Projects', Icons.folder_outlined, ThemeToken.my),
  reports('Reports', Icons.bar_chart_rounded, ThemeToken.my),
  assistant('AI', Icons.auto_awesome_outlined, ThemeToken.more);

  const Destination(this.label, this.icon, this.token);
  final String label;
  final IconData icon;
  final ThemeToken token;

  Destination get section => switch (this) {
    money || projects || reports => my,
    assistant => more,
    _ => this,
  };
}

const sideDestinations = [
  Destination.tasks,
  Destination.routine,
  Destination.planner,
  Destination.my,
  Destination.more,
];

const bottomDestinations = [
  Destination.town,
  Destination.tasks,
  Destination.planner,
  Destination.my,
  Destination.more,
];

class HavenShell extends StatefulWidget {
  const HavenShell({super.key, required this.store, this.updates});
  final HavenStore store;
  final UpdateController? updates;

  @override
  State<HavenShell> createState() => _HavenShellState();
}

class _HavenShellState extends State<HavenShell> with WidgetsBindingObserver {
  Destination destination = Destination.town;
  int district = 0;
  late String today;
  late Timer dateTimer;
  late AssistantSession assistant;
  late AppearanceCloud cloud;
  final reminders = TaskReminders();
  final shownReminders = <String>{};

  HavenActions get actions => HavenActions(widget.store);

  @override
  void initState() {
    super.initState();
    today = dayKey(DateTime.now());
    assistant = AssistantSession(
      File('${widget.store.file.parent.path}/assistant.json'),
    );
    unawaited(assistant.load());
    cloud = AppearanceCloud(widget.store);
    unawaited(cloud.start());
    widget.store.addListener(refreshReminders);
    refreshReminders();
    dateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      refreshDay();
      unawaited(widget.updates?.check());
    });
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.updates?.check());
  }

  @override
  void dispose() {
    dateTimer.cancel();
    assistant.dispose();
    cloud.dispose();
    widget.store.removeListener(refreshReminders);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void refreshReminders({bool scheduleNative = true}) {
    final now = DateTime.now();
    final state = widget.store.state;
    if (TaskReminders.native) {
      if (scheduleNative) unawaited(reminders.sync(state, now));
    } else {
      final day = dayKey(now);
      if (day != today) shownReminders.clear();
      final minute = now.hour * 60 + now.minute;
      final due = state
          .tasksFor(day)
          .where(
            (task) =>
                task.reminderMinute == minute &&
                !state.completed(task, day) &&
                shownReminders.add(task.id),
          );
      final titles = due.map((task) => task.title).toList();
      if (titles.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showNotice(context, 'Reminder · ${titles.join(', ')}');
        });
      }
    }
  }

  void refreshDay() {
    final now = DateTime.now();
    final date = dayKey(now);
    refreshReminders(scheduleNative: today != date);
    if (today != date && mounted) setState(() => today = date);
    final expansion = widget.store.state.expansion;
    if (expansion == null ||
        date.compareTo(expansion.nextMonday) >= 0 ||
        widget.store.state.taskReset.due(now) != null) {
      unawaited(refreshExpansion(now));
    }
  }

  Future<void> refreshExpansion(DateTime now) async {
    try {
      await widget.store.commit(
        (state) => applyTaskReset(advanceTownExpansion(state, now), now),
      );
    } catch (error, stack) {
      debugPrintStack(
        label:
            'Could not save the weekly town expansion (${error.runtimeType}).',
        stackTrace: stack,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshDay();
      unawaited(cloud.sync());
      unawaited(widget.updates?.check());
    }
  }

  void selectTab(Destination value) => setState(() => destination = value);

  void selectDistrict(int value) {
    if (value < 0 || value >= widget.store.state.districtCount) return;
    setState(() => district = value);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 880;
      final tabsVisible = wide || constraints.maxWidth >= 390;
      final reduced = MediaQuery.disableAnimationsOf(context);
      return Scaffold(
        drawer: tabsVisible
            ? null
            : Drawer(
                child: SafeArea(
                  child: _SideTabs(
                    current: destination,
                    onSelect: (value) {
                      Navigator.of(context).pop();
                      selectTab(value);
                    },
                    wide: true,
                  ),
                ),
              ),
        body: SafeArea(
          bottom: wide,
          child: Row(
            children: [
              if (tabsVisible)
                SizedBox(
                  width: wide ? 157 : 49,
                  child: _SideTabs(
                    current: destination,
                    onSelect: selectTab,
                    wide: wide,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (!wide)
                      Builder(
                        builder: (context) => _MobileHeader(
                          onMenu: tabsVisible
                              ? null
                              : Scaffold.of(context).openDrawer,
                          onSettings: () => selectTab(Destination.more),
                        ),
                      ),
                    if (destination != Destination.more &&
                        widget.updates != null)
                      UpdateNotice(
                        widget.updates!,
                        openSettings: () => selectTab(Destination.more),
                      ),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: widget.store,
                        builder: (context, _) {
                          final state = widget.store.state;
                          return AnimatedSwitcher(
                            duration: reduced
                                ? Duration.zero
                                : const Duration(milliseconds: 170),
                            child: SingleChildScrollView(
                              key: PageStorageKey(destination),
                              padding: EdgeInsets.fromLTRB(
                                wide ? 32 : 10,
                                wide ? 26 : 13,
                                wide ? 32 : 13,
                                18,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: destination == Destination.town
                                        ? 1160
                                        : 770,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: switch (destination) {
                                      Destination.town => _town(
                                        context,
                                        state,
                                        wide,
                                      ),
                                      Destination.tasks ||
                                      Destination.routine => TasksScreen(
                                        state: state,
                                        actions: actions,
                                        today: today,
                                        routines:
                                            destination == Destination.routine,
                                        onPhoto: () =>
                                            selectTab(Destination.assistant),
                                      ),
                                      Destination.planner => PlannerScreen(
                                        state: state,
                                        actions: actions,
                                        today: today,
                                      ),
                                      Destination.money => MoneyScreen(
                                        state: state,
                                        actions: actions,
                                        today: today,
                                      ),
                                      Destination.projects => ProjectsScreen(
                                        state: state,
                                        actions: actions,
                                        today: today,
                                      ),
                                      Destination.reports => ReportsScreen(
                                        state: state,
                                        today: today,
                                      ),
                                      Destination.assistant => AssistantScreen(
                                        session: assistant,
                                        state: state,
                                        actions: actions,
                                      ),
                                      Destination.my => _Hub(
                                        title: 'My Haven',
                                        items: const [
                                          Destination.projects,
                                          Destination.reports,
                                          Destination.money,
                                        ],
                                        onSelect: selectTab,
                                      ),
                                      Destination.more => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _Hub(
                                            title: 'More',
                                            items: const [
                                              Destination.assistant,
                                            ],
                                            onSelect: selectTab,
                                          ),
                                          const SizedBox(height: 15),
                                          MoreScreen(
                                            updates: widget.updates,
                                            cloud: cloud,
                                            state: state,
                                            actions: actions,
                                            today: today,
                                          ),
                                        ],
                                      ),
                                    },
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
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : _MobileNav(current: destination, onSelect: selectTab),
      );
    },
  );

  Widget _town(BuildContext context, HavenState state, bool wide) {
    final due = state.tasksFor(today, includeOverdue: true);
    final done = due.where((task) => state.checked(task, today)).length;
    final showing = [...due]
      ..sort(
        (a, b) => (state.checked(a, today) ? 1 : 0).compareTo(
          state.checked(b, today) ? 1 : 0,
        ),
      );
    final progress = weeklyProgress(state, localWeekStart(dateFromKey(today)));
    final map = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DistrictNavigation(
          district: district,
          count: state.districtCount,
          nextMonday: state.expansion?.nextMonday,
          onSelect: selectDistrict,
        ),
        const SizedBox(height: 8),
        TownMap(
          key: ValueKey(district),
          wide: wide,
          district: district,
          buildings: state.buildings
              .where((building) => building.district == district)
              .toList(),
          title: state.townName,
          level: 1 + (state.buildings.length - 1) ~/ 3,
        ),
      ],
    );
    final daily = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeeklyConstruction(
          progress: progress,
          lastWeek: state.expansion?.lastWeek,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text('Today', style: displayStyle(context, size: 29)),
            ),
            TextButton(
              onPressed: () => selectTab(Destination.tasks),
              child: const Text('All tasks'),
            ),
          ],
        ),
        if (due.isNotEmpty) ...[
          Text('$done of ${due.length} tasks complete', style: muted(context)),
          const SizedBox(height: 9),
          TaskListPanel(
            tasks: showing.take(4).toList(),
            state: state,
            actions: actions,
            today: today,
          ),
        ] else ...[
          const EmptyPanel(
            'Room to breathe',
            'Your tasks for today will appear here.',
            icon: Icons.eco_outlined,
          ),
          TextButton.icon(
            onPressed: () => actions.changeTask(context, today),
            icon: const Icon(Icons.add),
            label: const Text('New task'),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your town', style: displayStyle(context, size: wide ? 43 : 32)),
        const SizedBox(height: 4),
        Text(formattedDate(context, today), style: muted(context)),
        const SizedBox(height: 16),
        map,
        const SizedBox(height: 14),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: daily),
              const SizedBox(width: 17),
              Expanded(flex: 2, child: _overview(state)),
            ],
          )
        else ...[
          daily,
          const SizedBox(height: 14),
          _overview(state),
        ],
      ],
    );
  }

  Widget _overview(HavenState state) => DashboardOverview(
    state: state,
    today: today,
    onCalendar: () => selectTab(Destination.planner),
    onProjects: () => selectTab(Destination.projects),
    onMoney: () => selectTab(Destination.money),
  );
}

class _WeeklyConstruction extends StatelessWidget {
  const _WeeklyConstruction({required this.progress, this.lastWeek});

  final WeekProgress progress;
  final WeekProgress? lastWeek;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Weekly construction',
                style: displayStyle(context, size: 21),
              ),
            ),
            Text(
              '${progress.percent}%',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.fraction,
          borderRadius: BorderRadius.circular(8),
          semanticsLabel: 'Weekly task completion',
        ),
        const SizedBox(height: 8),
        Text(
          '${progress.completed} of ${progress.planned} tasks complete',
          style: muted(context),
        ),
        const SizedBox(height: 3),
        Text(
          '${progress.buildings} projected ${progress.buildings == 1 ? 'building' : 'buildings'} for Sunday night',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (lastWeek case final week?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Last week · ${week.percent}% complete · ${week.buildings} built',
              style: muted(context),
            ),
          ),
      ],
    ),
  );
}

class _Hub extends StatelessWidget {
  const _Hub({
    required this.title,
    required this.items,
    required this.onSelect,
  });
  final String title;
  final List<Destination> items;
  final ValueChanged<Destination> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageIntro(title, ''),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            for (final item in items)
              ListTile(
                leading: Icon(item.icon),
                title: Text(
                  item == Destination.assistant ? 'Haven AI' : item.label,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelect(item),
              ),
          ],
        ),
      ),
    ],
  );
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.landscape_outlined,
            color: scheme.onPrimary,
            size: 21,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Haven',
            overflow: TextOverflow.ellipsis,
            style: displayStyle(context, size: 23),
          ),
        ),
      ],
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({this.onMenu, required this.onSettings});
  final VoidCallback? onMenu;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 2, 5, 1),
    child: Row(
      children: [
        if (onMenu != null)
          IconButton(
            onPressed: onMenu,
            tooltip: 'Open side tabs',
            icon: const Icon(Icons.menu),
          ),
        const Expanded(child: _Wordmark()),
        IconButton(
          onPressed: onSettings,
          tooltip: 'Settings and hobbies',
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
  );
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.current, required this.onSelect});
  final Destination current;
  final ValueChanged<Destination> onSelect;
  @override
  Widget build(BuildContext context) {
    final colors = palette(context);
    final nav = colors[ThemeToken.navigation];
    final ink = readableColor(colors[ThemeToken.text], nav);
    final selected = current == Destination.routine
        ? Destination.tasks
        : current.section;
    final larger = MediaQuery.textScalerOf(context).scale(11) >= 16;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(7, 0, 7, 6),
      child: Material(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w700),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? readableColor(ink, colors[selected.token])
                    : ink,
                size: 23,
              ),
            ),
          ),
          child: NavigationBar(
            height: 61,
            animationDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : null,
            backgroundColor: nav,
            indicatorColor: colors[selected.token],
            selectedIndex: bottomDestinations.indexOf(selected),
            labelBehavior: larger
                ? NavigationDestinationLabelBehavior.alwaysHide
                : NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) =>
                onSelect(bottomDestinations[index]),
            destinations: [
              for (final item in bottomDestinations)
                NavigationDestination(
                  key: ValueKey(item),
                  icon: Icon(item.icon),
                  label: item.label,
                  tooltip: item.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideTabs extends StatelessWidget {
  const _SideTabs({
    required this.current,
    required this.onSelect,
    required this.wide,
  });
  final Destination current;
  final ValueChanged<Destination> onSelect;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = palette(context);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        wide ? 13 : 1,
        wide ? 20 : 56,
        wide ? 3 : 0,
        12,
      ),
      children: [
        if (wide) ...[const _Wordmark(), const SizedBox(height: 23)],
        for (final item in [if (wide) Destination.town, ...sideDestinations])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Builder(
              builder: (context) {
                final selected = item == current.section;
                final color = colors.monochrome
                    ? (selected
                          ? colors[ThemeToken.text]
                          : colors[ThemeToken.navigation])
                    : Color.lerp(
                        colors[ThemeToken.navigation],
                        colors[item.token],
                        selected ? 1 : .52,
                      )!;
                final ink = readableColor(colors[ThemeToken.text], color);
                final label = Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontSize: wide ? 14 : 12,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  ),
                );
                return Semantics(
                  selected: selected,
                  button: true,
                  label: item.label,
                  child: ExcludeSemantics(
                    child: Material(
                      color: color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(wide ? 13 : 9),
                        side: BorderSide(
                          color: selected ? ink : scheme.outlineVariant,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelect(item),
                        child: wide
                            ? ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(item.icon, color: ink, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(child: label),
                                    ],
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: 74,
                                width: 48,
                                child: Center(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: MediaQuery.withClampedTextScaling(
                                      maxScaleFactor: 1.35,
                                      child: label,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
