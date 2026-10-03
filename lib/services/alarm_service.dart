import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:plinth_components/plinth_components.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/alarm_model.dart';
import '../models/sound_options.dart';
import 'app_window.dart';
import 'notification_service.dart';
import 'alarm_scheduler.dart';

/// Singleton that owns the alarm list: loads and saves it, checks it every
/// 10 seconds and fires due alarms. AlarmScreen reads [alarms] and listens
/// for changes (e.g. a one-shot disabling itself after firing).
class AlarmService extends ChangeNotifier {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const Duration snoozeDuration = Duration(minutes: 5);

  /// How long one ring lasts when nobody answers it.
  static const Duration ringDuration = Duration(minutes: 1);

  /// An unanswered alarm rings again this many times, [retryInterval]
  /// apart, then gives up with a "Missed alarm" toast. Zero rings once.
  /// Set by AppProvider from the user's settings.
  int retries = defaultRetries;
  Duration retryInterval = defaultRetryInterval;
  static const int defaultRetries = 3;
  static const Duration defaultRetryInterval = Duration(minutes: 5);

  static const String alarmsStorageKey = 'alarms';

  /// The audio output. Its player is created on first use, so merely
  /// touching the service doesn't need the audio plugin; tests replace it
  /// to see what would be played.
  @visibleForTesting
  RingAudio audio = _PlayerAudio();

  /// What to play and how loud; set by AppProvider from the user's settings.
  SoundOptions sound = const SoundOptions();

  Timer? _timer;
  Timer? _fadeTimer;
  Timer? _previewTimer;

  /// The alarm list. Mutate in place, then call [setAlarms] to save it.
  List<AlarmModel> alarms = [];

  /// False until a list has been saved — on first run AlarmScreen seeds
  /// the defaults. An empty saved list is a valid state.
  bool get hasSavedAlarms => _hasSaved;
  bool _hasSaved = false;

  /// Reconciles Windows Task Scheduler and reports whether it worked;
  /// replaced in tests so they don't touch the real scheduled tasks.
  @visibleForTesting
  Future<bool> Function(List<AlarmModel>) syncScheduler = AlarmScheduler.sync;

  /// How long alarm edits must settle before the tasks are re-registered,
  /// so toggling several weekdays is one PowerShell run, not seven. Zero
  /// (in tests) syncs at once.
  @visibleForTesting
  Duration syncDelay = const Duration(seconds: 1);

  /// True when the last sync failed: Windows doesn't hold the alarm tasks,
  /// so alarms only ring while bClock is running. AlarmScreen warns.
  bool get schedulerFailed => _schedulerFailed;
  bool _schedulerFailed = false;

  Timer? _syncTimer;
  bool _syncing = false;
  bool _syncAgain = false;

  /// Start and stop the looping ring; replaced in tests (no audio plugin).
  /// Callers use [startSound] / [stopSound].
  @visibleForTesting
  late Future<void> Function() playSound = _playSound;
  @visibleForTesting
  late Future<void> Function() silenceSound = _silence;

  /// Navigator key injected from main.dart for showing dialogs.
  GlobalKey<NavigatorState>? navigatorKey;

  // Track which alarm already fired in the current minute
  final Set<String> _firedIds = {};
  int _lastMinute = -1;

