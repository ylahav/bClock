import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bclock/l10n/app_localizations.dart';
import 'package:bclock/models/alarm_model.dart';
import 'package:bclock/providers/app_provider.dart';
import 'package:bclock/screens/alarm_screen.dart';
import 'package:bclock/services/alarm_scheduler.dart';
import 'package:bclock/services/alarm_service.dart';
import 'package:bclock/services/app_window.dart';

void main() {
  AppWindow.raise = () async {}; // no window plugin in tests
  final service = AlarmService.instance
    ..playSound = () async {}
    ..silenceSound = () async {};

  /// What each sync was asked to register, and what it should answer.
  final syncs = <List<String>>[];
  var succeed = true;

  // Far from the current minute's alarms: 03:07 never fires mid-test
  // unless the suite happens to run at 03:07.
  AlarmModel alarm(String id, {bool enabled = true}) =>
      AlarmModel(id: id, hour: 3, minute: 7, repeat: true, isEnabled: enabled);

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('bclock/window'), (_) async => null);
    syncs.clear();
    succeed = true;
    service
      ..syncDelay = Duration.zero
      ..syncScheduler = (alarms) async {
        syncs.add([for (final a in alarms) a.id]);
        return succeed;
      };
    SharedPreferences.setMockInitialValues({});
    await service.load();
    await service.syncNow(); // clear a failure left by the previous test
    syncs.clear();
  });

  test('the script verifies one task per enabled alarm', () {
    final script = AlarmScheduler.buildScript(
      [alarm('a'), alarm('b')],
      r'C:\Apps\bClock\bclock.exe',
      r'C:\Apps\bClock',
    );

    expect("Register-ScheduledTask".allMatches(script).length, 2);
    expect(script, contains(".Count -ne 2) { exit 3 }"));
  });

  test('a failed sync is remembered, and a later success clears it', () async {
    var notified = 0;
    void listener() => notified++;
    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    succeed = false;
    service.setAlarms([alarm('a')]);
    await pumpEventQueue();
    expect(service.schedulerFailed, isTrue);
    expect(notified, greaterThanOrEqualTo(2)); // the change, then the failure

    succeed = true;
    await service.syncNow(); // "Try again"
    expect(service.schedulerFailed, isFalse);
  });

  test('syncs never overlap; changes during one cause exactly one more',
      () async {
    final gate = Completer<bool>();
    var running = 0;
    var maxRunning = 0;
    service.syncScheduler = (alarms) async {
      syncs.add([for (final a in alarms) a.id]);
      running++;
      if (running > maxRunning) maxRunning = running;
      final ok = syncs.length == 1 ? await gate.future : true;
      running--;
      return ok;
    };

    service.setAlarms([alarm('a')]); // starts the first sync, held open
    service.setAlarms([alarm('a'), alarm('b')]);
    service.setAlarms([alarm('a'), alarm('b'), alarm('c')]);
    await pumpEventQueue();
    expect(syncs, [
      ['a']
    ]);

    gate.complete(true);
    await pumpEventQueue();
    expect(maxRunning, 1);
    // One more run, with the list as it was by then, not one per change.
    expect(syncs, [
      ['a'],
      ['a', 'b', 'c'],
    ]);
  });

  testWidgets('edits settle before the tasks are re-registered',
      (tester) async {
    service.syncDelay = const Duration(seconds: 1);

    service.setAlarms([alarm('a')]);
    await tester.pump(const Duration(milliseconds: 500));
    service.setAlarms([alarm('a'), alarm('b')]);
    await tester.pump(const Duration(milliseconds: 500));
    expect(syncs, isEmpty); // the second edit restarted the wait

    await tester.pump(const Duration(milliseconds: 600));
    expect(syncs, [
      ['a', 'b']
    ]);
  });

  testWidgets('the Alarm tab warns when scheduling failed; Try again clears',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'flutter.${AlarmService.alarmsStorageKey}':
          jsonEncode([alarm('a').toJson()]),
    });
    final provider = AppProvider();
    await tester.runAsync(provider.load);
    await tester.runAsync(service.load);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const AlarmScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    const warning = "Alarms can't be scheduled with Windows";
    expect(find.text(warning), findsNothing);

    succeed = false;
    await tester.runAsync(service.syncNow);
    await tester.pumpAndSettle();
    expect(find.text(warning), findsOneWidget);
    expect(find.text('They will only ring while bClock is running.'),
        findsOneWidget);

    succeed = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text(warning), findsNothing);
  });
}
