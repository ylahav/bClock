// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navClock => 'Horloge';

  @override
  String get navStopwatch => 'Chrono';

  @override
  String get navTimer => 'Minuteur';

  @override
  String get navWorld => 'Monde';

  @override
  String get navAlarm => 'Alarme';

  @override
  String get viewDigital => 'Numérique';

  @override
  String get viewBoth => 'Les deux';

  @override
  String get viewAnalog => 'Analogique';

  @override
  String get toggleTheme => 'Changer de thème';

  @override
  String get settings => 'Paramètres';

  @override
  String get hideControls => 'Masquer les commandes';

  @override
  String get stopwatchTitle => 'Chronomètre';

  @override
  String get lap => 'Tour';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get pause => 'Pause';

  @override
  String get start => 'Démarrer';

  @override
  String get timerTitle => 'Minuteur';

  @override
  String get resume => 'Reprendre';

  @override
  String get timesUp => 'Temps écoulé';

  @override
  String get plusOneMinute => '+1 min';

  @override
  String get addMinute => 'Ajouter 1 minute';

  @override
  String get removeMinute => 'Retirer 1 minute';

  @override
  String presetMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get timeLeft => 'Temps restant';

  @override
  String get customDuration => 'Personnalisé…';

  @override
  String get setTimerTitle => 'Régler le minuteur';

  @override
  String get hours => 'Heures';

  @override
  String get minutes => 'Minutes';

  @override
  String get seconds => 'Secondes';

  @override
  String get lapTime => 'Temps';

  @override
  String lapNumber(int n) {
    return 'Tour $n';
  }

  @override
  String get worldTitle => 'Monde';

  @override
  String get addCity => 'Ajouter une ville';

  @override
  String get addCityTitle => 'Ajouter une ville';

  @override
  String get noCities => 'Aucune ville ajoutée';

  @override
  String get addACity => 'Ajouter une ville';

  @override
  String removeCity(String city) {
    return 'Retirer $city';
  }

  @override
  String get moveCityEarlier => 'Déplacer avant';

  @override
  String get moveCityLater => 'Déplacer après';

  @override
  String get planMeeting => 'Planifier une réunion';

  @override
  String get planNow => 'Maintenant';

  @override
  String planSummary(int count, int total) {
    return '$count sur $total en heures de bureau';
  }

  @override
  String get workingHours => 'Heures de bureau';

  @override
  String get meetingTime => 'Heure de la réunion';

  @override
  String get searchCities => 'Rechercher des villes…';

  @override
  String get alarmsTitle => 'Alarmes';

  @override
  String get addAlarm => 'Ajouter une alarme';

  @override
  String get noAlarms => 'Aucune alarme';

  @override
  String get addAnAlarm => 'Ajouter une alarme';

  @override
  String get labelTitle => 'Libellé';

  @override
  String get labelPlaceholder => 'ex. Réveil, Réunion…';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get addLabel => 'Ajouter un libellé…';

  @override
  String get repeat => 'Répéter';

  @override
  String get alarmDisabled => 'Désactivée';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get tomorrow => 'Demain';

  @override
  String get defaultAlarmWakeUp => 'Réveil';

  @override
  String get defaultAlarmMorning => 'Routine du matin';

  @override
  String snooze(int minutes) {
    return 'Rappel $minutes min';
  }

  @override
  String get dismiss => 'Arrêter';

  @override
  String get sectionClockDisplay => 'Affichage de l\'horloge';

  @override
  String get defaultView => 'Vue par défaut';

  @override
  String get defaultViewHint => 'Ce qui s\'affiche sur l\'écran de l\'horloge';

  @override
  String get digitalPosition => 'Position du numérique';

  @override
  String get digitalPositionHint =>
      'Où placer l\'horloge numérique quand les deux sont affichées';

  @override
  String get aboveAnalog => 'Au-dessus';

  @override
  String get belowAnalog => 'En dessous';

  @override
  String get clockSize => 'Taille de l\'horloge';

  @override
  String get clockSizeHint => 'Ajuste l\'affichage analogique et numérique';

  @override
  String get sizeSmall => 'Petite';

  @override
  String get sizeMedium => 'Moyenne';

  @override
  String get sizeLarge => 'Grande';

  @override
  String get sectionAppearance => 'Apparence';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get usingDarkTheme => 'Thème sombre activé';

  @override
  String get usingLightTheme => 'Thème clair activé';

  @override
  String get sectionWindow => 'Fenêtre';

  @override
  String get alwaysOnTop => 'Toujours au premier plan';

  @override
  String get alwaysOnTopHint => 'Garder bClock au-dessus des autres fenêtres';

  @override
  String get closeToTray => 'Rester dans la zone de notification';

  @override
  String get closeToTrayHint =>
      'Fermer la fenêtre masque bClock dans la zone de notification ; alarmes et minuteurs continuent';

  @override
  String get trayShow => 'Afficher bClock';

  @override
  String get trayQuit => 'Quitter';

  @override
  String get trayHintTitle => 'bClock fonctionne toujours';

  @override
  String get trayHintBody =>
      'Les alarmes et minuteurs continuent. Clic droit sur l\'icône de la zone de notification pour quitter.';

  @override
  String get sectionLanguage => 'Langue';

  @override
  String get language => 'Langue';

  @override
  String get languageHint => 'Langue de l\'interface';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get a11yCloseDialog => 'Fermer la boîte de dialogue';

  @override
  String get a11yClearSearch => 'Effacer la recherche';

  @override
  String get a11yClearSelection => 'Effacer la sélection';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteAlarmQuestion => 'Supprimer cette alarme ?';

  @override
  String get back => 'Retour';

  @override
  String elapsedDuration(int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
      zero: '0 minute',
    );
    String _temp1 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds secondes',
      one: '1 seconde',
      zero: '0 seconde',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get weekStart => 'La semaine commence le';

  @override
  String get weekStartHint => 'Premier jour du sélecteur de jours des alarmes';

  @override
  String elapsedDurationWithHours(int hours, int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours heures',
      one: '1 heure',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
      zero: '0 minute',
    );
    String _temp2 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds secondes',
      one: '1 seconde',
      zero: '0 seconde',
    );
    return '$_temp0, $_temp1, $_temp2';
  }
}
