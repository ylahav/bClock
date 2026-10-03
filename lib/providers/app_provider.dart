import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../models/sound_options.dart';
import '../services/alarm_service.dart';
import '../services/chime_service.dart';
import '../services/mini_window.dart';
import '../services/tray_service.dart';

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
  static const _kCloseToTray = 'closeToTray';
  static const _kMini = 'miniMode';
  static const _kSound = 'alarmSound';
  static const _kSoundPath = 'alarmSoundPath';
  static const _kVolume = 'alarmVolume';
  static const _kFadeIn = 'alarmFadeIn';
  static const _kRetries = 'alarmRetries';
  static const _kRetryMinutes = 'alarmRetryMinutes';
  static const _kChime = 'hourlyChime';
  static const _kChimeFrom = 'chimeFromHour';
  static const _kChimeUntil = 'chimeUntilHour';
  static const _kShowNav = 'showNav';
  static const _kLocale = 'locale';
  static const _kWeekStart = 'weekStart';

  ThemeMode _themeMode = ThemeMode.dark;
  ClockView _clockView = ClockView.digital;
  DigitalPosition _digitalPosition = DigitalPosition.below;
  ClockSizeOption _clockSize = ClockSizeOption.medium;
  bool _alwaysOnTop = false;
  bool _closeToTray = true;
  bool _miniMode = false;
  SoundOptions _sound = const SoundOptions();
  int _alarmRetries = AlarmService.defaultRetries;
  bool _hourlyChime = false;
  int _chimeFromHour = ChimeService.defaultFromHour;
  int _chimeUntilHour = ChimeService.defaultUntilHour;
  int _alarmRetryMinutes = AlarmService.defaultRetryInterval.inMinutes;
  bool _showNav = true;
  WeekStart _weekStart = WeekStart.monday;

  /// Language code (`en`, `fr`, …), or null to follow the OS locale.
  String? _languageCode;

  ThemeMode get themeMode => _themeMode;
  ClockView get clockView => _clockView;
  DigitalPosition get digitalPosition => _digitalPosition;
  ClockSizeOption get clockSize => _clockSize;
  bool get alwaysOnTop => _alwaysOnTop;

  /// Whether closing the window hides bClock in the tray (on by default)
  /// rather than quitting. Applied by TrayService.
  bool get closeToTray => _closeToTray;

  /// Whether the window is the small, frameless, always-on-top clock.
  /// Remembered across restarts; main.dart applies it at startup.
  bool get miniMode => _miniMode;

  /// The mini window's size for the current clock view.
  Size get miniWindowSize => switch (_clockView) {
        ClockView.digital => const Size(200, 84),
        ClockView.analog => const Size(160, 160),
        ClockView.both => const Size(170, 236),
      };

  /// What a ringing alarm or timer plays. AlarmService holds a copy.
  SoundOptions get sound => _sound;

  /// How many more times an unanswered alarm rings (0 = once), and the
  /// minutes between rings. AlarmService holds copies.
  int get alarmRetries => _alarmRetries;
  int get alarmRetryMinutes => _alarmRetryMinutes;
  static const int maxAlarmRetries = 10;

  /// The hourly chime (off by default) and the hours of the day, both
  /// included, between which it sounds. ChimeService holds copies.
  bool get hourlyChime => _hourlyChime;
  int get chimeFromHour => _chimeFromHour;
  int get chimeUntilHour => _chimeUntilHour;
  static const int maxAlarmRetryMinutes = 60;
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
    _closeToTray = p.getBool(_kCloseToTray) ?? true;
    _miniMode = p.getBool(_kMini) ?? false;
    _sound = SoundOptions(
      sound: AlarmSound.values[p.getInt(_kSound) ?? AlarmSound.beeps.index],
      customPath: p.getString(_kSoundPath),
      volume: p.getDouble(_kVolume) ?? 1.0,
      fadeIn: p.getBool(_kFadeIn) ?? false,
    );
    AlarmService.instance.sound = _sound;
    _alarmRetries = p.getInt(_kRetries) ?? AlarmService.defaultRetries;
    _alarmRetryMinutes =
        p.getInt(_kRetryMinutes) ?? AlarmService.defaultRetryInterval.inMinutes;
    _applyRetries();
    _hourlyChime = p.getBool(_kChime) ?? false;
    _chimeFromHour = p.getInt(_kChimeFrom) ?? ChimeService.defaultFromHour;
    _chimeUntilHour = p.getInt(_kChimeUntil) ?? ChimeService.defaultUntilHour;
    _applyChime();
    _showNav = p.getBool(_kShowNav) ?? true;
    _languageCode = p.getString(_kLocale);
    _weekStart =
        WeekStart.values[p.getInt(_kWeekStart) ?? WeekStart.monday.index];
    if (_alwaysOnTop) await windowManager.setAlwaysOnTop(true);
    // Before the window is first shown, so the title bar never flashes
    // light on a dark start.
    await _applyWindowBrightness();
    notifyListeners();
  }

  /// Handled by the Windows runner (windows/runner/flutter_window.cpp).
  static const _windowChannel = MethodChannel('bclock/window');

  /// Matches the native Windows title bar to the app theme — Flutter only
  /// paints the client area. Not window_manager.setBrightness: that one
  /// refuses a dark title bar while Windows itself is in light mode.
  Future<void> _applyWindowBrightness() =>
      _windowChannel.invokeMethod('setDarkTitleBar', isDark);

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setInt(_kTheme, _themeMode.index),
      p.setInt(_kView, _clockView.index),
      p.setInt(_kPos, _digitalPosition.index),
      p.setInt(_kSize, _clockSize.index),
      p.setBool(_kOnTop, _alwaysOnTop),
      p.setBool(_kCloseToTray, _closeToTray),
      p.setBool(_kMini, _miniMode),
      p.setInt(_kSound, _sound.sound.index),
      _sound.customPath == null
          ? p.remove(_kSoundPath)
          : p.setString(_kSoundPath, _sound.customPath!),
      p.setDouble(_kVolume, _sound.volume),
      p.setBool(_kFadeIn, _sound.fadeIn),
      p.setInt(_kRetries, _alarmRetries),
      p.setInt(_kRetryMinutes, _alarmRetryMinutes),
      p.setBool(_kChime, _hourlyChime),
      p.setInt(_kChimeFrom, _chimeFromHour),
      p.setInt(_kChimeUntil, _chimeUntilHour),
      p.setBool(_kShowNav, _showNav),
      p.setInt(_kWeekStart, _weekStart.index),
      _languageCode == null
          ? p.remove(_kLocale)
          : p.setString(_kLocale, _languageCode!),
    ]);
  }

  void toggleTheme() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    _applyWindowBrightness();
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
    if (!_miniMode) await windowManager.setAlwaysOnTop(value);
    notifyListeners();
    _save();
  }

  /// Switches between the full app and the mini clock, resizing the window.
  Future<void> setMiniMode(bool value) async {
    if (_miniMode == value || _switchingMini) return;
    _switchingMini = true;
    try {
      if (value) {
        // Content first: the window never shows the full app squeezed
        // into the mini size.
        _setMini(true);
        await MiniWindow.enter(miniWindowSize);
      } else {
        // Window first: the Clock tab fits the window to its clock as soon
        // as it is showing again, and must measure the restored width, not
        // the mini one.
        await MiniWindow.exit(alwaysOnTop: _alwaysOnTop);
        _setMini(false);
      }
    } finally {
      _switchingMini = false;
    }
  }

  bool _switchingMini = false;

  void _setMini(bool value) {
    _miniMode = value;
    notifyListeners();
    _save();
  }

  Future<void> setCloseToTray(bool value) async {
    _closeToTray = value;
    await TrayService.instance.setCloseToTray(value);
    notifyListeners();
    _save();
  }

  /// Changes the ring settings, and hands them to AlarmService.
  void setSound(SoundOptions value) {
    _sound = value;
    AlarmService.instance.sound = value;
    notifyListeners();
    _save();
  }

  void setAlarmRetries(int value) {
    _alarmRetries = value.clamp(0, maxAlarmRetries);
    _applyRetries();
    notifyListeners();
    _save();
  }

  void setAlarmRetryMinutes(int value) {
    _alarmRetryMinutes = value.clamp(1, maxAlarmRetryMinutes);
    _applyRetries();
    notifyListeners();
    _save();
  }

  void _applyRetries() {
    AlarmService.instance
      ..retries = _alarmRetries
      ..retryInterval = Duration(minutes: _alarmRetryMinutes);
  }

  /// Switches the hourly chime; switching it on plays it once, so the
  /// user hears what they chose.
  void setHourlyChime(bool value) {
    _hourlyChime = value;
    _applyChime();
    if (value) ChimeService.instance.play();
    notifyListeners();
    _save();
  }

  void setChimeHours({int? from, int? until}) {
    _chimeFromHour = (from ?? _chimeFromHour).clamp(0, 23);
    _chimeUntilHour = (until ?? _chimeUntilHour).clamp(0, 23);
    _applyChime();
    notifyListeners();
    _save();
  }

  void _applyChime() {
    ChimeService.instance.configure(
      enabled: _hourlyChime,
      fromHour: _chimeFromHour,
      untilHour: _chimeUntilHour,
    );
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
