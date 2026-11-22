import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haven/domain.dart';
import 'package:haven/store.dart';

void main() {
  final sunday = DateTime(2026, 11, 22, 23, 59, 59);
  final monday = DateTime(2026, 11, 23);

  test('construction lands at local Monday midnight and only runs once', () {
    final start = HavenState.starter(sunday);
    final completed = completeTask(start, start.tasks.first.id, sunday);
    expect(weeklyProgress(completed, localWeekStart(sunday)).percent, 33);
    expect(completed.buildings, hasLength(1));
    expect(advanceTownExpansion(completed, sunday), same(completed));

    final built = advanceTownExpansion(completed, monday);
    expect(built.buildings, hasLength(3));
    expect(built.expansion?.lastWeek?.buildings, 2);
    expect(built.expansion?.nextMonday, '2026-11-30');
    expect(advanceTownExpansion(built, monday), same(built));
    expect(advanceTownExpansion(built, sunday), same(built));
    expect(built.balance.toJson(), completed.balance.toJson());
  });

  test('higher completion earns up to five buildings and zero earns none', () {
    final start = HavenState.starter(sunday);
    final withNothing = advanceTownExpansion(start, monday);
    expect(withNothing.buildings, hasLength(1));
    final full = start.tasks.fold(
      start,
      (state, task) => completeTask(state, task.id, sunday),
    );
    final built = advanceTownExpansion(full, monday);
    expect(built.buildings, hasLength(6));
    expect(built.expansion!.lastWeek!.percent, 100);
    expect(
      built.buildings.map((building) => building.plot).toSet(),
      hasLength(6),
    );
  });

  test(
    'closed app catches up the completed weeks across a DST change',
    () async {
      final temp = await Directory.systemTemp.createTemp('haven-weekly-');
      addTearDown(() => temp.delete(recursive: true));
      final oldSunday = DateTime(2026, 3, 22, 23);
      final initial = await HavenStore.open(temp, now: oldSunday);
      addTearDown(initial.dispose);
      final task = initial.state.tasks.first;
      await initial.commit((state) => completeTask(state, task.id, oldSunday));

      final resumed = await HavenStore.open(temp, now: DateTime(2026, 4, 6));
      addTearDown(resumed.dispose);
      expect(resumed.state.buildings, hasLength(3));
      expect(resumed.state.expansion?.throughWeek, '2026-04-06');
      expect(resumed.state.expansion?.lastWeek?.buildings, 0);
      final reopened = await HavenStore.open(temp, now: DateTime(2026, 4, 8));
      addTearDown(reopened.dispose);
      expect(reopened.state.buildings, hasLength(3));
      expect(reopened.state.expansion?.nextMonday, '2026-04-13');
    },
  );

  test(
    'a 0.3 save keeps its buildings and districts and starts this week',
    () async {
      final temp = await Directory.systemTemp.createTemp('haven-upgrade-');
      addTearDown(() => temp.delete(recursive: true));
      final old = HavenState.starter(DateTime(2026, 5, 1)).toJson();
      old['expansion'] = {'throughWeek': '2026-04-27', 'districtCount': 4};
      for (final building in old['buildings'] as List<Json>) {
        building.remove('district');
      }
      await File('${temp.path}/haven-v1.json').writeAsString(jsonEncode(old));

      final store = await HavenStore.open(temp, now: sunday);
      addTearDown(store.dispose);
      expect(store.state.districtCount, 4);
      expect(store.state.expansion?.nextMonday, '2026-11-23');
      expect(store.state.buildings.single.district, 0);
      expect(store.state.buildings.single.id, 'starter-home');
      expect(store.state.tasks.first.id, old['tasks'][0]['id']);
    },
  );

  test('construction opens a new district when the town center is full', () {
    final start = HavenState.starter(sunday);
    final filled = start.copyWith(
      buildings: [
        ...start.buildings,
        for (final plot in buildablePlots)
          PlacedBuilding('legacy/$plot', Building.cottage, plot),
      ],
    );
    final completed = completeTask(filled, filled.tasks.first.id, sunday);
    final expanded = advanceTownExpansion(completed, monday);
    final restored = HavenState.fromJson(expanded.toJson());
    expect(restored.districtCount, 2);
    expect(
      restored.buildings.where((building) => building.district == 1),
      hasLength(2),
    );
    expect(restored.buildings.first.id, 'starter-home');
  });

  test(
    'recurring occurrences are scored once and completed archived tasks count',
    () {
      final friday = DateTime(2026, 11, 20);
      final task = Task(
        id: 'daily',
        title: 'Practice',
        due: '2026-11-16',
        repeat: Repeat.daily,
        createdOn: dayKey(friday),
      );
      var state = HavenState(tasks: [task]);
      state = completeTask(state, task.id, friday);
      final current = weeklyProgress(state, localWeekStart(friday));
      expect((current.completed, current.planned), (1, 3));
      state = state.copyWith(tasks: [task.archive('2026-11-21')]);
      expect(weeklyProgress(state, localWeekStart(friday)).completed, 1);
    },
  );
}
