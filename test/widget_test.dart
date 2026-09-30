import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bclock/l10n/app_localizations.dart';
import 'package:bclock/providers/app_provider.dart';
import 'package:bclock/screens/settings_screen.dart';
import 'package:bclock/screens/stopwatch_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home, {Locale? locale}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
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
}
