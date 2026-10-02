import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bclock/l10n/app_localizations.dart';
import 'package:bclock/models/alarm_model.dart';
import 'package:bclock/services/alarm_service.dart';
import 'package:bclock/services/app_window.dart';
import 'package:bclock/services/notification_service.dart';
import 'package:bclock/services/timer_service.dart';

/// Records toasts instead of showing them; [press] stands in for a click on
/// a toast button.
class FakeNotifications extends NotificationService {
  final shown = <int, ({String title, String body, List<String> keys})>{};
  final cancelled = <int>[];

  int get lastId => shown.keys.last;

  @override
  Future<void> show(
    int id, {
    required String title,
    required String body,
    required Map<String, String> actions,
    required ValueChanged<String> onAction,
  }) async {
    shown.remove(id); // keep insertion order = most recent last
    shown[id] = (title: title, body: body, keys: actions.keys.toList());
    await super.show(id,
        title: title, body: body, actions: actions, onAction: onAction);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    await super.cancel(id);
  }

  void press(int id, String key) => handleResponse(id, key);
}

void main() {
  late FakeNotifications toasts;
  final navigatorKey = GlobalKey<NavigatorState>();
  var silenced = 0;
  final alarms = AlarmService.instance
    ..navigatorKey = navigatorKey
    ..syncScheduler = (_) async {}
    ..playSound = () async {}
    ..silenceSound = () async {
      silenced++;
    };
  final timer = TimerService.instance
    ..navigatorKey = navigatorKey
    ..syncScheduler = (_) async {};

  var raised = 0;
  AppWindow.raise = () async {
    raised++;
  };

  setUp(() {
    raised = 0;
    toasts = FakeNotifications();
    NotificationService.instance = toasts;
    silenced = 0;
  });

  Future<void> pumpApp(WidgetTester tester, List<AlarmModel> list) async {
    SharedPreferences.setMockInitialValues({
      'flutter.${AlarmService.alarmsStorageKey}':
          jsonEncode([for (final a in list) a.toJson()]),
    });
    await alarms.load();
    await timer.load();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SizedBox(),
    ));
  }

  testWidgets('an alarm shows a toast; its Dismiss ends the ring',
      (tester) async {
    await pumpApp(tester, [
      AlarmModel(id: 'd', hour: 7, minute: 15, label: 'Gym', repeat: true),
    ]);
    final ringing = alarms.fireById('d');
    await tester.pumpAndSettle();

    final toast = toasts.shown[toasts.lastId]!;
    expect(toast.title, 'Gym');
    expect(toast.body, '07:15');
    expect(toast.keys, ['snooze', 'dismiss']);
    expect(find.text('07:15'), findsOneWidget); // the popup, too
    expect(raised, 1); // shown even if it was hidden in the tray

    toasts.press(toasts.lastId, 'dismiss');
    await tester.pumpAndSettle();
    await ringing;

    expect(find.text('07:15'), findsNothing); // popup closed
    expect(silenced, 1);
    expect(toasts.cancelled, [toasts.lastId]);
  });

  testWidgets("answering the popup withdraws the toast", (tester) async {
    await pumpApp(tester, [
      AlarmModel(id: 'p', hour: 6, minute: 0, repeat: true),
    ]);
    final ringing = alarms.fireById('p');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await ringing;

    expect(toasts.cancelled, [toasts.lastId]);
    expect(silenced, 1);
    // A late click on the withdrawn toast does nothing more.
    toasts.press(toasts.lastId, 'dismiss');
    expect(silenced, 1);
  });

  testWidgets('Snooze on the toast rings again five minutes later',
      (tester) async {
    await pumpApp(tester, [
      AlarmModel(id: 's', hour: 5, minute: 30, repeat: true),
    ]);
    final ringing = alarms.fireById('s');
    await tester.pumpAndSettle();
    final id = toasts.lastId;

    toasts.press(id, 'snooze');
    await tester.pumpAndSettle();
    await ringing;
    expect(find.text('05:30'), findsNothing);

    toasts.shown.clear();
    await tester.pump(AlarmService.snoozeDuration);
    await tester.pumpAndSettle();
    expect(toasts.shown.keys, [id]); // rang again
    expect(find.text('05:30'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
  });

  testWidgets("the timer's toast offers +1 min, which restarts it",
      (tester) async {
    await pumpApp(tester, []);
    timer.setDuration(const Duration(seconds: 5));
    timer.startOrResume();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    final toast = toasts.shown[toasts.lastId]!;
    expect(toast.title, "Time's up");
    expect(toast.keys, ['plus1', 'dismiss']);

    toasts.press(toasts.lastId, 'plus1');
    await tester.pumpAndSettle();
    expect(find.text("Time's up"), findsNothing);
    expect(timer.isRunning, isTrue);
    expect(timer.remaining().inSeconds, closeTo(60, 2));
    timer.reset(); // before the pending-Timer check, which precedes tearDown
  });
}
