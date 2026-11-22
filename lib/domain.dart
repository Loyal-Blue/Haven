import 'dart:math';

typedef Json = Map<String, dynamic>;

String newId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime calendarDay(DateTime date, [int offset = 0]) =>
    DateTime(date.year, date.month, date.day + offset);

DateTime dateFromKey(String key) => DateTime.parse(key);

DateTime localWeekStart(DateTime date) {
  final local = date.toLocal();
  return calendarDay(local, DateTime.monday - local.weekday);
}

class WeekProgress {
  const WeekProgress(this.week, this.completed, this.planned);

  static const maxBuildings = 5;
  final String week;
  final int completed;
  final int planned;

  double get fraction => planned == 0 ? 0 : completed / planned;
  int get percent => planned == 0 ? 0 : completed * 100 ~/ planned;
  int get buildings =>
      completed == 0 ? 0 : (completed * maxBuildings + planned - 1) ~/ planned;

  Json toJson() => {'week': week, 'completed': completed, 'planned': planned};

  static WeekProgress fromJson(Json json) => WeekProgress(
    json['week'] as String,
    json['completed'] as int,
    json['planned'] as int,
  );
}

class TownExpansion {
  const TownExpansion(
    this.throughWeek, {
    this.districtCount = 1,
    this.lastWeek,
    this.automatic = true,
  });

  final String throughWeek;
  final int districtCount;
  final WeekProgress? lastWeek;
  final bool automatic;

  String get nextMonday => dayKey(calendarDay(dateFromKey(throughWeek), 7));

  Json toJson() => {
    'throughWeek': throughWeek,
    'districtCount': districtCount,
    'automatic': automatic,
    if (lastWeek != null) 'lastWeek': lastWeek!.toJson(),
  };

  static TownExpansion fromJson(Json json) => TownExpansion(
    json['throughWeek'] as String,
    districtCount: json['districtCount'] as int,
    automatic: json['automatic'] == true,
    lastWeek: json['lastWeek'] == null
        ? null
        : WeekProgress.fromJson(json['lastWeek'] as Json),
  );
}

enum ThemePreference { system, light, dark }

enum Effort {
  light('Light', Resources(6, 3, 2, 4)),
  steady('Steady', Resources(12, 6, 4, 8)),
  deep('Deep', Resources(20, 10, 6, 12));

  const Effort(this.label, this.reward);
  final String label;
  final Resources reward;
}

enum Repeat {
  once('Once'),
  daily('Daily'),
  weekly('Weekly');

  const Repeat(this.label);
  final String label;
}

enum TaskCategory {
  home('Home'),
  school('School'),
  personal('Personal'),
  work('Work');

  const TaskCategory(this.label);
  final String label;
}

class Resources {
  const Resources(this.wood, this.stone, this.seeds, this.coins);

  static const zero = Resources(0, 0, 0, 0);
  static const dailyCap = Resources(60, 30, 20, 36);
  final int wood;
  final int stone;
  final int seeds;
  final int coins;

  Resources operator +(Resources other) => Resources(
    wood + other.wood,
    stone + other.stone,
    seeds + other.seeds,
    coins + other.coins,
  );

  Resources operator -(Resources other) => Resources(
    wood - other.wood,
    stone - other.stone,
    seeds - other.seeds,
    coins - other.coins,
  );

  bool covers(Resources other) =>
      wood >= other.wood &&
      stone >= other.stone &&
      seeds >= other.seeds &&
      coins >= other.coins;

  Resources limitedBy(Resources limit) => Resources(
    wood.clamp(0, max(0, limit.wood)),
    stone.clamp(0, max(0, limit.stone)),
    seeds.clamp(0, max(0, limit.seeds)),
    coins.clamp(0, max(0, limit.coins)),
  );

  bool get isZero => wood == 0 && stone == 0 && seeds == 0 && coins == 0;

