import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:plinth_components/plinth_components.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/alarm_model.dart';
import 'notification_service.dart';
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

  /// Start and stop the looping ring; replaced in tests (no audio plugin).
  /// Callers use [startSound] / [stopSound].
  @visibleForTesting
  late Future<void> Function() playSound = _playSound;
  @visibleForTesting
  late Future<void> Function() silenceSound = () => _player.stop();

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

  /// Toast ids: alarms below [_timerToastId], the timer at it.
  static int _alarmToastId(String id) => id.hashCode & 0x3fffffff;

  Future<void> _fire(AlarmModel alarm) {
    final l = strings();
    return ring(
      id: _alarmToastId(alarm.id),
      icon: Icons.alarm,
      toastTitle: alarm.label.isEmpty ? l.navAlarm : alarm.label,
      toastBody: alarm.timeString,
      headline: _BigTime(alarm.timeString),
      detail: alarm.label,
      actions: [
        RingAction('snooze', l.snooze(snoozeDuration.inMinutes), Icons.snooze,
            () => snooze(alarm)),
        RingAction('dismiss', l.dismiss, Icons.alarm_off, () {},
            primary: true),
      ],
    );
  }

  /// The UI language's strings, for text shown outside a widget (toasts).
  AppLocalizations strings() {
    final ctx = navigatorKey?.currentContext;
    return ctx != null && ctx.mounted
        ? AppLocalizations.of(ctx)
        : lookupAppLocalizations(const Locale('en'));
  }

  /// Rings: plays the looping sound, and offers [actions] both as an
  /// in-app popup and as a Windows toast (which shows even when bClock is
  /// behind other windows). Whichever the user answers first ends the
  /// ring: the sound stops, the toast is withdrawn, the popup closes, and
  /// then that action runs. Shared by alarms and the countdown timer.
  Future<void> ring({
    required int id,
    required IconData icon,
    required String toastTitle,
    required String toastBody,
    required Widget headline,
    String detail = '',
    required List<RingAction> actions,
  }) async {
    final notifications = NotificationService.instance;
    final close = ValueNotifier(false);
    var answered = false;
    void answer(RingAction action) {
      if (answered) return;
      answered = true;
      unawaited(stopSound());
      unawaited(notifications.cancel(id));
      close.value = true;
      action.onSelected();
    }

    await startSound();
    final byKey = {for (final a in actions) a.key: a};
    unawaited(notifications.show(
      id,
      title: toastTitle,
      body: toastBody,
      actions: {for (final a in actions) a.key: a.label},
      onAction: (key) {
        final action = byKey[key];
        if (action != null) answer(action);
      },
    ));

    final ctx = navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final controller = PlinthDisclosureController(initiallyOpen: true);
    // No title (so no close button) and no backdrop dismissal: the user
    // must pick one of the actions, here or on the toast.
    await PlinthModal(
      controller: controller,
      closeOnBackdropTap: false,
      size: PlinthSize.xs,
      child: _RingPopup(
        icon: icon,
        headline: headline,
        detail: detail,
        actions: actions,
        onAnswer: answer,
        close: close,
      ),
    ).show(ctx);
    controller.dispose();
    close.dispose();
  }

  /// Start / stop the looping ring. One player, shared with the countdown
  /// timer, so its sound and an alarm's never play over each other.
  Future<void> startSound() => playSound();
  Future<void> stopSound() => silenceSound();

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
    await stopSound();
    _snoozeTimers[alarm.id]?.cancel();
    _snoozeTimers[alarm.id] = Timer(snoozeDuration, () {
      _snoozeTimers.remove(alarm.id);
      _fire(alarm);
    });
  }
}

// ── Popup dialog ────────────────────────────────────────────────

/// A button of a ring, shown in the popup and on the toast.
class RingAction {
  /// [key] identifies the button on the toast; [primary] draws it filled.
  const RingAction(this.key, this.label, this.icon, this.onSelected,
      {this.primary = false});

  final String key;
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool primary;
}

/// The alarm's time, large.
class _BigTime extends StatelessWidget {
  final String time;
  const _BigTime(this.time);

  @override
  Widget build(BuildContext context) => Text(
        time,
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w200,
          color: context.plinth.text,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1,
        ),
      );
}

class _RingPopup extends StatefulWidget {
  final IconData icon;
  final Widget headline;
  final String detail;
  final List<RingAction> actions;
  final ValueChanged<RingAction> onAnswer;

  /// Set when the ring was answered, here or on the toast.
  final ValueNotifier<bool> close;

  const _RingPopup({
    required this.icon,
    required this.headline,
    required this.detail,
    required this.actions,
    required this.onAnswer,
    required this.close,
  });

  @override
  State<_RingPopup> createState() => _RingPopupState();
}

class _RingPopupState extends State<_RingPopup> {
  @override
  void initState() {
    super.initState();
    widget.close.addListener(_onClose);
  }

  @override
  void dispose() {
    widget.close.removeListener(_onClose);
    super.dispose();
  }

  /// Closes this popup's own route, even if another sits above it.
  void _onClose() {
    if (!widget.close.value || !mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlinthThemeIcon(
            icon: Icon(widget.icon),
            variant: PlinthVariant.light,
            size: PlinthSize.xl,
            circle: true,
          ),
          const SizedBox(height: 16),
          widget.headline,
          if (widget.detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            PlinthText(
              widget.detail,
              size: PlinthSize.lg,
              color: 'gray',
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          PlinthGroup(
            mainAxisAlignment: MainAxisAlignment.center,
            gap: PlinthSize.sm,
            children: [
              for (final a in widget.actions)
                PlinthButton(
                  variant:
                      a.primary ? PlinthVariant.filled : PlinthVariant.light,
                  leadingIcon: Icon(a.icon),
                  onPressed: () => widget.onAnswer(a),
                  child: Text(a.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
