import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bclock/l10n/app_localizations.dart';
import 'package:bclock/screens/timer_screen.dart';
import 'package:bclock/services/alarm_service.dart';
import 'package:bclock/services/timer_service.dart';

Widget _app(Widget home) => MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  final timer = TimerService.instance;
  // Never touch real scheduled tasks or the audio plugin.
  final scheduled = <DateTime?>[];
  var rings = 0;
  timer.syncScheduler = (endAt) async => scheduled.add(endAt);
  AlarmService.instance
    ..syncScheduler = (_) async {}
    ..playSound = () async {
      rings++;
    }
    ..silenceSound = () async {};

  Future<void> loadWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    await timer.load();
  }

  Future<Map<String, Object?>> saved() async {
    final p = await SharedPreferences.getInstance();
    return {for (final k in p.getKeys()) k: p.get(k)};
  }

  setUp(() {
    scheduled.clear();
    rings = 0;
  });
  // A test that leaves the timer running would leave its end Timer pending.
  tearDown(timer.reset);

  test('start, pause, resume and reset move the scheduled task', () async {
    await loadWith({});
    timer.setDuration(const Duration(minutes: 10));

    timer.startOrResume();
    expect(timer.isRunning, isTrue);
    final end = scheduled.last!;
    expect(end.difference(DateTime.now()).inSeconds, closeTo(600, 2));
    expect((await saved())['timer.endAtMs'], end.millisecondsSinceEpoch);

    timer.pause();
    expect(timer.isPaused, isTrue);
    expect(scheduled.last, isNull); // task removed while paused
    expect((await saved())['timer.pausedLeftMs'], isNotNull);

    timer.startOrResume();
    expect(timer.isRunning, isTrue);
    expect(scheduled.last, isNotNull);

    timer.reset();
    expect(timer.isIdle, isTrue);
    expect(timer.remaining(), const Duration(minutes: 10));
    expect(scheduled.last, isNull);
  });

  test('a running timer survives a restart', () async {
    final end = DateTime.now().add(const Duration(seconds: 90));
    await loadWith({
      'timer.durationMs': const Duration(minutes: 5).inMilliseconds,
      'timer.endAtMs': end.millisecondsSinceEpoch,
    });

    expect(timer.isRunning, isTrue);
    expect(timer.remaining().inSeconds, closeTo(90, 2));
  });

  test('a timer that ended moments ago rings on launch', () async {
    await loadWith({
      'timer.endAtMs': DateTime.now()
          .subtract(const Duration(seconds: 10))
          .millisecondsSinceEpoch,
    });
    timer.start(); // what a --timer-done launch does

    expect(rings, 1);
    expect(timer.isIdle, isTrue);
    expect(scheduled.last, isNull);
    // The forwarded --timer-done arriving after that rings nothing more.
    timer.fireIfDue();
    expect(rings, 1);
  });

  test('a timer that ended long ago is finished quietly', () async {
    await loadWith({
      'timer.endAtMs': DateTime.now()
          .subtract(const Duration(hours: 3))
          .millisecondsSinceEpoch,
    });
    timer.start();

    expect(rings, 0);
    expect(timer.isIdle, isTrue);
  });

  test('+1 min extends a running timer; −1 min stops at a minute', () async {
    await loadWith({});
    timer.setDuration(const Duration(minutes: 2));
    timer.removeMinute();
    timer.removeMinute(); // at one minute: would reach zero
    expect(timer.duration, const Duration(minutes: 1));
    timer.setDuration(const Duration(seconds: 90));
    timer.removeMinute(); // custom values go below a minute
    expect(timer.duration, const Duration(seconds: 30));
    timer.setDuration(const Duration(minutes: 1));

    timer.startOrResume();
    timer.addMinute();
    expect(timer.remaining().inSeconds, closeTo(120, 2));
    expect(timer.total, const Duration(minutes: 2));
  });

  testWidgets('picking a preset and starting counts down', (tester) async {
    await loadWith({});
    await tester.pumpWidget(_app(const TimerScreen()));

    expect(find.text('05:00'), findsOneWidget);
    await tester.tap(find.text('10 min'));
    await tester.pump();
    expect(find.text('10:00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.text('10 min'), findsNothing); // presets hide while running
    timer.reset(); // before the pending-Timer check, which precedes tearDown
  });

  testWidgets('a timer ending in the app rings once', (tester) async {
    await loadWith({});
    await tester.pumpWidget(_app(const TimerScreen()));
    timer.setDuration(TimerService.minDuration);
    timer.startOrResume();

    // The end Timer runs on the test's fake clock.
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    expect(rings, 1);
    expect(timer.isIdle, isTrue);
  });

  testWidgets('the timer fits small windows', (tester) async {
    await loadWith({});
    addTearDown(tester.view.reset);
    for (final size in const [Size(240, 200), Size(240, 400), Size(340, 300)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app(const TimerScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('five nav labels fit the narrowest window', (tester) async {
    tester.view.physicalSize = const Size(240, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // French has the longest labels ("Minuteur", "Monde", ...).
    final l = await AppLocalizations.delegate.load(const Locale('fr'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: NavigationBar(
          selectedIndex: 2,
          destinations: [
            for (final label in [
              l.navClock,
              l.navStopwatch,
              l.navTimer,
              l.navWorld,
              l.navAlarm,
            ])
              NavigationDestination(
                  icon: const Icon(Icons.circle), label: label),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom value is typed in the dialog; Enter sets it',
      (tester) async {
    await loadWith({});
    await tester.pumpWidget(_app(const TimerScreen()));

    // Tapping the time opens the dialog, focused on minutes.
    // At the narrowest window, so the three fields must fit there too.
    tester.view.physicalSize = const Size(240, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pump();
    await tester.tap(find.text('05:00'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Set timer'), findsOneWidget);
    final minutes = find.byType(TextField).at(1);
    expect(tester.widget<TextField>(minutes).focusNode!.hasFocus, isTrue);

    await tester.enterText(minutes, '1');
    await tester.enterText(find.byType(TextField).at(2), '30');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Set timer'), findsNothing);
    expect(timer.duration, const Duration(minutes: 1, seconds: 30));
    expect(find.text('01:30'), findsOneWidget);
    // Not a preset, so "Custom…" shows as the selection.
    expect(
      tester
          .widget<PlinthChip>(find.widgetWithText(PlinthChip, 'Custom…'))
          .selected,
      isTrue,
    );
  });

  testWidgets('the time is not editable while running', (tester) async {
    await loadWith({});
    await tester.pumpWidget(_app(const TimerScreen()));
    timer.startOrResume();
    await tester.pump();

    await tester.tap(find.text('05:00'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Set timer'), findsNothing);
    timer.reset(); // before the pending-Timer check, which precedes tearDown
  });
}
