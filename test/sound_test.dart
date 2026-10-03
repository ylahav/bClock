import 'dart:io';

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

/// Records what would be played instead of playing it.
class FakeAudio implements RingAudio {
  String? asset;
  String? file;
  bool? loop;
  bool playing = false;
  final volumes = <double>[];

  double get volume => volumes.last;

  @override
  Future<void> play({
    String? asset,
    String? file,
    required bool loop,
    required double volume,
  }) async {
    this.asset = asset;
    this.file = file;
    this.loop = loop;
    playing = true;
    volumes.add(volume);
  }

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> stop() async => playing = false;

  @override
  void dispose() {}
}

void main() {
  final service = AlarmService.instance;
  late FakeAudio audio;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('bclock/window'), (_) async => null);
    audio = FakeAudio();
    service
      ..audio = audio
      ..sound = const SoundOptions();
  });

  test('by default the ring loops Beeps at full volume', () async {
    await service.startSound();

    expect(audio.asset, 'sounds/alarm.wav');
    expect(audio.file, isNull);
    expect(audio.loop, isTrue);
    expect(audio.volume, 1.0);

    await service.stopSound();
    expect(audio.playing, isFalse);
  });

  test('the chosen sound and volume are used', () async {
    service.sound = const SoundOptions(sound: AlarmSound.chime, volume: 0.6);
    await service.startSound();

    expect(audio.asset, 'sounds/chime.wav');
    expect(audio.volume, 0.6);
    await service.stopSound();
  });

  testWidgets('with fade-in the volume climbs to the set level in 30 s',
      (tester) async {
    service.sound = const SoundOptions(volume: 0.8, fadeIn: true);
    await service.startSound();
    expect(audio.volume, closeTo(0.8 * 0.15, 1e-9)); // quiet, not silent

    await tester.pump(const Duration(seconds: 15));
    expect(audio.volume, closeTo(0.12 + (0.8 - 0.12) / 2, 0.02)); // halfway

    await tester.pump(const Duration(seconds: 15));
    expect(audio.volume, closeTo(0.8, 1e-9));
    // It stops there: no further steps, and never above the set volume.
    final steps = audio.volumes.length;
    await tester.pump(const Duration(seconds: 10));
    expect(audio.volumes.length, steps);
    expect(audio.volumes.every((v) => v <= 0.8 + 1e-9), isTrue);
    await service.stopSound();
  });

  testWidgets('dismissing mid-fade stops the climb', (tester) async {
    service.sound = const SoundOptions(fadeIn: true);
    await service.startSound();
    await tester.pump(const Duration(seconds: 5));

    await service.stopSound();
    final steps = audio.volumes.length;
    await tester.pump(const Duration(seconds: 30));

    expect(audio.playing, isFalse);
    expect(audio.volumes.length, steps);
  });

  test("the user's own file is played while it exists", () async {
    final dir = Directory.systemTemp.createTempSync('bclock_sound_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}mine.wav')
      ..writeAsBytesSync([0]);
    service.sound =
        SoundOptions(sound: AlarmSound.custom, customPath: file.path);

    await service.startSound();
    expect(audio.file, file.path);
    expect(audio.asset, isNull);

    // Moved or deleted: the ring must not go silent.
    file.deleteSync();
    await service.startSound();
    expect(audio.file, isNull);
    expect(audio.asset, 'sounds/alarm.wav');
    await service.stopSound();
  });

  testWidgets('Preview plays once at the set volume and cuts off',
      (tester) async {
    service.sound =
        const SoundOptions(sound: AlarmSound.pulse, volume: 0.5, fadeIn: true);
    await service.preview();

    expect(audio.asset, 'sounds/pulse.wav');
    expect(audio.loop, isFalse);
    expect(audio.volume, 0.5); // no fade in a preview
    expect(audio.playing, isTrue);

    await tester.pump(AlarmService.previewLimit);
    expect(audio.playing, isFalse);
  });

  group('Settings', () {
    Future<AppProvider> pumpSettings(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = AppProvider();
      await tester.runAsync(provider.load);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SettingsScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      return provider;
    }

    testWidgets('sound, volume and fade-in are saved and reach the ring',
        (tester) async {
      final provider = await pumpSettings(tester);

      provider.setSound(provider.sound.copyWith(sound: AlarmSound.chime));
      await tester.pumpAndSettle();
      tester.widget<PlinthSlider>(find.byType(PlinthSlider)).onChanged!(0.4);
      await tester
          .pumpAndSettle(); // as a real frame would, before the next input
      await tester
          .tap(find.widgetWithText(PlinthSwitch, 'Increase volume gradually'));
      await tester.pumpAndSettle();

      expect(find.text('40%'), findsOneWidget);
      // AlarmService holds the same settings…
      expect(service.sound.sound, AlarmSound.chime);
      expect(service.sound.volume, 0.4);
      expect(service.sound.fadeIn, isTrue);
      // …and they survive a restart.
      final reloaded = AppProvider();
      await tester.runAsync(reloaded.load);
      expect(reloaded.sound.sound, AlarmSound.chime);
      expect(reloaded.sound.volume, 0.4);
      expect(reloaded.sound.fadeIn, isTrue);
    });

    testWidgets('choosing your own file asks for it, and shows its name',
        (tester) async {
      final provider = await pumpSettings(tester);
      final original = SettingsScreen.pickSoundFile;
      addTearDown(() => SettingsScreen.pickSoundFile = original);
      SettingsScreen.pickSoundFile = () async => r'C:\Music\wake up.mp3';

      await tester.tap(find.byType(PlinthSelect<AlarmSound>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Your own file…').last);
      await tester.pumpAndSettle();

      expect(provider.sound.sound, AlarmSound.custom);
      expect(provider.sound.customPath, r'C:\Music\wake up.mp3');
      expect(find.text('wake up.mp3'), findsOneWidget);
      // That path doesn't exist here, so the screen says what will play.
      expect(find.text('File not found. Beeps will play instead.'),
          findsOneWidget);
    });

    testWidgets('cancelling the file dialog keeps the previous sound',
        (tester) async {
      final provider = await pumpSettings(tester);
      final original = SettingsScreen.pickSoundFile;
      addTearDown(() => SettingsScreen.pickSoundFile = original);
      SettingsScreen.pickSoundFile = () async => null;

      await tester.tap(find.byType(PlinthSelect<AlarmSound>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Your own file…').last);
      await tester.pumpAndSettle();

      expect(provider.sound.sound, AlarmSound.beeps);
    });

    testWidgets('Preview plays the current sound', (tester) async {
      final provider = await pumpSettings(tester);
      provider.setSound(provider.sound.copyWith(sound: AlarmSound.pulse));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preview'));
      await tester.pump();

      expect(audio.asset, 'sounds/pulse.wav');
      expect(audio.loop, isFalse);
      await tester.pump(AlarmService.previewLimit); // let it cut off
    });
  });
}
