import 'dart:async';
import 'package:flutter/material.dart';
import 'package:plinth_components/plinth_components.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import 'alarm_scheduler.dart';
import 'alarm_service.dart';

/// Singleton that owns the countdown timer: what it is set to, whether it
/// runs, and ringing when it ends. TimerScreen reads it and listens.
///
/// Like the stopwatch, a running timer stores its **end time**, not ticks,
/// so it survives the app closing. While it runs, a Windows scheduled task
/// (`AlarmScheduler.timerTaskName`) also launches `bclock.exe --timer-done`
/// at the end time, so it rings even if bClock was closed.
class TimerService extends ChangeNotifier {
  TimerService._();
  static final TimerService instance = TimerService._();

  static const String _kDuration = 'timer.durationMs';
  static const String _kTotal = 'timer.totalMs';
  static const String _kEndAt = 'timer.endAtMs';
  static const String _kPausedLeft = 'timer.pausedLeftMs';

  static const Duration defaultDuration = Duration(minutes: 5);

  /// Custom values may be any whole number of seconds (e.g. 1:30).
  static const Duration minDuration = Duration(seconds: 1);
  static const Duration maxDuration = Duration(hours: 99);
  static const List<Duration> presets = [
    Duration(minutes: 1),
    Duration(minutes: 3),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 25),
    Duration(minutes: 45),
  ];

  /// A launch this long after the end time (bClock was closed and its task
  /// didn't run) shows the timer as finished without ringing.
  static const Duration _ringGrace = Duration(minutes: 1);

  /// What the timer is set to; what Start counts down from.
  Duration get duration => _duration;
  Duration _duration = defaultDuration;

  /// The length of the current run, for the progress ring. Grows with +1 min.
  Duration get total => _total;
  Duration _total = defaultDuration;

  DateTime? _endAt; // running
  Duration? _pausedLeft; // paused
  Timer? _doneTimer;

  bool get isRunning => _endAt != null;
  bool get isPaused => _pausedLeft != null;
  bool get isIdle => !isRunning && !isPaused;

  /// Time left: counts down while running, frozen while paused, and the set
  /// duration while idle.
  Duration remaining([DateTime? now]) {
    if (_endAt != null) {
      final left = _endAt!.difference(now ?? DateTime.now());
      return left.isNegative ? Duration.zero : left;
    }
    return _pausedLeft ?? _duration;
  }

  /// Navigator key injected from main.dart for the "Time's up" popup.
  GlobalKey<NavigatorState>? navigatorKey;

  /// Registers / removes the end-time task; replaced in tests so they don't
  /// touch real scheduled tasks.
  @visibleForTesting
  Future<void> Function(DateTime?) syncScheduler = AlarmScheduler.syncTimer;

  // ── Lifecycle ─────────────────────────────────────────────

  /// Reads the saved state. Awaited before the first frame.
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    Duration? ms(String key) {
      final v = p.getInt(key);
      return v == null ? null : Duration(milliseconds: v);
    }

    _duration = ms(_kDuration) ?? defaultDuration;
    _total = ms(_kTotal) ?? _duration;
    final endMs = p.getInt(_kEndAt);
    _endAt = endMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endMs);
    _pausedLeft = ms(_kPausedLeft);
    notifyListeners();
  }

  /// Call after the first frame, so a ring's popup has a Navigator.
  void start() {
    final end = _endAt;
    if (end == null) return;
    final overdue = DateTime.now().difference(end);
    if (overdue.isNegative) {
      _arm();
    } else {
      _finish(ring: overdue < _ringGrace);
    }
  }

  /// The `--timer-done` launch path (the scheduled task, in a fresh process
  /// or forwarded to the running one). A no-op if the in-app timer already
  /// rang, or the timer was paused or reset since.
  void fireIfDue() {
    final end = _endAt;
    if (end == null) return;
    // The task fires on the second; allow for launch time.
    if (end.difference(DateTime.now()) <= const Duration(seconds: 2)) {
      _finish(ring: true);
    }
  }

  // ── Actions ───────────────────────────────────────────────

  /// Sets the duration. Only while idle — a running timer keeps its end.
  void setDuration(Duration d) {
    if (!isIdle) return;
    _duration = _clamp(d);
    _total = _duration;
    _commit();
  }

  /// Starts from the set duration, or resumes a paused timer.
  void startOrResume() {
    if (isRunning) return;
    final left = _pausedLeft;
    if (left == null) _total = _duration;
    _pausedLeft = null;
    _runFor(left ?? _duration);
  }

  void pause() {
    if (!isRunning) return;
    _pausedLeft = remaining();
    _endAt = null;
    _doneTimer?.cancel();
    _commit();
  }

  /// Back to idle, at the set duration.
  void reset() {
    _endAt = null;
    _pausedLeft = null;
    _total = _duration;
    _doneTimer?.cancel();
    _commit();
  }

  /// Adds a minute: to the time left while running or paused, or to the
  /// set duration while idle.
  void addMinute() => _adjust(const Duration(minutes: 1));

  /// Takes a minute off the set duration. Idle only, and only while more
  /// than a minute is set, so it never lands on zero.
  bool get canRemoveMinute => isIdle && _duration > const Duration(minutes: 1);

  void removeMinute() {
    if (canRemoveMinute) _adjust(const Duration(minutes: -1));
  }

  void _adjust(Duration delta) {
    if (isIdle) {
      setDuration(_duration + delta);
      return;
    }
    _total = _clamp(_total + delta);
    if (isPaused) {
      _pausedLeft = _clamp(_pausedLeft! + delta);
      _commit();
    } else {
      _runFor(remaining() + delta);
    }
  }

  Duration _clamp(Duration d) =>
      d < minDuration ? minDuration : (d > maxDuration ? maxDuration : d);

  void _runFor(Duration left) {
    _endAt = DateTime.now().add(left);
    _arm();
    _commit();
  }

  void _arm() {
    _doneTimer?.cancel();
    final left = _endAt!.difference(DateTime.now());
    _doneTimer = Timer(
        left.isNegative ? Duration.zero : left, () => _finish(ring: true));
  }

  void _finish({required bool ring}) {
    _endAt = null;
    _pausedLeft = null;
    _total = _duration;
    _doneTimer?.cancel();
    _commit();
    if (ring) unawaited(_ring());
  }

  /// Saves, notifies, and fire-and-forget points the scheduled task at the
  /// current end time (or removes it).
  void _commit() {
    unawaited(_save());
    unawaited(syncScheduler(_endAt));
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setInt(_kDuration, _duration.inMilliseconds),
      p.setInt(_kTotal, _total.inMilliseconds),
      if (_endAt == null)
        p.remove(_kEndAt)
      else
        p.setInt(_kEndAt, _endAt!.millisecondsSinceEpoch),
      if (_pausedLeft == null)
        p.remove(_kPausedLeft)
      else
        p.setInt(_kPausedLeft, _pausedLeft!.inMilliseconds),
    ]);
  }

  // ── Ring ──────────────────────────────────────────────────

  Future<void> _ring() async {
    final sound = AlarmService.instance;
    await sound.startSound();
    final ctx = navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final controller = PlinthDisclosureController(initiallyOpen: true);
    await PlinthModal(
      controller: controller,
      closeOnBackdropTap: false,
      size: PlinthSize.xs,
      child: _TimesUpPopup(
        onDismiss: sound.stopSound,
        onAddMinute: () {
          sound.stopSound();
          _total = const Duration(minutes: 1);
          _runFor(const Duration(minutes: 1));
        },
      ),
    ).show(ctx);
    controller.dispose();
  }
}

// ── Popup ───────────────────────────────────────────────────────

/// No title (so no close button) and no backdrop dismissal, like the alarm
/// popup: the user must pick +1 min or Dismiss.
class _TimesUpPopup extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onAddMinute;

  const _TimesUpPopup({required this.onDismiss, required this.onAddMinute});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PlinthThemeIcon(
            icon: Icon(Icons.hourglass_bottom),
            variant: PlinthVariant.light,
            size: PlinthSize.xl,
            circle: true,
          ),
          const SizedBox(height: 16),
          PlinthText(
            l.timesUp,
            size: PlinthSize.xl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PlinthGroup(
            mainAxisAlignment: MainAxisAlignment.center,
            gap: PlinthSize.sm,
            children: [
              PlinthButton(
                variant: PlinthVariant.light,
                leadingIcon: const Icon(Icons.add),
                onPressed: () {
                  onAddMinute();
                  Navigator.of(context).pop();
                },
                child: Text(l.plusOneMinute),
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
