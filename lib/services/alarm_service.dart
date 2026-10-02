import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:plinth_components/plinth_components.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/alarm_model.dart';
import 'alarm_scheduler.dart';

/// Singleton that owns the alarm list: loads and saves it, checks it every
/// 10 seconds and fires due alarms. AlarmScreen reads [alarms] and listens
/// for changes (e.g. a one-shot disabling itself after firing).
class AlarmService extends ChangeNotifier {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const Duration snoozeDuration = Duration(minutes: 5);

  static const String alarmsStorageKey = 'alarms';

  // Created on first ring, so merely touching the service (tests) doesn't
  // need the audio plugin.
  late final AudioPlayer _player = AudioPlayer();
  Timer? _timer;

  /// The alarm list. Mutate in place, then call [setAlarms] to save it.
  List<AlarmModel> alarms = [];

  /// False until a list has been saved — on first run AlarmScreen seeds
  /// the defaults. An empty saved list is a valid state.
  bool get hasSavedAlarms => _hasSaved;
  bool _hasSaved = false;

  /// Reconciles Windows Task Scheduler; replaced in tests so they don't
  /// touch the real scheduled tasks.
  @visibleForTesting
  Future<void> Function(List<AlarmModel>) syncScheduler = AlarmScheduler.sync;

  /// Starts the looping alarm sound; replaced in tests (no audio plugin).
  @visibleForTesting
  late Future<void> Function() playSound = _playSound;

  /// Navigator key injected from main.dart for showing dialogs.
  GlobalKey<NavigatorState>? navigatorKey;

  // Track which alarm already fired in the current minute
  final Set<String> _firedIds = {};
  int _lastMinute = -1;

  // Pending snooze timers, keyed by alarm id
  final Map<String, Timer> _snoozeTimers = {};

  // ── Lifecycle ─────────────────────────────────────────────

  /// Reads the saved list. Awaited before the first frame, so the screen
  /// and both firing paths share one list from the start.
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(alarmsStorageKey);
    _hasSaved = raw != null;
    alarms = raw == null
        ? []
        : (jsonDecode(raw) as List)
            .map((e) => AlarmModel.fromJson(e as Map<String, dynamic>))
            .toList();
    notifyListeners();
  }

  /// Call after the first frame, so a due alarm's popup has a Navigator.
  void start() {
    // Re-register the tasks once per launch, so tasks from an older
    // version pick up current settings without the user editing an alarm.
    unawaited(syncScheduler(alarms));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_check()) _commit();
    });
    if (_check()) _commit();
  }

  /// The single mutation entry point: replaces the list, saves it and
  /// syncs the scheduler.
  void setAlarms(List<AlarmModel> alarms) {
    this.alarms = alarms;
    _hasSaved = true;
    _check();
    _commit();
  }

  /// Saves, notifies and fire-and-forget syncs Windows Task Scheduler so
  /// alarms fire even when the app is closed.
  void _commit() {
    unawaited(_save());
    unawaited(syncScheduler(alarms));
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        alarmsStorageKey, jsonEncode(alarms.map((a) => a.toJson()).toList()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final t in _snoozeTimers.values) {
      t.cancel();
    }
    _snoozeTimers.clear();
    _player.dispose();
    super.dispose();
  }

  // ── Check ─────────────────────────────────────────────────

  /// Fires due alarms. Returns true if a one-shot was disabled, i.e. the
  /// list changed and needs saving.
  bool _check() {
    final now = DateTime.now();
    var changed = false;
    for (final alarm in List<AlarmModel>.from(alarms)) {
      if (!alarm.isEnabled) continue;
      if (alarm.hour != now.hour) continue;
      if (alarm.minute != now.minute) continue;
      if (alarm.repeat && alarm.days.any((d) => d)) {
        if (!alarm.days[now.weekday - 1]) continue;
      }
      if (!_markFired(alarm.id)) continue;

      _fire(alarm);

      // One-shot alarm → disable after firing
      if (!alarm.repeat) {
        alarm.isEnabled = false;
        changed = true;
      }
    }
    return changed;
  }

  /// Records that [id] fired this minute. Returns false if it already had —
  /// the polling loop and a `--fire` launch both fire at the alarm's minute,
  /// and whichever comes second must not ring again.
  bool _markFired(String id) {
    final now = DateTime.now();
    final minute = now.hour * 60 + now.minute;
    // New minute → clear the fired-set so alarms can fire again tomorrow
    if (minute != _lastMinute) {
      _firedIds.clear();
      _lastMinute = minute;
    }
    return _firedIds.add(id);
  }

  // ── Fire ──────────────────────────────────────────────────

  Future<void> _playSound() async {
    // Loops until dismissed
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/alarm.wav'));
  }

  Future<void> _fire(AlarmModel alarm) async {
    await playSound();

    final ctx = navigatorKey?.currentContext;
    if (ctx != null && ctx.mounted) {
      await _showAlarmPopup(
        ctx,
        alarm: alarm,
        onDismiss: _stopSound,
        onSnooze: () => snooze(alarm),
      );
    }
  }

  Future<void> _stopSound() => _player.stop();

  /// Fires the alarm with [id], unless it already fired this minute.
  /// Intended for the `--fire` launch path (Windows Task Scheduler → fresh
  /// process, or forwarded to the running one).
  Future<void> fireById(String id) async {
    final alarm = alarms.where((a) => a.id == id).firstOrNull;
    if (alarm == null || !_markFired(alarm.id)) return;

    if (!alarm.repeat) {
      alarm.isEnabled = false;
      _commit();
    }

    await _fire(alarm);
  }

  /// Stop the current sound and re-fire the alarm after [snoozeDuration].
  /// Any pending snooze for the same alarm is cancelled first.
  Future<void> snooze(AlarmModel alarm) async {
    await _stopSound();
    _snoozeTimers[alarm.id]?.cancel();
    _snoozeTimers[alarm.id] = Timer(snoozeDuration, () {
      _snoozeTimers.remove(alarm.id);
      _fire(alarm);
    });
  }
}

