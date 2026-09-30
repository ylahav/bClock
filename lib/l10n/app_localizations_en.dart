// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navClock => 'Clock';

  @override
  String get navStopwatch => 'Stopwatch';

  @override
  String get navWorld => 'World';

  @override
  String get navAlarm => 'Alarm';

  @override
  String get viewDigital => 'Digital';

  @override
  String get viewBoth => 'Both';

  @override
  String get viewAnalog => 'Analog';

  @override
  String get toggleTheme => 'Toggle theme';

  @override
  String get settings => 'Settings';

  @override
  String get hideControls => 'Hide controls';

  @override
  String get stopwatchTitle => 'Stopwatch';

  @override
  String get lap => 'Lap';

  @override
  String get reset => 'Reset';

  @override
  String get pause => 'Pause';

  @override
  String get start => 'Start';

  @override
  String get lapTime => 'Time';

  @override
  String lapNumber(int n) {
    return 'Lap $n';
  }

  @override
  String get worldTitle => 'World';

  @override
  String get addCity => 'Add city';

  @override
  String get addCityTitle => 'Add City';

  @override
  String get noCities => 'No cities added';

  @override
  String get addACity => 'Add a city';

  @override
  String removeCity(String city) {
    return 'Remove $city';
  }

  @override
  String get searchCities => 'Search cities…';

  @override
  String get alarmsTitle => 'Alarms';

  @override
  String get addAlarm => 'Add alarm';

  @override
  String get noAlarms => 'No alarms set';

  @override
  String get addAnAlarm => 'Add an alarm';

  @override
  String get labelTitle => 'Label';

  @override
  String get labelPlaceholder => 'e.g. Wake up, Meeting…';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get addLabel => 'Add label…';

  @override
  String get repeat => 'Repeat';

  @override
  String get alarmDisabled => 'Disabled';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get defaultAlarmWakeUp => 'Wake up';

  @override
  String get defaultAlarmMorning => 'Morning routine';

  @override
  String snooze(int minutes) {
    return 'Snooze $minutes min';
  }

  @override
  String get dismiss => 'Dismiss';

  @override
  String get sectionClockDisplay => 'Clock Display';

  @override
  String get defaultView => 'Default View';

  @override
  String get defaultViewHint => 'What to show on the clock screen';

  @override
  String get digitalPosition => 'Digital Position';

  @override
  String get digitalPositionHint =>
      'Where to place the digital clock when showing both';

  @override
  String get aboveAnalog => 'Above analog';

  @override
  String get belowAnalog => 'Below analog';

  @override
  String get clockSize => 'Clock Size';

  @override
  String get clockSizeHint => 'Scales both analog and digital displays';

  @override
  String get sizeSmall => 'Small';

  @override
  String get sizeMedium => 'Medium';

  @override
  String get sizeLarge => 'Large';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get usingDarkTheme => 'Using dark theme';

  @override
  String get usingLightTheme => 'Using light theme';

  @override
  String get sectionWindow => 'Window';

  @override
  String get alwaysOnTop => 'Always on Top';

  @override
  String get alwaysOnTopHint => 'Keep bClock above all other windows';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get language => 'Language';

  @override
  String get languageHint => 'Language of the interface';

  @override
  String get languageSystem => 'System default';

  @override
  String get a11yCloseDialog => 'Close dialog';

  @override
  String get a11yClearSearch => 'Clear search';

  @override
  String get a11yClearSelection => 'Clear selection';

  @override
  String get delete => 'Delete';

  @override
  String get deleteAlarmQuestion => 'Delete this alarm?';

  @override
  String get back => 'Back';

  @override
  String elapsedDuration(int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    String _temp1 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get weekStart => 'Week starts on';

  @override
  String get weekStartHint => 'First day shown in the alarm day picker';
}
