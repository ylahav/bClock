import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:bclock/l10n/app_localizations.dart';
import 'package:bclock/providers/app_provider.dart';
import 'package:bclock/screens/world_clock_screen.dart';

void main() {
  const zones = ['Europe/London', 'Asia/Tokyo', 'America/New_York'];

  setUpAll(tzdata.initializeTimeZones);
  // AppProvider.load sets the title bar through the runner's channel.
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized()
      .defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('bclock/window'), (_) async => null));

  Future<void> pumpWorld(
    WidgetTester tester, {
    Size size = const Size(700, 700),
    ClockView view = ClockView.digital,
  }) async {
    SharedPreferences.setMockInitialValues({
      'flutter.world.cities': zones,
      'flutter.clockView': view.index,
    });
    final provider = AppProvider();
    await tester.runAsync(provider.load);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const WorldClockScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Each zone's time when it is [minutes] after local midnight today.
  List<tz.TZDateTime> timesAt(int minutes) {
    final now = DateTime.now();
    final moment = DateTime(now.year, now.month, now.day)
        .add(Duration(minutes: minutes))
        .toUtc();
    return [
      for (final z in zones) tz.TZDateTime.from(moment, tz.getLocation(z)),
    ];
  }

  Future<void> openPlanner(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pumpAndSettle();
  }

  /// Moves the planner's slider to [minutes] after local midnight.
  Future<void> planAt(WidgetTester tester, int minutes) async {
    tester
        .widget<PlinthSlider>(find.byType(PlinthSlider))
        .onChanged!(minutes.toDouble());
    await tester.pumpAndSettle();
  }

  testWidgets('the planner shows every city at the chosen time',
      (tester) async {
    await pumpWorld(tester);
    expect(find.byType(PlinthSlider), findsNothing); // live clocks

    await openPlanner(tester);
    await planAt(tester, 10 * 60); // 10:00 here

    final times = timesAt(10 * 60);
    for (final t in times) {
      expect(find.text(DateFormat('HH:mm').format(t)), findsWidgets);
    }
    // Working hours (9:00-18:00 there) are counted and marked.
    final working = times.where((t) => t.hour >= 9 && t.hour < 18).length;
    expect(find.text('$working of 3 in working hours'), findsOneWidget);
    expect(find.byIcon(Icons.work_outline), findsNWidgets(working));
  });

  testWidgets('a different time changes which cities are working',
      (tester) async {
    await pumpWorld(tester);
    await openPlanner(tester);

    // Somewhere in the day the count differs from 10:00's: three zones
    // 14 hours apart are never all in or all out the whole day.
    final counts = <int>{};
    for (var m = 0; m < 24 * 60; m += 120) {
      await planAt(tester, m);
      final working =
          timesAt(m).where((t) => t.hour >= 9 && t.hour < 18).length;
      expect(find.text('$working of 3 in working hours'), findsOneWidget,
          reason: 'at $m minutes');
      counts.add(working);
    }
    expect(counts.length, greaterThan(1));
  });

  testWidgets('Now returns to the live clocks', (tester) async {
    await pumpWorld(tester);
    await openPlanner(tester);
    await planAt(tester, 3 * 60);

    await tester.tap(find.text('Now'));
    await tester.pumpAndSettle();

    expect(find.byType(PlinthSlider), findsNothing);
    expect(find.byIcon(Icons.work_outline), findsNothing);
    final live = tz.TZDateTime.now(tz.getLocation(zones.first));
    expect(find.text(DateFormat('HH:mm').format(live)), findsWidgets);
  });

  testWidgets('cards and planner fit the narrowest window in every view',
      (tester) async {
    for (final view in ClockView.values) {
      await pumpWorld(tester, size: const Size(240, 400), view: view);
      expect(tester.takeException(), isNull, reason: '$view, live');
      await openPlanner(tester);
      await planAt(tester, 15 * 60);
      expect(tester.takeException(), isNull, reason: '$view, planning');
      // A fresh screen (and so the live clocks) for the next view.
      await tester.pumpWidget(const SizedBox());
    }
  });
}
