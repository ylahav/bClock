import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bclock/l10n/app_localizations.dart';
import 'package:bclock/providers/app_provider.dart';
import 'package:bclock/screens/settings_screen.dart';

void main() {
  // AppProvider.load sets the title bar through the runner's channel.
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized()
      .defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('bclock/window'), (_) async => null));

  testWidgets('Settings fits narrow windows in every language',
      (tester) async {
    addTearDown(tester.view.reset);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final width in [240.0, 280.0, 340.0]) {
        // "Both" shows every segmented control, digital position included.
        SharedPreferences.setMockInitialValues({
          'flutter.clockView': ClockView.both.index,
          'flutter.locale': locale.languageCode,
        });
        final provider = AppProvider();
        await tester.runAsync(provider.load);
        tester.view.physicalSize = Size(width, 2400);
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
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$locale at $width');
      }
    }
  });
}
