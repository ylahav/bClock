import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bclock/l10n/app_localizations.dart';
import 'package:bclock/models/sound_options.dart';
import 'package:bclock/providers/app_provider.dart';
import 'package:bclock/screens/settings_screen.dart';
import 'package:bclock/services/alarm_service.dart';
import 'package:bclock/services/chime_service.dart';

/// Counts chimes instead of playing them.
class FakeAudio implements RingAudio {
  final played = <({String? asset, bool loop, double volume})>[];

  @override
  Future<void> play({
    String? asset,
    String? file,
    required bool loop,
    required double volume,
  }) async =>
      played.add((asset: asset, loop: loop, volume: volume));

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() {}
}

void main() {
  final chime = ChimeService.instance;
  late FakeAudio audio;
  late DateTime clock;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('bclock/window'), (_) async => null);
    audio = FakeAudio();
    chime
      ..audio = audio
      ..now = () => clock;
    AlarmService.instance.sound = const SoundOptions();
  });
  // Off again, so no hour timer is left pending.
  tearDown(() => chime.configure(enabled: false, fromHour: 8, untilHour: 22));

  /// Moves the test's clock and the fake timers forward together.
  Future<void> advance(WidgetTester tester, Duration d) async {
    clock = clock.add(d);
    await tester.pump(d);
  }

  testWidgets('it chimes at the top of each hour, at the alarm volume',
      (tester) async {
    clock = DateTime(2026, 10, 5, 9, 59, 30);
    AlarmService.instance.sound = const SoundOptions(volume: 0.4);
    chime.configure(enabled: true, fromHour: 8, untilHour: 22);

    await advance(tester, const Duration(seconds: 29));
    expect(audio.played, isEmpty); // 9:59:59

    await advance(tester, const Duration(seconds: 1));
    expect(
        audio.played, [(asset: 'sounds/hour.wav', loop: false, volume: 0.4)]);

    await advance(tester, const Duration(hours: 1));
    expect(audio.played.length, 2); // 11:00, rearmed by itself
    chime.configure(enabled: false, fromHour: 8, untilHour: 22);
  });

  testWidgets('it stays quiet outside the chosen hours', (tester) async {
    clock = DateTime(2026, 10, 5, 21, 30);
    chime.configure(enabled: true, fromHour: 8, untilHour: 22);

    await advance(tester, const Duration(minutes: 30));
    expect(audio.played.length, 1); // 22:00 is included
    await advance(tester, const Duration(hours: 1));
    expect(audio.played.length, 1); // 23:00 is not
    // …and stays quiet through the night, hour by hour, until 8:00.
    for (var hour = 0; hour <= 7; hour++) {
      await advance(tester, const Duration(hours: 1));
      expect(audio.played.length, 1, reason: 'at $hour:00');
    }
    await advance(tester, const Duration(hours: 1));
    expect(audio.played.length, 2); // 8:00
    chime.configure(enabled: false, fromHour: 8, untilHour: 22);
  });

  test('a range can wrap past midnight', () {
    chime.configure(enabled: false, fromHour: 22, untilHour: 6);

    expect(chime.chimesAt(23), isTrue);
    expect(chime.chimesAt(0), isTrue);
    expect(chime.chimesAt(6), isTrue);
    expect(chime.chimesAt(7), isFalse);
    expect(chime.chimesAt(21), isFalse);
  });

  testWidgets('switched off, nothing is scheduled', (tester) async {
    clock = DateTime(2026, 10, 5, 9, 59);
    chime.configure(enabled: true, fromHour: 8, untilHour: 22);
    chime.configure(enabled: false, fromHour: 8, untilHour: 22);

    await advance(tester, const Duration(hours: 3));
    expect(audio.played, isEmpty);
  });

  testWidgets('a timer that fires late, after sleep, does not chime',
      (tester) async {
    clock = DateTime(2026, 10, 5, 9, 59);
    chime.configure(enabled: true, fromHour: 8, untilHour: 22);

    // The PC slept: the timer fires, but the clock says 10:37.
    clock = DateTime(2026, 10, 5, 10, 37);
    await tester.pump(const Duration(minutes: 1));
    expect(audio.played, isEmpty);

    // It rearmed for the next real hour.
    await advance(tester, const Duration(minutes: 23));
    expect(audio.played.length, 1);
    chime.configure(enabled: false, fromHour: 8, untilHour: 22);
  });

  testWidgets('Settings: off by default; switching on plays it and saves',
      (tester) async {
    clock = DateTime(2026, 10, 5, 9, 10);
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 3400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = AppProvider();
    await tester.runAsync(provider.load);
    expect(provider.hourlyChime, isFalse);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chime between'), findsNothing); // hours hidden while off

    await tester.tap(find.widgetWithText(PlinthSwitch, 'Chime every hour'));
    await tester.pumpAndSettle();
    expect(audio.played.length, 1); // you hear what you switched on
    expect(find.text('Chime between'), findsOneWidget);

    provider.setChimeHours(from: 7, until: 20);
    await tester.pumpAndSettle();
    expect(chime.chimesAt(7), isTrue);
    expect(chime.chimesAt(21), isFalse);

    final reloaded = AppProvider();
    await tester.runAsync(reloaded.load);
    expect(reloaded.hourlyChime, isTrue);
    expect(reloaded.chimeFromHour, 7);
    expect(reloaded.chimeUntilHour, 20);
  });

  testWidgets('the hour fields fit a narrow window in every language',
      (tester) async {
    clock = DateTime(2026, 10, 5, 9, 10);
    addTearDown(tester.view.reset);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final width in [240.0, 300.0]) {
        SharedPreferences.setMockInitialValues({});
        final provider = AppProvider();
        await tester.runAsync(provider.load);
        tester.view.physicalSize = Size(width, 3600);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const SettingsScreen(),
          ),
        ));
        provider.setHourlyChime(true);
        await tester.pumpAndSettle();

        expect(find.byType(PlinthNumberInput), findsNWidgets(4));
        expect(tester.takeException(), isNull, reason: '$locale at $width');
      }
    }
    chime.configure(enabled: false, fromHour: 8, untilHour: 22);
  });
}
