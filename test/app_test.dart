import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/main.dart';
import 'package:haven/design.dart';
import 'package:haven/mobile_home.dart';
import 'package:haven/mobile_widgets.dart';
import 'package:haven/domain.dart';
import 'package:haven/store.dart';
import 'package:haven/town.dart';

void main() {
  testWidgets('Android redesign preserves task completion and navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(414, 880);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final temp = Directory.systemTemp.createTempSync('haven-ui-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final store = (await tester.runAsync(() => HavenStore.open(temp)))!;
    addTearDown(store.dispose);

    await tester.pumpWidget(HavenApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Your town'), findsOneWidget);
    expect(find.text('Willowbrook'), findsOneWidget);

    Future<void> tapAndSave(Finder finder) async {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await store.commit((state) => state);
      });
      await tester.pumpAndSettle();
    }

    final complete = find.byTooltip('Complete Clean my room');
    await tester.ensureVisible(complete);
    await tapAndSave(complete);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('2 projected buildings for Sunday night'), findsOneWidget);
    expect(find.text('Build'), findsNothing);
    expect(store.state.buildings, hasLength(1));

    Finder bottom(Destination destination) => find.byKey(ValueKey(destination));
    expect(find.byTooltip('Quick add'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('More and settings'));
    await tester.tap(find.byTooltip('More and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haven AI'));
    await tester.pumpAndSettle();
    expect(find.text('Set up provider'), findsOneWidget);
    await tester.tap(bottom(Destination.my));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    expect(find.text('Net cash flow'), findsOneWidget);
    expect(find.text('New transaction'), findsOneWidget);
    await tester.tap(bottom(Destination.planner));
    await tester.pumpAndSettle();
    expect(find.text('Schedule task'), findsOneWidget);
    await tester.tap(find.byTooltip('More and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hobbies'));
    await tester.pumpAndSettle();
    expect(find.text('New hobby'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets(
    'desktop layout retains its navigation rail and theme',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 820);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final temp = Directory.systemTemp.createTempSync('haven-desktop-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final store = (await tester.runAsync(() => HavenStore.open(temp)))!;
      addTearDown(store.dispose);
      await tester.pumpWidget(HavenApp(store: store));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(PhoneDashboard), findsNothing);
      expect(find.byTooltip('Quick add'), findsNothing);
      final context = tester.element(find.byType(TownMap));
      expect(phoneStyle(context), isNull);
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        const Color(0xfff1eee8),
      );
      expect(find.text('Routine'), findsOneWidget);
      expect(find.text('Willowbrook'), findsOneWidget);
      final terrain = tester.widget<Image>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/world/terrain.png',
        ),
      );
      expect(terrain.fit, BoxFit.fill);
      await tester.tap(find.text('Todo'));
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );

  testWidgets('the weekly district is visible and navigable', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(414, 880);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final temp = Directory.systemTemp.createTempSync('haven-districts-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final store = (await tester.runAsync(() async {
      final now = DateTime.now();
      final older = DateTime(now.year, now.month, now.day - 7);
      final original = await HavenStore.open(temp, now: older);
      await original.commit(
        (state) => state.copyWith(
          expansion: TownExpansion(
            state.expansion!.throughWeek,
            districtCount: 2,
          ),
        ),
      );
      original.dispose();
      return HavenStore.open(temp, now: now);
    }))!;
    addTearDown(store.dispose);

    await tester.pumpWidget(HavenApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('District 1 of 2'), findsOneWidget);
    expect(
      tester.widget<TownMap>(find.byType(TownMap)).buildings,
      hasLength(1),
    );

    await tester.ensureVisible(find.byTooltip('Next district'));
    await tester.tap(find.byTooltip('Next district'));
    await tester.pumpAndSettle();
    expect(find.text('District 2 of 2'), findsOneWidget);
    expect(find.text('Upper meadows · Level 1'), findsOneWidget);
    expect(tester.widget<TownMap>(find.byType(TownMap)).buildings, isEmpty);

    await tester.tap(find.byTooltip('Previous district'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TownMap>(find.byType(TownMap)).buildings,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('compact iOS layout schedules tasks and shows report pills', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final dir = Directory.systemTemp.createTempSync('haven-phone-add-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = (await tester.runAsync(() => HavenStore.open(dir)))!;
    addTearDown(store.dispose);
    await tester.pumpWidget(HavenApp(store: store));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(PhoneWeek));
    final today = dateFromKey(dayKey(DateTime.now()));
    final monday = localWeekStart(today);
    final other = today.weekday == DateTime.monday
        ? calendarDay(monday, 1)
        : monday;
    final day = find.byKey(ValueKey(dayKey(other)));
    await tester.ensureVisible(day);
    await tester.tap(find.descendant(of: day, matching: find.byType(InkWell)));
    await tester.pumpAndSettle();
    expect(
      find.text('Tasks on ${formattedDate(context, dayKey(other))}'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Quick add'));
    await tester.pumpAndSettle();
    expect(find.text('New transaction'), findsOneWidget);
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Plan a walk');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    expect(find.text('Save task'), findsNothing);
    for (
      var attempt = 0;
      attempt < 30 &&
          !store.state.tasks.any((task) => task.title == 'Plan a walk');
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(
      store.state.tasks.singleWhere((task) => task.title == 'Plan a walk').due,
      dayKey(other),
    );

    await tester.tap(find.byKey(const ValueKey(Destination.my)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.byType(PhonePills), findsOneWidget);
    expect(
      tester.getRect(find.byTooltip('Quick add')).bottom,
      lessThanOrEqualTo(700 - 34),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
}
