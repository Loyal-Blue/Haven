import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haven/domain.dart';
import 'package:haven/store.dart';

void main() {
  final now = DateTime(2026, 11, 22, 12);
  final today = dayKey(now);

  test('a one-off task rewards once, including when retried the next day', () {
    final state = HavenState.starter(now);
    final task = state.tasks.first;
    final completed = completeTask(state, task.id, now);
    expect(completed.balance.toJson(), Effort.steady.reward.toJson());
    expect(completeTask(completed, task.id, now), same(completed));
    expect(
      completeTask(completed, task.id, calendarDay(now, 1)),
      same(completed),
    );
  });

  test('weekly recurrence unlocks once on each scheduled day', () {
    final task = Task(
      id: 'weekly',
      title: 'Take bins out',
      due: today,
      repeat: Repeat.weekly,
    );
    final initial = HavenState(tasks: [task]);
    final first = completeTask(initial, task.id, now);
    expect(completeTask(first, task.id, now), same(first));
    expect(
      () => completeTask(first, task.id, calendarDay(now, 1)),
      throwsA(isA<RuleFailure>()),
    );
    final second = completeTask(first, task.id, calendarDay(now, 7));
    expect(second.ledger, hasLength(2));
    expect(second.completed(task, dayKey(calendarDay(now, 7))), isTrue);
  });

  test('the daily cap preserves completions and is shared by practice', () {
    final tasks = List.generate(
      5,
      (i) => Task(id: '$i', title: 'Task $i', due: today, effort: Effort.deep),
    );
    var state = HavenState(
      tasks: tasks,
      hobbies: [const Hobby('coding', 'Coding', 60)],
    );
    for (final task in tasks) {
      state = completeTask(state, task.id, now);
    }
    final session = PracticeSession('session', 'coding', 30, '', now);
    state = addPractice(state, session);
    expect(addPractice(state, session), same(state));
    expect(
      state.ledger.where((entry) => entry.kind == LedgerKind.task),
      hasLength(5),
    );
    expect(state.balance.toJson(), Resources.dailyCap.toJson());
    expect(state.ledger.last.delta.isZero, isTrue);
    expect(state.sessions.single.minutes, 30);
  });

  test(
    'queued saves reopen with one reward, weekly buildings and untouched EUR',
    () async {
      final temp = await Directory.systemTemp.createTemp('haven-saves-');
      addTearDown(() => temp.delete(recursive: true));
      final store = await HavenStore.open(temp, now: now);
      addTearDown(store.dispose);
      final taskId = store.state.tasks.first.id;
      final money = MoneyEntry(
        'income',
        'Allowance',
        'Personal',
        4000,
        MoneyKind.income,
        today,
      );
      await Future.wait([
        store.commit((state) => state.copyWith(money: [money])),
        store.commit((state) => completeTask(state, taskId, now)),
        store.commit((state) => completeTask(state, taskId, now)),
        store.commit(
          (state) => advanceTownExpansion(state, calendarDay(now, 1)),
        ),
        store.commit(
          (state) => advanceTownExpansion(state, calendarDay(now, 1)),
        ),
      ]);
      await store.commit((state) => state.copyWith(townName: 'Fern Hollow'));
      final reopened = await HavenStore.open(temp);
      addTearDown(reopened.dispose);
      expect(reopened.state.townName, 'Fern Hollow');
      expect(reopened.state.buildings, hasLength(3));
      expect(reopened.state.balance.toJson(), Effort.steady.reward.toJson());
      expect(reopened.state.money.single.cents, 4000);
      expect(reopened.state.ledger, hasLength(1));
    },
  );

  test('EUR editing accepts dot and comma decimals without rounding', () {
    expect(parseCents('12,50'), 1250);
    expect(parseCents('12.5'), 1250);
    expect(parseCents('5'), 500);
    for (final invalid in ['-4', '0', '1.234', '1,000.00', '1e3']) {
      expect(parseCents(invalid), isNull);
    }
  });
}
