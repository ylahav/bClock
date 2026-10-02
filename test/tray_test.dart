import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
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

  test('closing to the tray is on by default', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    await provider.load();
    expect(provider.closeToTray, isTrue);
  });

  testWidgets('the tray setting is switched off in Settings and saved',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 2400);
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

    final toggle =
        find.widgetWithText(PlinthSwitch, 'Keep running in the tray');
    expect(tester.widget<PlinthSwitch>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(provider.closeToTray, isFalse);

    final reloaded = AppProvider();
    await tester.runAsync(reloaded.load);
    expect(reloaded.closeToTray, isFalse);
  });
}
