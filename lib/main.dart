import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'actions.dart';
import 'assistant.dart';
import 'assistant_screen.dart';
import 'design.dart';
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
    builder: (context, _) => MaterialApp(
      title: 'Haven',
      debugShowCheckedModeBanner: false,
      theme: havenTheme(Brightness.light),
      darkTheme: havenTheme(Brightness.dark),
      themeMode: switch (store.state.theme) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      home: HavenShell(store: store, updates: updates),
    ),
  );
}

enum Destination {
  town('Town', Icons.holiday_village_outlined, Icons.holiday_village_rounded),
  tasks(
    'Tasks',
    Icons.check_circle_outline_rounded,
    Icons.check_circle_rounded,
  ),
  planner(
    'Planner',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
  ),
  money(
    'Money',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet_rounded,
  ),
  assistant('AI', Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
  more('More', Icons.grid_view_outlined, Icons.grid_view_rounded);

  const Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

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

  HavenActions get actions => HavenActions(widget.store);

  @override
  void initState() {
    super.initState();
    today = dayKey(DateTime.now());
    assistant = AssistantSession(
      File('${widget.store.file.parent.path}/assistant.json'),
    );
    unawaited(assistant.load());
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void refreshDay() {
    final now = DateTime.now();
    final date = dayKey(now);
    if (today != date && mounted) setState(() => today = date);
    final expansion = widget.store.state.expansion;
    if (expansion == null || date.compareTo(expansion.nextMonday) >= 0) {
      unawaited(refreshExpansion(now));
    }
  }

  Future<void> refreshExpansion(DateTime now) async {
    try {
      await widget.store.commit((state) => advanceTownExpansion(state, now));
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
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (wide)
                SizedBox(
                  width: 151,
                  child: _DesktopRail(
                    current: destination,
                    onSelect: selectTab,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (!wide)
                      _MobileHeader(
                        onSettings: () => selectTab(Destination.more),
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
                          return SingleChildScrollView(
                            key: PageStorageKey(destination),
                            padding: EdgeInsets.fromLTRB(
                              wide ? 30 : 18,
                              wide ? 30 : 15,
                              wide ? 30 : 18,
                              18,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: destination == Destination.town
                                      ? 1180
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
                                    Destination.tasks => TasksScreen(
                                      state: state,
                                      actions: actions,
                                      today: today,
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
                                    Destination.assistant => AssistantScreen(
                                      session: assistant,
                                      state: state,
                                    ),
                                    Destination.more => MoreScreen(
                                      updates: widget.updates,
                                      state: state,
                                      actions: actions,
                                      today: today,
                                    ),
                                  },
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
    final done = due.where((task) => state.completed(task, today)).length;
    final showing = [...due]
      ..sort(
        (a, b) => (state.completed(a, today) ? 1 : 0).compareTo(
          state.completed(b, today) ? 1 : 0,
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
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: map),
              const SizedBox(width: 22),
              Expanded(flex: 2, child: daily),
            ],
          )
        else ...[
          map,
          const SizedBox(height: 14),
          daily,
        ],
      ],
    );
  }
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

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: graphite,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.landscape_outlined, color: railText, size: 22),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          'Haven',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: displayStyle(
            context,
            size: 19,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Material(
    color: panelColor(context),
    shape: Border(
      bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(17, 2, 9, 2),
      child: Row(
        children: [
          const _Wordmark(),
          const Spacer(),
          IconButton(
            onPressed: onSettings,
            tooltip: 'Settings and hobbies',
            icon: const Icon(Icons.tune_rounded, size: 22),
          ),
        ],
      ),
    ),
  );
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.current, required this.onSelect});
  final Destination current;
  final ValueChanged<Destination> onSelect;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(9, 0, 9, 7),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(
              color: railText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? graphite
                  : railText,
              size: 23,
            ),
          ),
        ),
        child: NavigationBar(
          height: 66,
          backgroundColor: graphite,
          indicatorColor: silverMint,
          selectedIndex: current.index,
          onDestinationSelected: (index) => onSelect(Destination.values[index]),
          destinations: [
            for (final item in Destination.values)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    ),
  );
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.current, required this.onSelect});
  final Destination current;
  final ValueChanged<Destination> onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 13, 0, 13),
    child: Panel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: _Wordmark(),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Material(
                color: graphite,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in Destination.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Semantics(
                            selected: item == current,
                            child: TextButton.icon(
                              icon: Icon(
                                item == current ? item.selectedIcon : item.icon,
                                size: 18,
                              ),
                              label: Text(
                                item.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () => onSelect(item),
                              style: TextButton.styleFrom(
                                foregroundColor: item == current
                                    ? graphite
                                    : railText,
                                backgroundColor: item == current
                                    ? silverMint
                                    : null,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.offline_pin_outlined, size: 15),
              const SizedBox(width: 5),
              Flexible(
                child: Text('Local save', style: muted(context, size: 12)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