  List<int> toJson() => [wood, stone, seeds, coins];
  static Resources fromJson(List<dynamic> values) => Resources(
    values[0] as int,
    values[1] as int,
    values[2] as int,
    values[3] as int,
  );
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.due,
    this.category = TaskCategory.personal,
    this.effort = Effort.steady,
    this.repeat = Repeat.once,
    this.notes = '',
    this.archived = false,
    this.createdOn,
    this.archivedOn,
  });

  final String id;
  final String title;
  final String due;
  final TaskCategory category;
  final Effort effort;
  final Repeat repeat;
  final String notes;
  final bool archived;
  final String? createdOn;
  final String? archivedOn;

  bool occursOn(String day) => !archived && scheduledOn(day);

  bool scheduledOn(String day) {
    if (day.compareTo(due) < 0) return false;
    return switch (repeat) {
      Repeat.once => day == due,
      Repeat.daily => true,
      Repeat.weekly => dateFromKey(day).weekday == dateFromKey(due).weekday,
    };
  }

  String occurrence(String day) => repeat == Repeat.once ? 'once' : day;

  Task archive(String day) => Task(
    id: id,
    title: title,
    due: due,
    category: category,
    effort: effort,
    repeat: repeat,
    notes: notes,
    archived: true,
    createdOn: createdOn,
    archivedOn: archivedOn ?? day,
  );

  Json toJson() => {
    'id': id,
    'title': title,
    'due': due,
    'category': category.name,
    'effort': effort.name,
    'repeat': repeat.name,
    'notes': notes,
    'archived': archived,
    if (createdOn != null) 'createdOn': createdOn,
    if (archivedOn != null) 'archivedOn': archivedOn,
  };

  static Task fromJson(Json json) => Task(
    id: json['id'],
    title: json['title'],
    due: json['due'],
    category: TaskCategory.values.byName(json['category']),
    effort: Effort.values.byName(json['effort']),
    repeat: Repeat.values.byName(json['repeat']),
    notes: json['notes'],
    archived: json['archived'],
    createdOn: json['createdOn'] as String?,
    archivedOn: json['archivedOn'] as String?,
  );
}

enum LedgerKind { task, hobby, building }

class LedgerEntry {
  const LedgerEntry(
    this.id,
    this.kind,
    this.sourceId,
    this.day,
    this.at,
    this.delta,
  );

  final String id;
  final LedgerKind kind;
  final String sourceId;
  final String day;
  final DateTime at;
  final Resources delta;

  Json toJson() => {
    'id': id,
    'kind': kind.name,
    'sourceId': sourceId,
    'day': day,
    'at': at.toUtc().toIso8601String(),
    'delta': delta.toJson(),
  };

  static LedgerEntry fromJson(Json json) => LedgerEntry(
    json['id'],
    LedgerKind.values.byName(json['kind']),
    json['sourceId'],
    json['day'],
    DateTime.parse(json['at']),
    Resources.fromJson(json['delta']),
  );
}

enum Building { cottage, garden, orchard, well, workshop }

typedef Plot = ({int x, int y});

const buildablePlots = <Plot>[
  (x: 1, y: 1),
  (x: 2, y: 1),
  (x: 3, y: 1),
  (x: 6, y: 1),
  (x: 7, y: 1),
  (x: 8, y: 1),
  (x: 9, y: 1),
  (x: 2, y: 2),
  (x: 3, y: 2),
  (x: 6, y: 2),
  (x: 7, y: 2),
  (x: 8, y: 2),
  (x: 9, y: 2),
  (x: 2, y: 3),
  (x: 3, y: 3),
  (x: 6, y: 3),
  (x: 7, y: 3),
  (x: 8, y: 3),
  (x: 9, y: 3),
  (x: 1, y: 5),
  (x: 2, y: 5),
  (x: 3, y: 5),
  (x: 4, y: 5),
  (x: 6, y: 5),
  (x: 7, y: 5),
  (x: 9, y: 5),
  (x: 2, y: 6),
  (x: 3, y: 6),
  (x: 4, y: 6),
  (x: 6, y: 6),
  (x: 7, y: 6),
];

class PlacedBuilding {
  const PlacedBuilding(this.id, this.building, this.plot, {this.district = 0});
  final String id;
  final Building building;
  final Plot plot;
  final int district;

  Json toJson() => {
    'id': id,
    'building': building.name,
    'x': plot.x,
    'y': plot.y,
    'district': district,
  };
  static PlacedBuilding fromJson(Json json) => PlacedBuilding(
    json['id'],
    Building.values.byName(json['building']),
    (x: json['x'], y: json['y']),
    district: json['district'] as int? ?? 0,
  );
}

enum MoneyKind {
  expense('Expense'),
  income('Income');

  const MoneyKind(this.label);
  final String label;
}

class MoneyEntry {
  const MoneyEntry(
    this.id,
    this.label,
    this.category,
    this.cents,
    this.kind,
    this.day,
  );
  final String id;
  final String label;
  final String category;
  final int cents;
  final MoneyKind kind;
  final String day;

