// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get navClock => 'שעון';

  @override
  String get navStopwatch => 'סטופר';

  @override
  String get navWorld => 'עולם';

  @override
  String get navAlarm => 'מעורר';

  @override
  String get viewDigital => 'דיגיטלי';

  @override
  String get viewBoth => 'שניהם';

  @override
  String get viewAnalog => 'אנלוגי';

  @override
  String get toggleTheme => 'החלפת ערכת נושא';

  @override
  String get settings => 'הגדרות';

  @override
  String get hideControls => 'הסתרת פקדים';

  @override
  String get stopwatchTitle => 'סטופר';

  @override
  String get lap => 'הקפה';

  @override
  String get reset => 'איפוס';

  @override
  String get pause => 'השהיה';

  @override
  String get start => 'התחלה';

  @override
  String get lapTime => 'זמן';

  @override
  String lapNumber(int n) {
    return 'הקפה $n';
  }

  @override
  String get worldTitle => 'שעון עולמי';

  @override
  String get addCity => 'הוספת עיר';

  @override
  String get addCityTitle => 'הוספת עיר';

  @override
  String get noCities => 'לא נוספו ערים';

  @override
  String get addACity => 'הוספת עיר';

  @override
  String removeCity(String city) {
    return 'הסרת $city';
  }

  @override
  String get moveCityEarlier => 'הזזה למקום הקודם';

  @override
  String get moveCityLater => 'הזזה למקום הבא';

  @override
  String get searchCities => 'חיפוש ערים…';

  @override
  String get alarmsTitle => 'שעון מעורר';

  @override
  String get addAlarm => 'הוספת התראה';

  @override
  String get noAlarms => 'אין התראות';

  @override
  String get addAnAlarm => 'הוספת התראה';

  @override
  String get labelTitle => 'תווית';

  @override
  String get labelPlaceholder => 'לדוגמה: השכמה, פגישה…';

  @override
  String get cancel => 'ביטול';

  @override
  String get save => 'שמירה';

  @override
  String get addLabel => 'הוספת תווית…';

  @override
  String get repeat => 'חזרה';

  @override
  String get alarmDisabled => 'מושבת';

  @override
  String get today => 'היום';

  @override
  String get tomorrow => 'מחר';

  @override
  String get defaultAlarmWakeUp => 'השכמה';

  @override
  String get defaultAlarmMorning => 'שגרת בוקר';

  @override
  String snooze(int minutes) {
    return 'נודניק $minutes דק׳';
  }

  @override
  String get dismiss => 'כיבוי';

  @override
  String get sectionClockDisplay => 'תצוגת השעון';

  @override
  String get defaultView => 'תצוגת ברירת מחדל';

  @override
  String get defaultViewHint => 'מה להציג במסך השעון';

  @override
  String get digitalPosition => 'מיקום השעון הדיגיטלי';

  @override
  String get digitalPositionHint =>
      'היכן למקם את השעון הדיגיטלי כשמוצגים שניהם';

  @override
  String get aboveAnalog => 'מעל';

  @override
  String get belowAnalog => 'מתחת';

  @override
  String get clockSize => 'גודל השעון';

  @override
  String get clockSizeHint => 'משנה את גודל התצוגה האנלוגית והדיגיטלית';

  @override
  String get sizeSmall => 'קטן';

  @override
  String get sizeMedium => 'בינוני';

  @override
  String get sizeLarge => 'גדול';

  @override
  String get sectionAppearance => 'מראה';

  @override
  String get darkMode => 'מצב כהה';

  @override
  String get usingDarkTheme => 'ערכת נושא כהה פעילה';

  @override
  String get usingLightTheme => 'ערכת נושא בהירה פעילה';

  @override
  String get sectionWindow => 'חלון';

  @override
  String get alwaysOnTop => 'תמיד למעלה';

  @override
  String get alwaysOnTopHint => 'השארת bClock מעל כל החלונות האחרים';

  @override
  String get sectionLanguage => 'שפה';

  @override
  String get language => 'שפה';

  @override
  String get languageHint => 'שפת הממשק';

  @override
  String get languageSystem => 'ברירת המחדל של המערכת';

  @override
  String get a11yCloseDialog => 'סגירת תיבת הדו־שיח';

  @override
  String get a11yClearSearch => 'ניקוי החיפוש';

  @override
  String get a11yClearSelection => 'ניקוי הבחירה';

  @override
  String get delete => 'מחיקה';

  @override
  String get deleteAlarmQuestion => 'למחוק את ההתראה?';

  @override
  String get back => 'חזרה';

  @override
  String elapsedDuration(int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes דקות',
      two: 'שתי דקות',
      one: 'דקה אחת',
    );
    String _temp1 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds שניות',
      two: 'שתי שניות',
      one: 'שנייה אחת',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get weekStart => 'השבוע מתחיל ביום';

  @override
  String get weekStartHint => 'היום הראשון בבורר הימים של ההתראות';

  @override
  String elapsedDurationWithHours(int hours, int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours שעות',
      two: 'שעתיים',
      one: 'שעה אחת',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes דקות',
      two: 'שתי דקות',
      one: 'דקה אחת',
    );
    String _temp2 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds שניות',
      two: 'שתי שניות',
      one: 'שנייה אחת',
    );
    return '$_temp0, $_temp1, $_temp2';
  }
}
