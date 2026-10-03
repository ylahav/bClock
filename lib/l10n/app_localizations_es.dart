// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navClock => 'Reloj';

  @override
  String get navStopwatch => 'Cronómetro';

  @override
  String get navTimer => 'Temporizador';

  @override
  String get navWorld => 'Mundo';

  @override
  String get navAlarm => 'Alarma';

  @override
  String get viewDigital => 'Digital';

  @override
  String get viewBoth => 'Ambos';

  @override
  String get viewAnalog => 'Analógico';

  @override
  String get toggleTheme => 'Cambiar tema';

  @override
  String get settings => 'Ajustes';

  @override
  String get hideControls => 'Ocultar controles';

  @override
  String get stopwatchTitle => 'Cronómetro';

  @override
  String get lap => 'Vuelta';

  @override
  String get reset => 'Reiniciar';

  @override
  String get pause => 'Pausa';

  @override
  String get start => 'Iniciar';

  @override
  String get timerTitle => 'Temporizador';

  @override
  String get resume => 'Reanudar';

  @override
  String get timesUp => 'Se acabó el tiempo';

  @override
  String get plusOneMinute => '+1 min';

  @override
  String get addMinute => 'Añadir 1 minuto';

  @override
  String get removeMinute => 'Quitar 1 minuto';

  @override
  String presetMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get timeLeft => 'Tiempo restante';

  @override
  String get customDuration => 'Personalizado…';

  @override
  String get setTimerTitle => 'Ajustar temporizador';

  @override
  String get hours => 'Horas';

  @override
  String get minutes => 'Minutos';

  @override
  String get seconds => 'Segundos';

  @override
  String get lapTime => 'Tiempo';

  @override
  String lapNumber(int n) {
    return 'Vuelta $n';
  }

  @override
  String get worldTitle => 'Mundo';

  @override
  String get addCity => 'Añadir ciudad';

  @override
  String get addCityTitle => 'Añadir ciudad';

  @override
  String get noCities => 'No hay ciudades';

  @override
  String get addACity => 'Añadir una ciudad';

  @override
  String removeCity(String city) {
    return 'Quitar $city';
  }

  @override
  String get moveCityEarlier => 'Mover antes';

  @override
  String get moveCityLater => 'Mover después';

  @override
  String get planMeeting => 'Planificar una reunión';

  @override
  String get planNow => 'Ahora';

  @override
  String planSummary(int count, int total) {
    return '$count de $total en horario laboral';
  }

  @override
  String get workingHours => 'Horario laboral';

  @override
  String get meetingTime => 'Hora de la reunión';

  @override
  String get searchCities => 'Buscar ciudades…';

  @override
  String get alarmsTitle => 'Alarmas';

  @override
  String get addAlarm => 'Añadir alarma';

  @override
  String get noAlarms => 'No hay alarmas';

  @override
  String get addAnAlarm => 'Añadir una alarma';

  @override
  String get labelTitle => 'Etiqueta';

  @override
  String get labelPlaceholder => 'p. ej. Despertar, Reunión…';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get addLabel => 'Añadir etiqueta…';

  @override
  String get repeat => 'Repetir';

  @override
  String get alarmDisabled => 'Desactivada';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get defaultAlarmWakeUp => 'Despertar';

  @override
  String get defaultAlarmMorning => 'Rutina matutina';

  @override
  String snooze(int minutes) {
    return 'Posponer $minutes min';
  }

  @override
  String get dismiss => 'Descartar';

  @override
  String get sectionClockDisplay => 'Visualización del reloj';

  @override
  String get defaultView => 'Vista predeterminada';

  @override
  String get defaultViewHint => 'Qué mostrar en la pantalla del reloj';

  @override
  String get digitalPosition => 'Posición digital';

  @override
  String get digitalPositionHint =>
      'Dónde colocar el reloj digital al mostrar ambos';

  @override
  String get aboveAnalog => 'Arriba';

  @override
  String get belowAnalog => 'Abajo';

  @override
  String get clockSize => 'Tamaño del reloj';

  @override
  String get clockSizeHint => 'Escala las pantallas analógica y digital';

  @override
  String get sizeSmall => 'Pequeño';

  @override
  String get sizeMedium => 'Mediano';

  @override
  String get sizeLarge => 'Grande';

  @override
  String get sectionAppearance => 'Apariencia';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get usingDarkTheme => 'Usando tema oscuro';

  @override
  String get usingLightTheme => 'Usando tema claro';

  @override
  String get sectionWindow => 'Ventana';

  @override
  String get alwaysOnTop => 'Siempre visible';

  @override
  String get alwaysOnTopHint => 'Mantener bClock sobre las demás ventanas';

  @override
  String get closeToTray => 'Seguir en la bandeja';

  @override
  String get closeToTrayHint =>
      'Al cerrar la ventana, bClock se oculta en la bandeja y las alarmas y temporizadores siguen funcionando';

  @override
  String get trayShow => 'Mostrar bClock';

  @override
  String get trayQuit => 'Salir';

  @override
  String get trayHintTitle => 'bClock sigue en marcha';

  @override
  String get trayHintBody =>
      'Las alarmas y los temporizadores siguen funcionando. Haz clic derecho en el icono de la bandeja para salir.';

  @override
  String get sectionLanguage => 'Idioma';

  @override
  String get language => 'Idioma';

  @override
  String get languageHint => 'Idioma de la interfaz';

  @override
  String get languageSystem => 'Idioma del sistema';

  @override
  String get a11yCloseDialog => 'Cerrar diálogo';

  @override
  String get a11yClearSearch => 'Borrar búsqueda';

  @override
  String get a11yClearSelection => 'Borrar selección';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleteAlarmQuestion => '¿Eliminar esta alarma?';

  @override
  String get back => 'Atrás';

  @override
  String elapsedDuration(int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos',
      one: '1 minuto',
    );
    String _temp1 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds segundos',
      one: '1 segundo',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get weekStart => 'La semana empieza el';

  @override
  String get weekStartHint =>
      'Primer día en el selector de días de las alarmas';

  @override
  String elapsedDurationWithHours(int hours, int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas',
      one: '1 hora',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos',
      one: '1 minuto',
    );
    String _temp2 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds segundos',
      one: '1 segundo',
    );
    return '$_temp0, $_temp1, $_temp2';
  }
}
