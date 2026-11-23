import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/appearance.dart';
import 'package:haven/assistant.dart';
import 'package:haven/design.dart';
import 'package:haven/domain.dart';
import 'package:haven/main.dart';
import 'package:haven/mobile_preferences.dart';
import 'package:haven/planner_data.dart';
import 'package:haven/store.dart';
import 'package:haven/theme_settings.dart';
import 'package:haven/town.dart';

void main() {
  test(
    'custom colors and both pure monochrome variants persist in the save',
    () async {
      final directory = await Directory.systemTemp.createTemp('haven-theme-');
      addTearDown(() => directory.delete(recursive: true));
      final store = await HavenStore.open(directory);
      const settings = ThemeSettings(
        preset: ThemePreset.custom,
        base: ThemePreset.ocean,
        mono: Mono.black,
        monoVariant: Mono.black,
        colors: {ThemeToken.primary: 0x112233, ThemeToken.event: 0x5588aa},
        fontScale: 1.25,
        reducedMotion: true,
        highContrast: true,
      );
      await store.commit((state) => state.copyWith(appearance: settings));
      store.dispose();
      final reopened = await HavenStore.open(directory);
      addTearDown(reopened.dispose);
      final restored = reopened.state.appearance;
      expect(restored.toJson(), settings.toJson());
      for (final (variant, paper, ink) in const [
        (Mono.black, Colors.black, Colors.white),
        (Mono.white, Colors.white, Colors.black),
      ]) {
        final theme = havenTheme(
          Brightness.light,
          restored.copyWith(mono: variant),
        );
        expect(theme.scaffoldBackgroundColor, paper);
        expect(theme.colorScheme.surface, paper);
        expect(theme.colorScheme.primary, ink);
        expect(theme.colorScheme.error, ink);
        expect(theme.extension<HavenPalette>()![ThemeToken.event], ink);
      }
      final custom = makePalette(
        Brightness.light,
        restored.copyWith(mono: Mono.off),
      );
      expect(custom[ThemeToken.primary], const Color(0xff112233));
      expect(custom[ThemeToken.event], const Color(0xff5588aa));
    },
  );

  test('legacy saves keep their color mode without new settings', () {
    final data = HavenState(theme: ThemePreference.dark).toJson()
      ..remove('mobile')
      ..remove('appearance')
      ..remove('appearanceUpdatedAt')
      ..remove('taskReset')
      ..remove('projects');
    final restored = HavenState.fromJson(data);
    expect(restored.theme, ThemePreference.dark);
    expect(restored.appearance.preset, ThemePreset.classic);
    expect(restored.projects, isEmpty);
    expect(restored.mobile.order, DashboardCard.values);
  });

  test(
    'manual and scheduled resets preserve scoring and only grant rewards once',
    () {
      final before = DateTime(2026, 11, 22, 8);
      final state = HavenState.starter(before);
      final task = state.tasks.first;
      final day = dayKey(before);
      final granted = completeTask(state, task.id, before);
      final reset = granted.copyWith(
        taskReset: granted.taskReset.after(before, granted.ledger.length),
      );
      expect(reset.checked(task, day), isFalse);
      expect(reset.completed(task, day), isTrue);
      final restored = completeTask(reset, task.id, before);
      expect(restored.checked(task, day), isTrue);
      expect(restored.ledger, granted.ledger);
      final auto = restored.copyWith(
        taskReset: TaskReset(
          frequency: ResetFrequency.weekly,
          weekday: DateTime.sunday,
          minute: 9 * 60,
          lastAt: before.millisecondsSinceEpoch,
        ),
      );
      expect(applyTaskReset(auto, before), same(auto));
      final after = DateTime(2026, 11, 22, 9);
      final cleared = applyTaskReset(auto, after);
      expect(cleared.checked(task, day), isFalse);
      expect(cleared.balance.toJson(), restored.balance.toJson());
      expect(weeklyProgress(cleared, localWeekStart(after)).completed, 1);
      expect(applyTaskReset(cleared, after), same(cleared));
      final expanded = advanceTownExpansion(cleared, DateTime(2026, 11, 23));
      expect(expanded.expansion!.history.single.buildings, 2);
    },
  );

  test('custom recurrence, priorities, subtasks, and reminders survive serialization', () {
    const task = Task(
      id: 'routine',
      title: 'Read a chapter',
      due: '2026-10-25',
      repeat: Repeat.weekly,
      interval: 2,
      projectId: 'project',
      priority: TaskPriority.high,
      reminderMinute: 570,
    );
    final state = HavenState(
      tasks: const [task],
      projects: const [
        Project('project', 'Finish book', milestone: '2026-11-30'),
      ],
    );
    final decoded = HavenState.fromJson(state.toJson());
    final restored = decoded.projectTasks('project').single;
    expect(restored.occursOn('2026-11-01'), isFalse);
    expect(restored.occursOn('2026-11-08'), isTrue);
    expect(restored.priority, TaskPriority.high);
    expect(restored.reminderMinute, 570);
    expect(decoded.projects.single.milestone, '2026-11-30');
  });

  test('photo parser deduplicates titles and rejects malformed responses', () {
    expect(
      photoTaskTitles('''```json
{"tasks":["  Clean  room  ","clean room","Read chapter",8,""]}
```'''),
      ['Clean room', 'Read chapter'],
    );
    expect(() => photoTaskTitles('A prose answer'), throwsFormatException);
  });

  testWidgets('compact layouts switch appearance live and grayscale the town', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(335, 790);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final dir = Directory.systemTemp.createTempSync('haven-compact-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = (await tester.runAsync(() => HavenStore.open(dir)))!;
    addTearDown(store.dispose);
    await tester.pumpWidget(HavenApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(Destination.tasks)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open side tabs'));
    await tester.pumpAndSettle();
    expect(find.text('Routine'), findsOneWidget);
    await tester.tap(find.text('Routine'));
    await tester.pumpAndSettle();
    expect(find.text('Routines'), findsOneWidget);

    await tester.tap(find.byTooltip('More and settings'));
    await tester.pumpAndSettle();
    final appearance = find.text('Appearance');
    await tester.ensureVisible(appearance);
    await tester.tap(appearance);
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceScreen), findsOneWidget);
    final preset = find.widgetWithText(ChoiceChip, 'Black & White');
    await tester.ensureVisible(preset);
    await tester.runAsync(() async {
      await tester.tap(preset);
      await store.commit((state) => state);
    });
    await tester.pumpAndSettle();
    expect(store.state.appearance.mono, Mono.white);
    final dark = (await tester.runAsync(
      () => store.commit(
        (state) => state.copyWith(
          appearance: state.appearance.copyWith(
            mono: Mono.black,
            fontScale: 1.35,
          ),
        ),
      ),
    ))!;
    expect(dark.appearance.mono, Mono.black);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(AppearanceScreen)))
          .scaffoldBackgroundColor,
      Colors.black,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(Destination.town)));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TownMap),
        matching: find.byType(ColorFiltered),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('mobile card colors, order and preference changes persist', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 840);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final dir = Directory.systemTemp.createTempSync('haven-mobile-options-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = (await tester.runAsync(() => HavenStore.open(dir)))!;
    addTearDown(store.dispose);
    await tester.pumpWidget(HavenApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobile dashboard'));
    await tester.pumpAndSettle();

    Future<void> saveAction(Finder finder, bool Function() saved) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 30 && !saved(); attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(
        saved(),
        isTrue,
        reason: '$finder left ${store.state.mobile.toJson()}',
      );
    }

    await tester.tap(find.text('Dashboard greeting'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Alex');
    await saveAction(
      find.text('Save'),
      () => store.state.mobile.name == 'Alex',
    );

    final reorder = find.byTooltip('Move Tasks earlier');
    await tester.ensureVisible(reorder);
    await saveAction(
      reorder,
      () => store.state.mobile.order.first == DashboardCard.tasks,
    );
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '#C3A4EE');
    await tester.pumpAndSettle();
    await saveAction(
      find.text('Apply'),
      () => store.state.mobile.colors[DashboardCard.tasks] == 0xc3a4ee,
    );
    await tester.tap(find.byType(DropdownButtonFormField<MobileMotion>));
    await tester.pumpAndSettle();
    await saveAction(
      find.text('Off').last,
      () => store.state.mobile.motion == MobileMotion.still,
    );

    final saved = (await tester.runAsync(() async {
      final reopened = await HavenStore.open(dir);
      try {
        return reopened.state.mobile;
      } finally {
        reopened.dispose();
      }
    }))!;
    expect(saved.name, 'Alex');
    expect(saved.order.first, DashboardCard.tasks);
    expect(saved.colors[DashboardCard.tasks], 0xc3a4ee);
    expect(saved.motion, MobileMotion.still);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