  Json toJson() => {
    'id': id,
    'label': label,
    'category': category,
    'cents': cents,
    'kind': kind.name,
    'day': day,
  };
  static MoneyEntry fromJson(Json json) => MoneyEntry(
    json['id'],
    json['label'],
    json['category'],
    json['cents'],
    MoneyKind.values.byName(json['kind']),
    json['day'],
  );
}

int? parseCents(String text) {
  final match = RegExp(r'^(\d{1,8})(?:[.,](\d{1,2}))?$')
      .firstMatch(text.trim());
  if (match == null) return null;
  final cents =
      int.parse(match[1]!) * 100 + int.parse((match[2] ?? '').padRight(2, '0'));
  return cents == 0 ? null : cents;
}

class Hobby {
  const Hobby(this.id, this.name, this.weeklyMinutes, [this.archived = false]);
  final String id;
  final String name;
  final int weeklyMinutes;
  final bool archived;

  Json toJson() => {
    'id': id,
    'name': name,
    'weeklyMinutes': weeklyMinutes,
    'archived': archived,
  };
  static Hobby fromJson(Json json) =>
      Hobby(json['id'], json['name'], json['weeklyMinutes'], json['archived']);
}

class PracticeSession {
  const PracticeSession(
    this.id,
    this.hobbyId,
    this.minutes,
    this.notes,
    this.at,
  );
  final String id;
  final String hobbyId;
  final int minutes;
  final String notes;
  final DateTime at;

  Json toJson() => {
    'id': id,
    'hobbyId': hobbyId,
    'minutes': minutes,
    'notes': notes,
    'at': at.toUtc().toIso8601String(),
  };
  static PracticeSession fromJson(Json json) => PracticeSession(
    json['id'],
    json['hobbyId'],
    json['minutes'],
    json['notes'],
    DateTime.parse(json['at']),
  );
}

class HavenState {
  HavenState({
    this.townName = 'Willowbrook',
    this.theme = ThemePreference.system,
    this.expansion,
    Map<String, int> budgets = const {},
    List<Task> tasks = const [],
    List<LedgerEntry> ledger = const [],
    List<PlacedBuilding> buildings = const [],
    List<MoneyEntry> money = const [],
    List<Hobby> hobbies = const [],
    List<PracticeSession> sessions = const [],
  }) : budgets = Map.unmodifiable(budgets),
       tasks = List.unmodifiable(tasks),
       ledger = List.unmodifiable(ledger),
       buildings = List.unmodifiable(buildings),
       money = List.unmodifiable(money),
       hobbies = List.unmodifiable(hobbies),
       sessions = List.unmodifiable(sessions);

  final String townName;
  final ThemePreference theme;
  final TownExpansion? expansion;
  final Map<String, int> budgets;
  final List<Task> tasks;
  final List<LedgerEntry> ledger;
  final List<PlacedBuilding> buildings;
  final List<MoneyEntry> money;
  final List<Hobby> hobbies;
  final List<PracticeSession> sessions;

  factory HavenState.starter(DateTime date) {
    final today = dayKey(date);
    return HavenState(
      expansion: TownExpansion(dayKey(localWeekStart(date))),
      tasks: [
        Task(
          id: newId(),
          title: 'Clean my room',
          due: today,
          createdOn: today,
          category: TaskCategory.home,
        ),
        Task(
          id: newId(),
          title: 'Plan tomorrow',
          due: today,
          createdOn: today,
          effort: Effort.light,
        ),
        Task(
          id: newId(),
          title: 'Finish a school assignment',
          due: today,
          createdOn: today,
          category: TaskCategory.school,
          effort: Effort.deep,
        ),
      ],
      buildings: [
        const PlacedBuilding('starter-home', Building.cottage, (x: 4, y: 3)),
      ],
    );
  }

  Resources get balance =>
      ledger.fold(Resources.zero, (value, entry) => value + entry.delta);
  int get completedTasks =>
      ledger.where((entry) => entry.kind == LedgerKind.task).length;
  int get districtCount => expansion?.districtCount ?? 1;

  bool occupied(Plot plot, {int district = 0}) => buildings.any(
    (building) => building.district == district && building.plot == plot,
  );
  bool completed(Task task, String day) =>
      ledger.any((entry) => entry.id == taskGrantId(task, day));
  static String taskGrantId(Task task, String day) =>
      'task/${task.id}/${task.occurrence(day)}';