// ── Popup dialog ────────────────────────────────────────────────

/// Shows the alarm popup as a [PlinthModal]. No title (so no close
/// button) and no backdrop dismissal: the user must pick Snooze or Dismiss.
Future<void> _showAlarmPopup(
  BuildContext context, {
  required AlarmModel alarm,
  required VoidCallback onDismiss,
  required VoidCallback onSnooze,
}) async {
  final controller = PlinthDisclosureController(initiallyOpen: true);
  await PlinthModal(
    controller: controller,
    closeOnBackdropTap: false,
    size: PlinthSize.xs,
    child: _AlarmPopup(alarm: alarm, onDismiss: onDismiss, onSnooze: onSnooze),
  ).show(context);
  controller.dispose();
}

class _AlarmPopup extends StatelessWidget {
  final AlarmModel alarm;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;

  const _AlarmPopup({
    required this.alarm,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.plinth;
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bell icon
          const PlinthThemeIcon(
            icon: Icon(Icons.alarm),
            variant: PlinthVariant.light,
            size: PlinthSize.xl,
            circle: true,
          ),

          const SizedBox(height: 16),

          // Time
          Text(
            alarm.timeString,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w200,
              color: theme.text,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1,
            ),
          ),

          const SizedBox(height: 8),

          // Label (if set)
          if (alarm.label.isNotEmpty)
            PlinthText(
              alarm.label,
              size: PlinthSize.lg,
              color: 'gray',
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 24),

          PlinthGroup(
            mainAxisAlignment: MainAxisAlignment.center,
            gap: PlinthSize.sm,
            children: [
              PlinthButton(
                variant: PlinthVariant.light,
                leadingIcon: const Icon(Icons.snooze),
                onPressed: () {
                  onSnooze();
                  Navigator.of(context).pop();
                },
                child: Text(l.snooze(AlarmService.snoozeDuration.inMinutes)),
              ),
              PlinthButton(
                leadingIcon: const Icon(Icons.alarm_off),
                onPressed: () {
                  onDismiss();
                  Navigator.of(context).pop();
                },
                child: Text(l.dismiss),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
