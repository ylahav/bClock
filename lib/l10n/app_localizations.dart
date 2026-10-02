import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('he')
  ];

  /// No description provided for @navClock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get navClock;

  /// No description provided for @navStopwatch.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get navStopwatch;

  /// No description provided for @navTimer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get navTimer;

  /// No description provided for @navWorld.
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get navWorld;

  /// No description provided for @navAlarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get navAlarm;

  /// No description provided for @viewDigital.
  ///
  /// In en, this message translates to:
  /// **'Digital'**
  String get viewDigital;

  /// No description provided for @viewBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get viewBoth;

  /// No description provided for @viewAnalog.
  ///
  /// In en, this message translates to:
  /// **'Analog'**
  String get viewAnalog;

  /// No description provided for @toggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle theme'**
  String get toggleTheme;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @hideControls.
  ///
  /// In en, this message translates to:
  /// **'Hide controls'**
  String get hideControls;

  /// No description provided for @stopwatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get stopwatchTitle;

  /// No description provided for @lap.
  ///
  /// In en, this message translates to:
  /// **'Lap'**
  String get lap;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @timerTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timerTitle;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @timesUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up'**
  String get timesUp;

  /// No description provided for @plusOneMinute.
  ///
  /// In en, this message translates to:
  /// **'+1 min'**
  String get plusOneMinute;

  /// No description provided for @addMinute.
  ///
  /// In en, this message translates to:
  /// **'Add 1 minute'**
  String get addMinute;

  /// No description provided for @removeMinute.
  ///
  /// In en, this message translates to:
  /// **'Remove 1 minute'**
  String get removeMinute;

  /// No description provided for @presetMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String presetMinutes(int minutes);

  /// No description provided for @timeLeft.
  ///
  /// In en, this message translates to:
  /// **'Time left'**
  String get timeLeft;

  /// No description provided for @customDuration.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get customDuration;

  /// No description provided for @setTimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Set timer'**
  String get setTimerTitle;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get seconds;

  /// No description provided for @lapTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get lapTime;

  /// No description provided for @lapNumber.
  ///
  /// In en, this message translates to:
  /// **'Lap {n}'**
  String lapNumber(int n);

  /// No description provided for @worldTitle.
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get worldTitle;

  /// No description provided for @addCity.
  ///
  /// In en, this message translates to:
  /// **'Add city'**
  String get addCity;

  /// No description provided for @addCityTitle.
  ///
  /// In en, this message translates to:
  /// **'Add City'**
  String get addCityTitle;

  /// No description provided for @noCities.
  ///
  /// In en, this message translates to:
  /// **'No cities added'**
  String get noCities;

  /// No description provided for @addACity.
  ///
  /// In en, this message translates to:
  /// **'Add a city'**
  String get addACity;

  /// No description provided for @removeCity.
  ///
  /// In en, this message translates to:
  /// **'Remove {city}'**
  String removeCity(String city);

  /// No description provided for @moveCityEarlier.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get moveCityEarlier;

  /// No description provided for @moveCityLater.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get moveCityLater;

  /// No description provided for @searchCities.
  ///
  /// In en, this message translates to:
  /// **'Search cities…'**
  String get searchCities;

  /// No description provided for @alarmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get alarmsTitle;

  /// No description provided for @addAlarm.
  ///
  /// In en, this message translates to:
  /// **'Add alarm'**
  String get addAlarm;

  /// No description provided for @noAlarms.
  ///
  /// In en, this message translates to:
  /// **'No alarms set'**
  String get noAlarms;

  /// No description provided for @addAnAlarm.
  ///
  /// In en, this message translates to:
  /// **'Add an alarm'**
  String get addAnAlarm;

  /// No description provided for @labelTitle.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get labelTitle;

  /// No description provided for @labelPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Wake up, Meeting…'**
  String get labelPlaceholder;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @addLabel.
  ///
  /// In en, this message translates to:
  /// **'Add label…'**
  String get addLabel;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @alarmDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get alarmDisabled;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @defaultAlarmWakeUp.
  ///
  /// In en, this message translates to:
  /// **'Wake up'**
  String get defaultAlarmWakeUp;

  /// No description provided for @defaultAlarmMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning routine'**
  String get defaultAlarmMorning;

  /// No description provided for @snooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze {minutes} min'**
  String snooze(int minutes);

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @sectionClockDisplay.
  ///
  /// In en, this message translates to:
  /// **'Clock Display'**
  String get sectionClockDisplay;

  /// No description provided for @defaultView.
  ///
  /// In en, this message translates to:
  /// **'Default View'**
  String get defaultView;

  /// No description provided for @defaultViewHint.
  ///
  /// In en, this message translates to:
  /// **'What to show on the clock screen'**
  String get defaultViewHint;

  /// No description provided for @digitalPosition.
  ///
  /// In en, this message translates to:
  /// **'Digital Position'**
  String get digitalPosition;

  /// No description provided for @digitalPositionHint.
  ///
  /// In en, this message translates to:
  /// **'Where to place the digital clock when showing both'**
  String get digitalPositionHint;

  /// No description provided for @aboveAnalog.
  ///
  /// In en, this message translates to:
  /// **'Above analog'**
  String get aboveAnalog;

  /// No description provided for @belowAnalog.
  ///
  /// In en, this message translates to:
  /// **'Below analog'**
  String get belowAnalog;

  /// No description provided for @clockSize.
  ///
  /// In en, this message translates to:
  /// **'Clock Size'**
  String get clockSize;

  /// No description provided for @clockSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Scales both analog and digital displays'**
  String get clockSizeHint;

  /// No description provided for @sizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get sizeSmall;

  /// No description provided for @sizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sizeMedium;

  /// No description provided for @sizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get sizeLarge;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @usingDarkTheme.
  ///
  /// In en, this message translates to:
  /// **'Using dark theme'**
  String get usingDarkTheme;

  /// No description provided for @usingLightTheme.
  ///
  /// In en, this message translates to:
  /// **'Using light theme'**
  String get usingLightTheme;

  /// No description provided for @sectionWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get sectionWindow;

  /// No description provided for @alwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'Always on Top'**
  String get alwaysOnTop;

  /// No description provided for @alwaysOnTopHint.
  ///
  /// In en, this message translates to:
  /// **'Keep bClock above all other windows'**
  String get alwaysOnTopHint;

  /// No description provided for @closeToTray.
  ///
  /// In en, this message translates to:
  /// **'Keep running in the tray'**
  String get closeToTray;

  /// No description provided for @closeToTrayHint.
  ///
  /// In en, this message translates to:
  /// **'Closing the window hides bClock in the tray, so alarms and timers keep working'**
  String get closeToTrayHint;

  /// No description provided for @trayShow.
  ///
  /// In en, this message translates to:
  /// **'Show bClock'**
  String get trayShow;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @trayHintTitle.
  ///
  /// In en, this message translates to:
  /// **'bClock is still running'**
  String get trayHintTitle;

  /// No description provided for @trayHintBody.
  ///
  /// In en, this message translates to:
  /// **'Alarms and timers keep working. Right-click the tray icon to quit.'**
  String get trayHintBody;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageHint.
  ///
  /// In en, this message translates to:
  /// **'Language of the interface'**
  String get languageHint;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @a11yCloseDialog.
  ///
  /// In en, this message translates to:
  /// **'Close dialog'**
  String get a11yCloseDialog;

  /// No description provided for @a11yClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get a11yClearSearch;

  /// No description provided for @a11yClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get a11yClearSelection;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAlarmQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this alarm?'**
  String get deleteAlarmQuestion;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Screen-reader label for the stopwatch time
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute} other{{minutes} minutes}}, {seconds, plural, =1{1 second} other{{seconds} seconds}}'**
  String elapsedDuration(int minutes, int seconds);

  /// No description provided for @weekStart.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get weekStart;

  /// No description provided for @weekStartHint.
  ///
  /// In en, this message translates to:
  /// **'First day shown in the alarm day picker'**
  String get weekStartHint;

  /// Screen-reader label for the stopwatch time from one hour on
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour} other{{hours} hours}}, {minutes, plural, =1{1 minute} other{{minutes} minutes}}, {seconds, plural, =1{1 second} other{{seconds} seconds}}'**
  String elapsedDurationWithHours(int hours, int minutes, int seconds);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