  List<Task> tasksFor(String day, {bool includeOverdue = false}) =>
      tasks.where((task) {
        if (task.occursOn(day)) return true;
        return includeOverdue &&
            !task.archived &&
            task.repeat == Repeat.once &&
            task.due.compareTo(day) < 0 &&
            !completed(task, day);
      }).toList();

  Resources remainingRewards(String day) {
    final granted = ledger
        .where((entry) => entry.day == day && entry.kind != LedgerKind.building)
        .fold(Resources.zero, (value, entry) => value + entry.delta);
    return Resources.dailyCap - granted;
  }

  HavenState copyWith({
    String? townName,
    ThemePreference? theme,
    TownExpansion? expansion,
    Map<String, int>? budgets,
    List<Task>? tasks,
    List<LedgerEntry>? ledger,
    List<PlacedBuilding>? buildings,
    List<MoneyEntry>? money,
    List<Hobby>? hobbies,
    List<PracticeSession>? sessions,
  }) => HavenState(
    townName: townName ?? this.townName,
    theme: theme ?? this.theme,
    expansion: expansion ?? this.expansion,
    budgets: budgets ?? this.budgets,
    tasks: tasks ?? this.tasks,
    ledger: ledger ?? this.ledger,
    buildings: buildings ?? this.buildings,
    money: money ?? this.money,
    hobbies: hobbies ?? this.hobbies,
    sessions: sessions ?? this.sessions,
  );

  Json toJson() => {
    'version': 1,
    'townName': townName,
    'theme': theme.name,
    if (expansion != null) 'expansion': expansion!.toJson(),
    'budgets': budgets,
    'tasks': tasks.map((task) => task.toJson()).toList(),
    'ledger': ledger.map((entry) => entry.toJson()).toList(),
    'buildings': buildings.map((item) => item.toJson()).toList(),
    'money': money.map((entry) => entry.toJson()).toList(),
    'hobbies': hobbies.map((hobby) => hobby.toJson()).toList(),
    'sessions': sessions.map((session) => session.toJson()).toList(),
  };

  static HavenState fromJson(Json json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported Haven save version.');
    }
    return HavenState(
      townName: json['townName'],
      theme: ThemePreference.values.byName(json['theme']),
      expansion: json['expansion'] == null
          ? null
          : TownExpansion.fromJson(json['expansion'] as Json),
      budgets: Map<String, int>.from(json['budgets']),
      tasks: decodeList(json['tasks'], Task.fromJson),
      ledger: decodeList(json['ledger'], LedgerEntry.fromJson),
      buildings: decodeList(json['buildings'], PlacedBuilding.fromJson),
      money: decodeList(json['money'], MoneyEntry.fromJson),
      hobbies: decodeList(json['hobbies'], Hobby.fromJson),
      sessions: decodeList(json['sessions'], PracticeSession.fromJson),
    );
  }
}

List<T> decodeList<T>(List<dynamic> rows, T Function(Json) decode) =>
    rows.map((row) => decode(row as Json)).toList();

WeekProgress weeklyProgress(HavenState state, DateTime week) {
  final start = dayKey(week);
  final end = dayKey(calendarDay(week, 7));
  final finished = <String>{};
  final completedBefore = <String>{};
  for (final entry in state.ledger.where(
    (entry) => entry.kind == LedgerKind.task,
  )) {
    if (entry.day.compareTo(start) < 0) {
      completedBefore.add(entry.id);
    } else if (entry.day.compareTo(end) < 0) {
      finished.add(entry.id);
    }
  }

  // A completion stays in the week's score even if its task is later edited
  // or archived. Each recurring occurrence has its own ledger ID.
  final planned = {...finished};
  for (final task in state.tasks) {
    final archivedOn = task.archivedOn;
    if (task.archived &&
        (archivedOn == null || archivedOn.compareTo(start) <= 0)) {
      continue;
    }
    if (task.repeat == Repeat.once) {
      final day = task.due.compareTo(start) < 0 ? start : task.due;
      final key = HavenState.taskGrantId(task, day);
      if (day.compareTo(end) < 0 &&
          (task.createdOn == null || task.createdOn!.compareTo(end) < 0) &&
          (archivedOn == null || day.compareTo(archivedOn) < 0) &&
          !completedBefore.contains(key)) {
        planned.add(key);
      }
      continue;
    }
    for (var offset = 0; offset < 7; offset++) {
      final day = dayKey(calendarDay(week, offset));
      if ((task.createdOn == null || day.compareTo(task.createdOn!) >= 0) &&
          (archivedOn == null || day.compareTo(archivedOn) < 0) &&
          task.scheduledOn(day)) {
        planned.add(HavenState.taskGrantId(task, day));
      }
    }
  }
  return WeekProgress(start, finished.length, planned.length);
}

