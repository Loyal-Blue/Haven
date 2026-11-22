import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/main.dart';
import 'package:haven/domain.dart';
import 'package:haven/store.dart';
import 'package:haven/town.dart';

void main() {
  testWidgets(
    'Android-sized town shows task completion and projected construction',
    (tester) async {
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
      expect(
        find.text('2 projected buildings for Sunday night'),
        findsOneWidget,
      );
      expect(find.text('Build'), findsNothing);
      expect(store.state.buildings, hasLength(1));

      Finder bottom(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      await tester.tap(bottom('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Haven AI'));
      await tester.pumpAndSettle();
      expect(find.text('Set up provider'), findsOneWidget);
      await tester.tap(bottom('My'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Money'));
      await tester.pumpAndSettle();
      expect(find.text('Net cash flow'), findsOneWidget);
      expect(find.text('New transaction'), findsOneWidget);
      await tester.tap(bottom('Event'));
      await tester.pumpAndSettle();
      expect(find.text('Schedule task'), findsOneWidget);
      await tester.tap(bottom('More'));
      await tester.pumpAndSettle();
      expect(find.text('Hobbies'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('desktop-width layout offers a navigation rail and town', (
    tester,
  ) async {
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
  });

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
}
