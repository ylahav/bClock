import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bclock/l10n/app_localizations.dart';
import 'package:bclock/providers/app_provider.dart';
import 'package:bclock/screens/clock_screen.dart';
import 'package:bclock/services/app_window.dart';
import 'package:bclock/services/mini_window.dart';
import 'package:bclock/widgets/mini_clock.dart';

void main() {
  // No window plugin in tests: record what the window would be asked to do.
  final windowCalls = <String>[];
  MiniWindow.enter = (size, {saveNormal = true}) async => windowCalls
      .add('enter ${size.width.round()}x${size.height.round()} $saveNormal');
  MiniWindow.exit =
      ({required alwaysOnTop}) async => windowCalls.add('exit $alwaysOnTop');
  AppWindow.raise = () async => windowCalls.add('raise');
  AppWindow.startDrag = () async => windowCalls.add('drag');

  setUp(() {
    windowCalls.clear();
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('bclock/window'), (_) async => null);
  });

  Future<AppProvider> load([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    final provider = AppProvider();
    await provider.load();
    return provider;
  }

  Widget app(AppProvider provider, Widget home) => ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: home,
        ),
      );

  test('entering sizes the window for the clock view, and is remembered',
      () async {
    final provider = await load({'flutter.clockView': ClockView.analog.index});
    expect(provider.miniMode, isFalse);

    await provider.setMiniMode(true);
    expect(windowCalls, ['enter 160x160 true']);

    final reopened = AppProvider();
    await reopened.load();
    expect(reopened.miniMode, isTrue);
  });

  test('leaving restores the window with the always-on-top setting', () async {
    final provider = await load({'flutter.miniMode': true});
    await provider.setMiniMode(false);

    expect(windowCalls, ['exit false']);
    expect(provider.miniMode, isFalse);
    // Asking for the mode it is already in does nothing.
    await provider.setMiniMode(false);
    expect(windowCalls, ['exit false']);
  });

  test('leaving restores the window before the app shows again', () async {
    // The Clock tab fits the window to its clock the moment it is showing;
    // if that ran at the mini width, it would override the restored size.
    final provider = await load({'flutter.miniMode': true});
    final original = MiniWindow.exit;
    addTearDown(() => MiniWindow.exit = original);
    bool? miniWhileRestoring;
    MiniWindow.exit = ({required alwaysOnTop}) async {
      miniWhileRestoring = provider.miniMode;
    };

    await provider.setMiniMode(false);

    expect(miniWhileRestoring, isTrue);
    expect(provider.miniMode, isFalse);
  });

  test('a ring leaves mini mode before showing the window', () async {
    final provider = await load({'flutter.miniMode': true});
    AppWindow.leaveMini = () => provider.setMiniMode(false);
    addTearDown(() => AppWindow.leaveMini = () async {});

    await AppWindow.showForPopup();

    expect(windowCalls, ['exit false', 'raise']);
    expect(provider.miniMode, isFalse);
  });

  testWidgets('the mini clock fits its window in every view', (tester) async {
    addTearDown(tester.view.reset);
    for (final view in ClockView.values) {
      final provider =
          await tester.runAsync(() => load({'flutter.clockView': view.index}));
      tester.view.physicalSize = provider!.miniWindowSize;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(app(
        provider,
        MiniClock(
          view: view,
          digitalPosition: DigitalPosition.below,
          onExit: () {},
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$view');
    }
  });

  testWidgets('drag moves the window; double-click and the hover button exit',
      (tester) async {
    tester.view.physicalSize = const Size(200, 84);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = await tester.runAsync(load);
    var exits = 0;
    await tester.pumpWidget(app(
      provider!,
      MiniClock(
        view: ClockView.digital,
        digitalPosition: DigitalPosition.below,
        onExit: () => exits++,
      ),
    ));

    await tester.drag(find.byType(MiniClock), const Offset(30, 10));
    expect(windowCalls, ['drag']);

    final centre = tester.getCenter(find.byType(MiniClock));
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(centre);
    await tester.pumpAndSettle();
    expect(exits, 1);

    // The exit button only shows while the pointer is over the clock.
    expect(find.byIcon(Icons.open_in_full), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: centre);
    addTearDown(mouse.removePointer);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.open_in_full));
    expect(exits, 2);
  });

  testWidgets("the Clock tab's button enters mini mode, and fits at 240 px",
      (tester) async {
    tester.view.physicalSize = const Size(240, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = await tester.runAsync(load);
    await tester.pumpWidget(app(provider!, const ClockScreen(active: false)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // three header buttons still fit

    await tester.tap(find.byIcon(Icons.picture_in_picture_alt_outlined));
    await tester.pump();

    expect(provider.miniMode, isTrue);
    expect(windowCalls, ['enter 200x84 true']);
  });
}
