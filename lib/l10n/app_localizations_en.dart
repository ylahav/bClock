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
  String get navTimer => 'Timer';

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
  String get miniMode => 'Mini mode';

  @override
  String get exitMiniMode => 'Exit mini mode';

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
  String get timerTitle => 'Timer';

  @override
  String get resume => 'Resume';

  @override
  String get timesUp => 'Time\'s up';

  @override
  String get plusOneMinute => '+1 min';

  @override
  String get addMinute => 'Add 1 minute';

  @override
  String get removeMinute => 'Remove 1 minute';

  @override
  String presetMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get timeLeft => 'Time left';

  @override
  String get customDuration => 'Custom…';

  @override
  String get setTimerTitle => 'Set timer';

  @override
  String get hours => 'Hours';

  @override
  String get minutes => 'Minutes';

  @override
  String get seconds => 'Seconds';

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
  String get moveCityEarlier => 'Move earlier';

  @override
  String get moveCityLater => 'Move later';

  @override
  String get planMeeting => 'Plan a meeting';

  @override
  String get planNow => 'Now';

  @override
  String planSummary(int count, int total) {
    return '$count of $total in working hours';
  }

  @override
  String get workingHours => 'Working hours';

  @override
  String get meetingTime => 'Meeting time';

  @override
  String get searchCities => 'Search cities…';

  @override
  String get alarmsTitle => 'Alarms';

  @override
  String get schedulerFailedTitle => 'Alarms can\'t be scheduled with Windows';

  @override
  String get schedulerFailedBody =>
      'They will only ring while bClock is running.';

  @override
  String get tryAgain => 'Try again';

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
  String get closeToTray => 'Keep running in the tray';

  @override
  String get closeToTrayHint =>
      'Closing the window hides bClock in the tray, so alarms and timers keep working';

  @override
  String get trayShow => 'Show bClock';

  @override
  String get trayQuit => 'Quit';

  @override
  String get trayHintTitle => 'bClock is still running';

  @override
  String get trayHintBody =>
      'Alarms and timers keep working. Right-click the tray icon to quit.';

  @override
  String get sectionUnanswered => 'Unanswered alarms';

  @override
  String get retryCount => 'Ring again';

  @override
  String get retryCountHint =>
      'How many more times an alarm rings if nobody answers it (0 = it rings once)';

  @override
  String get retryInterval => 'Minutes between rings';

  @override
  String get retryIntervalHint => 'Each ring lasts one minute';

  @override
  String get missedAlarm => 'Missed alarm';

  @override
  String get sectionAlarmSound => 'Alarm sound';

  @override
  String get alarmSound => 'Sound';

  @override
  String get alarmSoundHint => 'Played by alarms and the timer';

  @override
  String get soundBeeps => 'Beeps';

  @override
  String get soundChime => 'Chime';

  @override
  String get soundPulse => 'Soft pulse';

  @override
  String get soundCustom => 'Your own file…';

  @override
  String get chooseFile => 'Choose file…';

  @override
  String get soundFileMissing => 'File not found. Beeps will play instead.';

  @override
  String get alarmVolume => 'Volume';

  @override
  String get fadeIn => 'Increase volume gradually';

  @override
  String get fadeInHint =>
      'Start quietly and reach full volume over 30 seconds';

  @override
  String get previewSound => 'Preview';

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

  @override
  String elapsedDurationWithHours(int hours, int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    String _temp2 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0, $_temp1, $_temp2';
  }
}
