import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:plinth_components/plinth_components.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:window_manager/window_manager.dart';
import 'l10n/app_localizations.dart';
import 'l10n/plinth_strings_delegate.dart';
import 'providers/app_provider.dart';
import 'services/alarm_service.dart';
import 'theme/app_theme.dart';
import 'screens/clock_screen.dart';
import 'screens/stopwatch_screen.dart';
import 'screens/world_clock_screen.dart';
import 'screens/alarm_screen.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

/// Parses `--fire <id>` (or `--fire=<id>`) out of the process args. Returns
/// null if the flag isn't present.
String? _parseFireArg(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--fire' && i + 1 < args.length) return args[i + 1];
    if (a.startsWith('--fire=')) return a.substring('--fire='.length);
  }
  return null;
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await windowManager.ensureInitialized();

  final appProvider = AppProvider();
  await appProvider.load();

  AlarmService.instance.navigatorKey = _navigatorKey;
  AlarmService.instance.start();

  // `--fire <alarmId>` is passed by the Windows Task Scheduler entry when
  // an alarm fires while the app is closed. Trigger the popup after the
  // first frame so the Navigator is mounted.
  final fireId = _parseFireArg(args);
  if (fireId != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlarmService.instance.fireById(fireId);
    });
  }

  const windowOptions = WindowOptions(
    size: Size(340, 300),
    minimumSize: Size(240, 240),
    title: 'bClock',
    titleBarStyle: TitleBarStyle.normal,
    center: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ChangeNotifierProvider.value(
      value: appProvider,
      child: const BClockApp(),
    ),
  );
}

class BClockApp extends StatelessWidget {
  const BClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return MaterialApp(
          title: 'bClock',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: provider.themeMode,
          locale: provider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            PlinthStringsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = context.plinth;
    final l = AppLocalizations.of(context);

    final screens = [
      ClockScreen(active: _currentIndex == 0),
      const StopwatchScreen(),
      const WorldClockScreen(),
      const AlarmScreen(),
    ];

    return Scaffold(
      // Clip so a screen overflowing the compact window can't paint under
      // the transparent nav handle.
      body: ClipRect(
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle — always visible, toggles nav
          GestureDetector(
            onTap: provider.toggleNav,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: AnimatedRotation(
                  turns: provider.showNav ? 0 : 0.5,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: theme.textDisabled,
                  ),
                ),
              ),
            ),
          ),
          // Navigation bar — animated show / hide
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: provider.showNav
                ? NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (i) =>
                        setState(() => _currentIndex = i),
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.access_time_outlined),
                        selectedIcon: const Icon(Icons.access_time_filled),
                        label: l.navClock,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.timer_outlined),
                        selectedIcon: const Icon(Icons.timer),
                        label: l.navStopwatch,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.language_outlined),
                        selectedIcon: const Icon(Icons.language),
                        label: l.navWorld,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.alarm_outlined),
                        selectedIcon: const Icon(Icons.alarm),
                        label: l.navAlarm,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