  // The pending re-ring per alarm id: a snooze, or a retry of an
  // unanswered ring. One at a time, so they never stack.
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
    unawaited(syncNow());
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
    // An alarm that was deleted or switched off must not ring again from a
    // pending snooze or retry.
    final enabled = {
      for (final a in alarms)
        if (a.isEnabled) a.id
    };
    _snoozeTimers.removeWhere((id, timer) {
      if (enabled.contains(id)) return false;
      timer.cancel();
      return true;
    });
    _check();
    _commit();
  }

  /// Saves, notifies, and syncs Windows Task Scheduler (once edits settle)
  /// so alarms fire even when the app is closed.
  void _commit() {
    unawaited(_save());
    _syncTimer?.cancel();
    if (syncDelay == Duration.zero) {
      unawaited(syncNow());
    } else {
      _syncTimer = Timer(syncDelay, syncNow);
    }
    notifyListeners();
  }

  /// Re-registers the alarm tasks now and records whether it worked; also
  /// AlarmScreen's "Try again". Runs never overlap: a call during a run
  /// queues exactly one more, with the list as it is by then.
  Future<void> syncNow() async {
    _syncTimer?.cancel();
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        final ok = await syncScheduler(List.of(alarms));
        if (_schedulerFailed == ok) {
          _schedulerFailed = !ok;
          notifyListeners();
        }
      } while (_syncAgain);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        alarmsStorageKey, jsonEncode(alarms.map((a) => a.toJson()).toList()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _syncTimer?.cancel();
    for (final t in _snoozeTimers.values) {
      t.cancel();
    }
    _snoozeTimers.clear();
    _fadeTimer?.cancel();
    _previewTimer?.cancel();
    audio.dispose();
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

  /// Loops [sound] until dismissed. With fade-in, starts quietly and steps
  /// up to the set volume once a second over [SoundOptions.fadeDuration].
  Future<void> _playSound() async {
    final options = sound;
    _cancelSoundTimers();
    final start = options.fadeIn
        ? options.volume * SoundOptions.fadeStart
        : options.volume;
    await _play(options, loop: true, volume: start);
    if (!options.fadeIn) return;

    final steps = SoundOptions.fadeDuration.inSeconds;
    var step = 0;
    _fadeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      step++;
      unawaited(
          audio.setVolume(start + (options.volume - start) * step / steps));
      if (step >= steps) t.cancel();
    });
  }

  /// Plays [options]' sound: the user's file if it is still there,
  /// otherwise a bundled one (Beeps when a custom file has gone missing,
  /// so a ring is never silent).
  Future<void> _play(SoundOptions options,
      {required bool loop, required double volume}) {
    final path = options.customPath;
    if (options.sound == AlarmSound.custom &&
        path != null &&
        File(path).existsSync()) {
      return audio.play(file: path, loop: loop, volume: volume);
    }
    return audio.play(
      asset: options.sound.asset ?? AlarmSound.beeps.asset,
      loop: loop,
      volume: volume,
    );
  }

  Future<void> _silence() {
    _cancelSoundTimers();
    return audio.stop();
  }

  void _cancelSoundTimers() {
    _fadeTimer?.cancel();
    _previewTimer?.cancel();
  }

  /// Settings' Preview: plays the current sound once at the set volume (no
  /// fade), cut off after [previewLimit] in case it is a long file.
  Future<void> preview() async {
    _cancelSoundTimers();
    await _play(sound, loop: false, volume: sound.volume);
    _previewTimer = Timer(previewLimit, () => unawaited(audio.stop()));
  }

  static const Duration previewLimit = Duration(seconds: 6);

  /// Toast ids: alarms below [_timerToastId], the timer at it.
  static int _alarmToastId(String id) => id.hashCode & 0x3fffffff;

  /// Rings [alarm]. Unanswered for [ringDuration], it stops and, while
  /// [attempt] is below [retries], rings again after [retryInterval].
  Future<void> _fire(AlarmModel alarm, {int attempt = 0}) {
    final l = strings();
    return ring(
      timeout: ringDuration,
      onTimeout: () => _unanswered(alarm, attempt),
      id: _alarmToastId(alarm.id),
      icon: Icons.alarm,
      toastTitle: alarm.label.isEmpty ? l.navAlarm : alarm.label,
      toastBody: alarm.timeString,
      headline: _BigTime(alarm.timeString),
      detail: alarm.label,
      actions: [
        RingAction('snooze', l.snooze(snoozeDuration.inMinutes), Icons.snooze,
            () => snooze(alarm)),
        RingAction('dismiss', l.dismiss, Icons.alarm_off, () {}, primary: true),
      ],
    );
  }

  void _unanswered(AlarmModel alarm, int attempt) {
    if (attempt < retries) {
      _snoozeTimers[alarm.id]?.cancel();
      _snoozeTimers[alarm.id] = Timer(retryInterval, () {
        _snoozeTimers.remove(alarm.id);
        _fire(alarm, attempt: attempt + 1);
      });
      return;
    }
    // Gave up: leave a note of what was missed.
    final l = strings();
    unawaited(NotificationService.instance.show(
      _alarmToastId(alarm.id),
      title: l.missedAlarm,
      body: alarm.label.isEmpty
          ? alarm.timeString
          : '${alarm.timeString}  ${alarm.label}',
      actions: const {},
      onAction: (_) {},
    ));
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
  ///
  /// With [timeout], a ring nobody answers ends the same way after that
  /// long and calls [onTimeout]; without it, it rings until answered.
  Future<void> ring({
    required int id,
    required IconData icon,
    required String toastTitle,
    required String toastBody,
    required Widget headline,
    String detail = '',
    required List<RingAction> actions,
    Duration? timeout,
    VoidCallback? onTimeout,
  }) async {
    final notifications = NotificationService.instance;
    final close = ValueNotifier(false);
    Timer? giveUp;
    var ended = false;

    /// Ends the ring once: sound off, toast withdrawn, popup closed.
    bool end() {
      if (ended) return false;
      ended = true;
      giveUp?.cancel();
      unawaited(stopSound());
      unawaited(notifications.cancel(id));
      close.value = true;
      return true;
    }

    void answer(RingAction action) {
      if (end()) action.onSelected();
    }

    await startSound();
    // Nobody answered within [timeout]: stop, and let the caller decide
    // what happens next.
    if (timeout != null) {
      giveUp = Timer(timeout, () {
        if (end()) onTimeout?.call();
      });
    }
    // Show the full window (it may be hidden in the tray, or in mini mode)
    // so the popup is seen.
    unawaited(AppWindow.showForPopup());
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

// ── Audio ───────────────────────────────────────────────────────

/// What AlarmService needs from an audio player.
abstract class RingAudio {
  /// Plays a bundled [asset] or a [file] on disk (exactly one is given),
  /// replacing whatever was playing.
  Future<void> play({
    String? asset,
    String? file,
    required bool loop,
    required double volume,
  });

  Future<void> setVolume(double volume);
  Future<void> stop();
  void dispose();
}

class _PlayerAudio implements RingAudio {
  late final AudioPlayer _player = AudioPlayer();
  bool _created = false;

  AudioPlayer get _p {
    _created = true;
    return _player;
  }

  @override
  Future<void> play({
    String? asset,
    String? file,
    required bool loop,
    required double volume,
  }) async {
    await _p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await _p.play(
      file != null ? DeviceFileSource(file) : AssetSource(asset!),
      volume: volume,
    );
  }

  @override
  Future<void> setVolume(double volume) => _p.setVolume(volume);

  @override
  Future<void> stop() => _p.stop();

  @override
  void dispose() {
    if (_created) _player.dispose();
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
