import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plinth_blocks/plinth_blocks.dart';

import 'package:bclock/l10n/app_localizations.dart';
import 'package:bclock/models/alarm_model.dart';
import 'package:bclock/providers/app_provider.dart';
import 'package:bclock/screens/alarm_screen.dart';
import 'package:bclock/screens/clock_screen.dart';
import 'package:bclock/services/alarm_scheduler.dart';
import 'package:bclock/services/alarm_service.dart';
import 'package:bclock/services/app_window.dart';
import 'package:bclock/screens/settings_screen.dart';
import 'package:bclock/screens/stopwatch_screen.dart';
import 'package:bclock/screens/world_clock_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

Widget _app(Widget home, {Locale? locale}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  AppWindow.raise = () async {}; // no window plugin in tests
  // No real window under test: record the runner's window calls instead.
  final windowCalls = <MethodCall>[];
  // Never touch the real scheduled tasks or the audio plugin.
  final schedulerSyncs = <List<String>>[];
  AlarmService.instance
    ..syncDelay = Duration.zero
    ..syncScheduler = (alarms) async {
      schedulerSyncs.add([for (final a in alarms) a.id]);
      return true;
    }
    ..playSound = () async {}
    ..silenceSound = () async {};
  setUp(() {
    windowCalls.clear();
    schedulerSyncs.clear();
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('bclock/window'),
            (call) async {
      windowCalls.add(call);
      return null;
    });
  });

  test('Title bar brightness follows the app theme', () async {
    SharedPreferences.setMockInitialValues({'flutter.themeMode': 2}); // dark
    final provider = AppProvider();
    await provider.load();
    List<Object?> darkTitleBar() => windowCalls
        .where((c) => c.method == 'setDarkTitleBar')
        .map((c) => c.arguments)
        .toList();
    expect(darkTitleBar(), [true]);

    provider.toggleTheme();
    expect(darkTitleBar(), [true, false]);
  });

  testWidgets('StopwatchScreen renders start button', (WidgetTester tester) async {
    await tester.pumpWidget(_app(const StopwatchScreen()));

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('Stopwatch time is announced as a duration', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const StopwatchScreen()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('0 minutes, 0 seconds'), findsOneWidget);
    // The raw digits must not be announced after the label.
    expect(find.bySemanticsLabel('00:00.00'), findsNothing);
    semantics.dispose();
  });

  testWidgets('Stopwatch keeps the hours past 60 minutes', (tester) async {
    const elapsed = Duration(hours: 1, minutes: 15, seconds: 3);
    SharedPreferences.setMockInitialValues(
        {'flutter.sw.baseMs': elapsed.inMilliseconds});
    // Compact-window width: the longer H:MM:SS.cs must scale, not overflow.
    tester.view.physicalSize = const Size(300, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const StopwatchScreen()));
    await tester.pumpAndSettle();

    expect(find.text('1:15:03.00'), findsOneWidget);
    // One line (not wrapped) and within the 24px page gutters, as drawn —
    // getRect includes the FittedBox scale.
    final rect = tester.getRect(find.text('1:15:03.00'));
    expect(rect.height, lessThan(64 * 1.5));
    expect(rect.width, lessThanOrEqualTo(300 - 2 * 24));
    expect(find.bySemanticsLabel('1 hour, 15 minutes, 3 seconds'),
        findsOneWidget);
    semantics.dispose();
  });

  testWidgets('StopwatchScreen follows the app locale', (tester) async {
    await tester.pumpWidget(
        _app(const StopwatchScreen(), locale: const Locale('fr')));
    await tester.pumpAndSettle();
    expect(find.text('Chronomètre'), findsOneWidget);

    await tester.pumpWidget(
        _app(const StopwatchScreen(), locale: const Locale('he')));
    await tester.pumpAndSettle();
    expect(find.text('סטופר'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('סטופר'))),
      TextDirection.rtl,
    );
  });

  test('Sunday-first week reorders display, not storage indices', () {
    expect(WeekStart.monday.dayOrder, [0, 1, 2, 3, 4, 5, 6]);
    // Storage index 6 is Sunday (AlarmModel.days is Monday-first).
    expect(WeekStart.sunday.dayOrder, [6, 0, 1, 2, 3, 4, 5]);
  });

  testWidgets('Week start is chosen in settings and persisted',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = AppProvider();
    expect(provider.weekStart, WeekStart.monday);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: _app(const SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sunday'));
    await tester.pumpAndSettle();
    expect(provider.weekStart, WeekStart.sunday);

    final reloaded = AppProvider();
    await tester.runAsync(reloaded.load);
    expect(reloaded.weekStart, WeekStart.sunday);
  });

  testWidgets('Language picker switches the app language', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = AppProvider()..setLanguageCode('he');
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: Consumer<AppProvider>(
        builder: (_, p, __) => _app(const SettingsScreen(), locale: p.locale),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('שפת הממשק'), findsOneWidget);

    await tester.tap(find.text('עברית'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();

    expect(provider.languageCode, 'fr');
    expect(find.text("Langue de l'interface"), findsOneWidget);
  });

  testWidgets('World clock cities are restored and removals persist',
      (tester) async {
    tzdata.initializeTimeZones();
    SharedPreferences.setMockInitialValues({
      'flutter.world.cities': ['Europe/London', 'Asia/Tokyo'],
    });
    final provider = AppProvider();
    await provider.load();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: _app(const WorldClockScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('London'), findsOneWidget);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('New York'), findsNothing); // a default, not saved

    await tester.tap(find.byWidgetPredicate((w) =>
        w is PlinthCloseButton && w.semanticLabel == 'Remove London'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('world.cities'), ['Asia/Tokyo']);
  });

  Widget alarmApp(AppProvider provider) => ChangeNotifierProvider.value(
        value: provider,
        child: _app(const AlarmScreen()),
      );

  testWidgets('Alarms: first run seeds and saves the defaults', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    await provider.load();
    await AlarmService.instance.load();
    await tester.pumpWidget(alarmApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AlarmService.alarmsStorageKey), contains('"1"'));
    expect(schedulerSyncs.last, ['1', '2']);
  });

  testWidgets('Alarms: a fired one-shot is disabled, saved and shown off',
      (tester) async {
    final oneShot = AlarmModel(id: 'once', hour: 6, minute: 15);
    SharedPreferences.setMockInitialValues({
      'flutter.${AlarmService.alarmsStorageKey}':
          jsonEncode([oneShot.toJson()]),
    });
    final provider = AppProvider();
    await provider.load();
    await AlarmService.instance.load();
    await tester.pumpWidget(alarmApp(provider));
    await tester.pumpAndSettle();
    bool shownOn() =>
        tester.widget<PlinthSwitch>(find.byType(PlinthSwitch)).value;
    expect(shownOn(), isTrue);

    // As if the scheduled task fired (fresh launch or forwarded).
    await AlarmService.instance.fireById('once');
    await tester.pumpAndSettle();

    expect(shownOn(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(AlarmService.alarmsStorageKey)!);
    expect(saved[0]['isEnabled'], isFalse);
    expect(schedulerSyncs.last, ['once']);

    // Firing again in the same minute (the other path) is a no-op.
    schedulerSyncs.clear();
    await AlarmService.instance.fireById('once');
    expect(schedulerSyncs, isEmpty);
  });

  testWidgets('Alarm label dialog takes focus and saves on Enter',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.${AlarmService.alarmsStorageKey}':
          jsonEncode([AlarmModel(id: 'l', hour: 9, minute: 0).toJson()]),
    });
    final provider = AppProvider();
    await provider.load();
    await AlarmService.instance.load();
    await tester.pumpWidget(alarmApp(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add label…'));
    await tester.pumpAndSettle();
    // Focused on open: typing needs no click.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);

    tester.testTextInput.enterText('Gym ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing); // dialog closed
    expect(find.text('Gym'), findsOneWidget);
    expect(AlarmService.instance.alarms.single.label, 'Gym');
  });

  testWidgets('Clock tab never overflows a short window', (tester) async {
    // Shorter than the clock wants: the user dragged the window edge, or
    // the controls row is mid-animation. The clock must scale, not
    // overflow.
    for (final view in ClockView.values) {
      for (final size in ClockSizeOption.values) {
        for (final height in [240.0, 200.0, 160.0, 120.0]) {
          SharedPreferences.setMockInitialValues({
            'flutter.clockView': view.index,
            'flutter.clockSize': size.index,
          });
          final provider = AppProvider();
          await provider.load();
          tester.view.physicalSize = Size(308, height);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(ChangeNotifierProvider.value(
            value: provider,
            child: _app(const ClockScreen(active: false)),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$view, $size, height $height');
        }
      }
    }
    tester.view.reset();
  });

  Future<void> pumpWorld(WidgetTester tester, List<String> zones) async {
    tzdata.initializeTimeZones();
    SharedPreferences.setMockInitialValues({'flutter.world.cities': zones});
    final provider = AppProvider();
    await provider.load();
    tester.view.physicalSize = const Size(700, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: _app(const WorldClockScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<List<String>?> savedZones() async =>
      (await SharedPreferences.getInstance()).getStringList('world.cities');

  testWidgets('World clocks reorder by dragging a card onto another',
      (tester) async {
    await pumpWorld(tester, ['Europe/London', 'Asia/Tokyo', 'Europe/Paris']);

    final drag =
        await tester.startGesture(tester.getCenter(find.text('Paris')));
    await drag.moveBy(const Offset(-20, 0)); // past the drag slop
    await tester.pump();
    await drag.moveTo(tester.getCenter(find.text('London').first));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(await savedZones(), ['Europe/Paris', 'Europe/London', 'Asia/Tokyo']);
    // Drawn in the new order too: Paris is now left of London.
    expect(tester.getCenter(find.text('Paris')).dx,
        lessThan(tester.getCenter(find.text('London')).dx));
  });

  testWidgets('World clocks reorder from a screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpWorld(tester, ['Europe/London', 'Asia/Tokyo']);

    final node = tester.getSemantics(find.text('Tokyo'));
    final ids = node.getSemanticsData().customSemanticsActionIds!;
    final later = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Move later'));
    final earlier = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Move earlier'));
    // Last card: it can only move earlier.
    expect(ids, contains(earlier));
    expect(ids, isNot(contains(later)));

    tester.binding.performSemanticsAction(SemanticsActionEvent(
      type: SemanticsAction.customAction,
      viewId: tester.view.viewId,
      nodeId: node.id,
      arguments: earlier,
    ));
    await tester.pumpAndSettle();

    expect(await savedZones(), ['Asia/Tokyo', 'Europe/London']);
    semantics.dispose();
  });

  test('Alarm tasks wake the PC and run on battery', () {
    final cmd = AlarmScheduler.registerCommand(
      AlarmModel(id: 'w', hour: 6, minute: 30, repeat: true),
      r'C:\Apps\bClock\bclock.exe',
      r'C:\Apps\bClock',
    );

    expect(cmd, contains("-TaskName 'bClock_alarm_w'"));
    expect(cmd, contains('-WakeToRun'));
    expect(cmd, contains('-AllowStartIfOnBatteries'));
    expect(cmd, contains('-DontStopIfGoingOnBatteries'));
    // No 72-hour limit killing the bClock the task launched.
    expect(cmd, contains('-ExecutionTimeLimit ([TimeSpan]::Zero)'));
  });
}