HavenState advanceTownExpansion(HavenState state, DateTime now) {
  final week = localWeekStart(now);
  final monday = dayKey(week);
  final previous = state.expansion;
  if (previous == null || !previous.automatic) {
    return state.copyWith(
      expansion: TownExpansion(monday, districtCount: state.districtCount),
    );
  }
  if (monday.compareTo(previous.throughWeek) <= 0) return state;

  final lastClosedWeek = dayKey(calendarDay(week, -7));
  final eligibleWeeks = <String>{lastClosedWeek};
  for (final entry in state.ledger.where(
    (entry) => entry.kind == LedgerKind.task,
  )) {
    if (entry.day.compareTo(previous.throughWeek) >= 0 &&
        entry.day.compareTo(monday) < 0) {
      eligibleWeeks.add(dayKey(localWeekStart(dateFromKey(entry.day))));
    }
  }

  final plots = [...buildablePlots]
    ..sort((a, b) {
      int distance(Plot plot) => (plot.x - 4).abs() + (plot.y - 4).abs();
      final order = distance(a).compareTo(distance(b));
      if (order != 0) return order;
      final row = a.y.compareTo(b.y);
      return row == 0 ? a.x.compareTo(b.x) : row;
    });
  final buildings = [...state.buildings];
  final occupied = buildings
      .map((building) => (building.district, building.plot))
      .toSet();
  var district = 0;
  var districtCount = previous.districtCount;
  WeekProgress? last;
  for (final closed in eligibleWeeks.toList()..sort()) {
    final progress = weeklyProgress(state, dateFromKey(closed));
    last = progress;
    for (var index = 0; index < progress.buildings; index++) {
      var plot = plots
          .where((plot) => !occupied.contains((district, plot)))
          .firstOrNull;
      while (plot == null) {
        district++;
        plot = plots
            .where((plot) => !occupied.contains((district, plot)))
            .firstOrNull;
      }
      buildings.add(
        PlacedBuilding(
          'weekly/$closed/$index',
          Building.values[(buildings.length - 1).clamp(0, buildings.length) %
              Building.values.length],
          plot,
          district: district,
        ),
      );
      occupied.add((district, plot));
      if (district >= districtCount) districtCount = district + 1;
    }
  }

  return state.copyWith(
    expansion: TownExpansion(
      monday,
      districtCount: districtCount,
      lastWeek: last,
    ),
    buildings: buildings,
  );
}

class RuleFailure implements Exception {
  const RuleFailure(this.message);
  final String message;
}

HavenState completeTask(HavenState state, String id, DateTime now) {
  final task = state.tasks
      .where((task) => task.id == id && !task.archived)
      .firstOrNull;
  if (task == null) throw const RuleFailure('This task is unavailable.');
  final day = dayKey(now);
  final eligible =
      task.occursOn(day) ||
      (task.repeat == Repeat.once && task.due.compareTo(day) <= 0);
  if (!eligible) {
    throw const RuleFailure('This task is scheduled for another day.');
  }
  if (state.completed(task, day)) return state;
  final grant = LedgerEntry(
    HavenState.taskGrantId(task, day),
    LedgerKind.task,
    id,
    day,
    now,
    task.effort.reward.limitedBy(state.remainingRewards(day)),
  );
  return state.copyWith(ledger: [...state.ledger, grant]);
}

HavenState addPractice(HavenState state, PracticeSession session) {
  if (state.sessions.any((saved) => saved.id == session.id)) return state;
  if (!state.hobbies.any(
    (hobby) => hobby.id == session.hobbyId && !hobby.archived,
  )) {
    throw const RuleFailure('This hobby is unavailable.');
  }
  if (session.minutes < 1 || session.minutes > 720) {
    throw const RuleFailure('Enter a session between 1 and 720 minutes.');
  }
  final day = dayKey(session.at.toLocal());
  final reward = session.minutes >= 10
      ? const Resources(3, 1, 1, 2)
      : Resources.zero;
  return state.copyWith(
    sessions: [...state.sessions, session],
    ledger: [
      ...state.ledger,
      LedgerEntry(
        'hobby/${session.id}',
        LedgerKind.hobby,
        session.id,
        day,
        session.at,
        reward.limitedBy(state.remainingRewards(day)),
      ),
    ],
  );
}
