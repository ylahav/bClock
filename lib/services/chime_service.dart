import 'dart:async';
import 'package:flutter/foundation.dart';
import 'alarm_service.dart';

/// The optional hourly chime: a short bell at the top of each hour, between
/// two hours of the day, while bClock is running (the tray counts).
///
/// It has its own audio player, so a chime never cuts off a ringing alarm
/// or timer, and it is not scheduled with Windows: launching bClock every
/// hour just to chime would be absurd.
class ChimeService {
  ChimeService._();
  static final ChimeService instance = ChimeService._();

  static const String asset = 'sounds/hour.wav';
  static const int defaultFromHour = 8;
  static const int defaultUntilHour = 22;

  /// Tests replace these: no audio plugin, and a clock they control.
  @visibleForTesting
  RingAudio audio = RingAudio.player();
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  bool _enabled = false;
  int _fromHour = defaultFromHour;
  int _untilHour = defaultUntilHour;
  Timer? _timer;

  /// Applies the user's settings (from AppProvider) and reschedules.
  void configure({
    required bool enabled,
    required int fromHour,
    required int untilHour,
  }) {
    _enabled = enabled;
    _fromHour = fromHour;
    _untilHour = untilHour;
    _schedule();
  }

  /// Whether [hour] is inside the chiming hours, both ends included. A
  /// range like 22 to 6 wraps past midnight.
  bool chimesAt(int hour) => _fromHour <= _untilHour
      ? hour >= _fromHour && hour <= _untilHour
      : hour >= _fromHour || hour <= _untilHour;

  /// Plays the chime once, at the alarm volume. Also Settings' feedback
  /// when the chime is switched on.
  Future<void> play() => audio.play(
        asset: asset,
        loop: false,
        volume: AlarmService.instance.sound.volume,
      );

  /// One timer to the next top of the hour, rearmed each time it fires.
  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_enabled) return;
    final t = now();
    final nextHour = DateTime(t.year, t.month, t.day, t.hour + 1);
    _timer = Timer(nextHour.difference(t), _onTheHour);
  }

  void _onTheHour() {
    final t = now();
    // A timer that slept through the hour (the PC was asleep) fires late:
    // chime only if this really is the top of an hour.
    if (t.minute == 0 && chimesAt(t.hour)) unawaited(play());
    _schedule();
  }
}
