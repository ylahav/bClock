import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bclock/l10n/app_localizations.dart';
import 'package:bclock/models/alarm_model.dart';
import 'package:bclock/providers/app_provider.dart';
import 'package:bclock/screens/settings_screen.dart';
import 'package:bclock/services/alarm_service.dart';
import 'package:bclock/services/app_window.dart';
import 'package:bclock/services/notification_service.dart';

/// Records toasts instead of showing them.
class FakeNotifications extends NotificationService {
  final shown = <({String title, String body, List<String> keys})>[];
  int? lastId;

  @override
  Future<void> show(
    int id, {
    required String title,
    required String body,
    required Map<String, String> actions,
    required ValueChanged<String> onAction,
  }) async {
    lastId = id;
    shown.add((title: title, body: body, keys: actions.keys.toList()));
    await super.show(id,
        title: title, body: body, actions: actions, onAction: onAction);
  }

  void press(String key) => handleResponse(lastId, key);
}

void main() {
  AppWindow.raise = () async {}; // no window plugin in tests
  final navigatorKey = GlobalKey<NavigatorState>();
  late FakeNotifications toasts;
  var rings = 0;
  final service = AlarmService.instance
    ..navigatorKey = navigatorKey
    ..syncDelay = Duration.zero
    ..syncScheduler = (_) async {
      return true;
    }
    ..playSound = () async {
      rings++;
    }
    ..silenceSound = () async {};

  // 03:07 is far from the current minute, so only the test rings it. Each
  // test uses its own id: fireById won't ring one alarm twice in a minute.
  AlarmModel alarm(String id, {bool enabled = true}) =>
      AlarmModel(id: id, hour: 3, minute: 7, label: 'Pills', repeat: true)
        ..isEnabled = enabled;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('bclock/window'), (_) async => null);
    toasts = FakeNotifications();
    NotificationService.instance = toasts;
    rings = 0;
    service
      ..retries = 2
      ..retryInterval = const Duration(minutes: 5);
  });

  Future<void> pumpApp(WidgetTester tester, String id) async {
    SharedPreferences.setMockInitialValues({
      'flutter.${AlarmService.alarmsStorageKey}':
          jsonEncode([alarm(id).toJson()]),
    });
    await tester.runAsync(service.load);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SizedBox(),
    ));
  }

  /// Lets a ring go unanswered for its full minute.
  Future<void> ignoreRing(WidgetTester tester) async {
    await tester.pump(AlarmService.ringDuration);
    await tester.pumpAndSettle();
  }

  bool ringing() => find.text('03:07').evaluate().isNotEmpty;

  testWidgets('an unanswered alarm rings again, then gives up', (tester) async {
    await pumpApp(tester, 'again');
    service.fireById('again');
    await tester.pumpAndSettle();
    expect(rings, 1);
    expect(ringing(), isTrue);

    // Each ring stops by itself after a minute…
    await ignoreRing(tester);
    expect(ringing(), isFalse);
    // …and it rings again only after the wait.
    await tester.pump(const Duration(minutes: 4, seconds: 59));
    expect(rings, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(rings, 2);
    expect(ringing(), isTrue);

    await ignoreRing(tester);
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(rings, 3); // the first ring plus 2 retries
    await ignoreRing(tester);

    // Out of retries: a note of what was missed, and no more rings.
    expect(toasts.shown.last.title, 'Missed alarm');
    expect(toasts.shown.last.body, '03:07  Pills');
    expect(toasts.shown.last.keys, isEmpty);
    await tester.pump(const Duration(hours: 1));
    expect(rings, 3);
    expect(ringing(), isFalse);
  });

  testWidgets('with no retries it rings once', (tester) async {
    service.retries = 0;
    await pumpApp(tester, 'once');
    service.fireById('once');
    await tester.pumpAndSettle();
    await ignoreRing(tester);

    expect(toasts.shown.last.title, 'Missed alarm');
    await tester.pump(const Duration(hours: 1));
    expect(rings, 1);
  });

  testWidgets('Dismiss ends it: no retry follows', (tester) async {
    await pumpApp(tester, 'dismiss');
    service.fireById('dismiss');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(hours: 1));

    expect(rings, 1);
    expect(toasts.shown.where((t) => t.title == 'Missed alarm'), isEmpty);
  });

  testWidgets('answering a retry counts as answered', (tester) async {
    await pumpApp(tester, 'retry');
    service.fireById('retry');
    await tester.pumpAndSettle();
    await ignoreRing(tester);
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(rings, 2);

    toasts.press('dismiss'); // from the toast, on the second ring
    await tester.pumpAndSettle();
    await tester.pump(const Duration(hours: 1));

    expect(rings, 2);
    expect(toasts.shown.where((t) => t.title == 'Missed alarm'), isEmpty);
  });

  testWidgets('a snoozed alarm gets its full retries again', (tester) async {
    service.retries = 1;
    await pumpApp(tester, 'snooze');
    service.fireById('snooze');
    await tester.pumpAndSettle();
    await ignoreRing(tester);
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(rings, 2); // the one retry is used up

    await tester.tap(find.textContaining('Snooze'));
    await tester.pumpAndSettle();
    await tester.pump(AlarmService.snoozeDuration);
    await tester.pumpAndSettle();
    expect(rings, 3); // the snooze

    await ignoreRing(tester);
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(rings, 4); // a fresh retry after the snooze
    await ignoreRing(tester);
    expect(toasts.shown.last.title, 'Missed alarm');
  });

  testWidgets('switching the alarm off cancels its pending retry',
      (tester) async {
    await pumpApp(tester, 'off');
    service.fireById('off');
    await tester.pumpAndSettle();
    await ignoreRing(tester);

    service.setAlarms([alarm('off', enabled: false)]);
    await tester.pump(const Duration(hours: 1));

    expect(rings, 1);
  });

  testWidgets('Settings: both values default, save, and reach the service',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = AppProvider();
    await tester.runAsync(provider.load);
    expect(provider.alarmRetries, 3);
    expect(provider.alarmRetryMinutes, 5);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ring again'), findsOneWidget);
    expect(find.text('Minutes between rings'), findsOneWidget);

    final inputs = find.byType(PlinthNumberInput);
    tester.widget<PlinthNumberInput>(inputs.at(0)).onChanged!(1);
    await tester.pumpAndSettle();
    tester.widget<PlinthNumberInput>(inputs.at(1)).onChanged!(10);
    await tester.pumpAndSettle();

    expect(service.retries, 1);
    expect(service.retryInterval, const Duration(minutes: 10));
    final reloaded = AppProvider();
    await tester.runAsync(reloaded.load);
    expect(reloaded.alarmRetries, 1);
    expect(reloaded.alarmRetryMinutes, 10);

    // With no retries there is nothing to wait between.
    tester.widget<PlinthNumberInput>(inputs.at(0)).onChanged!(0);
    await tester.pumpAndSettle();
    expect(tester.widget<PlinthNumberInput>(inputs.at(1)).enabled, isFalse);
  });
}
