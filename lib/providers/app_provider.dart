import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

enum ClockView { analog, digital, both }

enum DigitalPosition { above, below }

enum ClockSizeOption { small, medium, large }

/// First day of the week in the UI. Display order only — alarm days are
/// always stored Monday-first (see [AlarmModel.days]).
enum WeekStart {
  monday,
  sunday;

  /// Storage indices (0 = Mon … 6 = Sun) in display order.
  List<int> get dayOrder => switch (this) {
        WeekStart.monday => const [0, 1, 2, 3, 4, 5, 6],
        WeekStart.sunday => const [6, 0, 1, 2, 3, 4, 5],
      };
}

class AppProvider extends ChangeNotifier {
  static const _kTheme = 'themeMode';
  static const _kView = 'clockView';
  static const _kPos = 'digitalPosition';
  static const _kSize = 'clockSize';
  static const _kOnTop = 'alwaysOnTop';
  static const _kShowNav = 'showNav';
  static const _kLocale = 'locale';
  static const _kWeekStart = 'weekStart';

  ThemeMode _themeMode = ThemeMode.dark;
  ClockView _clockView = ClockView.digital;
  DigitalPosition _digitalPosition = DigitalPosition.below;
  ClockSizeOption _clockSize = ClockSizeOption.medium;
  bool _alwaysOnTop = false;
  bool _showNav = true;
  WeekStart _weekStart = WeekStart.monday;

  /// Language code (`en`, `fr`, …), or null to follow the OS locale.
  String? _languageCode;

  ThemeMode get themeMode => _themeMode;
  ClockView get clockView => _clockView;
  DigitalPosition get digitalPosition => _digitalPosition;
  ClockSizeOption get clockSize => _clockSize;
  bool get alwaysOnTop => _alwaysOnTop;
  bool get showNav => _showNav;
  WeekStart get weekStart => _weekStart;
  bool get isDark => _themeMode == ThemeMode.dark;
  String? get languageCode => _languageCode;
  Locale? get locale => _languageCode == null ? null : Locale(_languageCode!);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[p.getInt(_kTheme) ?? ThemeMode.dark.index];
    _clockView = ClockView.values[p.getInt(_kView) ?? ClockView.digital.index];
    _digitalPosition =
        DigitalPosition.values[p.getInt(_kPos) ?? DigitalPosition.below.index];
    _clockSize = ClockSizeOption
        .values[p.getInt(_kSize) ?? ClockSizeOption.medium.index];
    _alwaysOnTop = p.getBool(_kOnTop) ?? false;
    _showNav = p.getBool(_kShowNav) ?? true;
    _languageCode = p.getString(_kLocale);
    _weekStart =
        WeekStart.values[p.getInt(_kWeekStart) ?? WeekStart.monday.index];
    if (_alwaysOnTop) await windowManager.setAlwaysOnTop(true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setInt(_kTheme, _themeMode.index),
      p.setInt(_kView, _clockView.index),
      p.setInt(_kPos, _digitalPosition.index),
      p.setInt(_kSize, _clockSize.index),
      p.setBool(_kOnTop, _alwaysOnTop),
      p.setBool(_kShowNav, _showNav),
      p.setInt(_kWeekStart, _weekStart.index),
      _languageCode == null
          ? p.remove(_kLocale)
          : p.setString(_kLocale, _languageCode!),
    ]);
  }

  void toggleTheme() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    _save();
  }

  void setClockView(ClockView view) {
    _clockView = view;
    notifyListeners();
    _save();
  }

  void setDigitalPosition(DigitalPosition pos) {
    _digitalPosition = pos;
    notifyListeners();
    _save();
  }

  void setClockSize(ClockSizeOption size) {
    _clockSize = size;
    notifyListeners();
    _save();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    _alwaysOnTop = value;
    await windowManager.setAlwaysOnTop(value);
    notifyListeners();
    _save();
  }

  /// Pass null to follow the OS locale.
  void setLanguageCode(String? code) {
    _languageCode = code;
    notifyListeners();
    _save();
  }

  void setWeekStart(WeekStart value) {
    _weekStart = value;
    notifyListeners();
    _save();
  }

  void toggleNav() {
    _showNav = !_showNav;
    notifyListeners();
    _save();
  }
}
