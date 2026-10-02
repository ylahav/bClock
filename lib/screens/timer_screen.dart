import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
import '../l10n/app_localizations.dart';
import '../services/timer_service.dart';

/// Countdown timer. The state lives in [TimerService]; this screen only
/// draws it, and ticks while the timer runs.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // Height the ring leaves for the presets and controls below it.
  static const _presetsHeight = 76.0;
  static const _controlsHeight = 72.0;
  static const _gap = 16.0;
  static const _minRing = 96.0;
  static const _maxRing = 220.0;
  // The controls row: two lg icons, one xl icon, two 28px gaps.
  static const _controlsWidth = 208.0;

  final _service = TimerService.instance;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    _syncTicker();
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _onChanged() {
    _syncTicker();
    setState(() {});
  }

  /// Redraw several times a second while running, so the seconds turn over
  /// on time; idle while paused or stopped.
  void _syncTicker() {
    if (_service.isRunning) {
      _ticker ??= Timer.periodic(
          const Duration(milliseconds: 200), (_) => setState(() {}));
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// Whole seconds, rounded up: a countdown shows 00:01 until it ends.
  Duration _ceilSeconds(Duration d) =>
      Duration(seconds: (d.inMilliseconds + 999) ~/ 1000);

  /// `MM:SS`, or `H:MM:SS` from one hour on.
  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  String _spoken(AppLocalizations l, Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return d.inHours > 0
        ? l.elapsedDurationWithHours(d.inHours, m, s)
        : l.elapsedDuration(m, s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.plinth;
    final l = AppLocalizations.of(context);
    final s = _service;
    final left = _ceilSeconds(s.remaining());
    final progress = s.isIdle || s.total == Duration.zero
        ? 1.0
        : (s.remaining().inMilliseconds / s.total.inMilliseconds)
            .clamp(0.0, 1.0);

    return PlinthPage(
      title: l.timerTitle,
      titleOrder: 4,
      background: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      body: LayoutBuilder(builder: (context, c) {
        final below =
            (s.isIdle ? _presetsHeight + _gap : 0) + _controlsHeight + _gap;
        final ring = min(c.maxWidth, c.maxHeight - below)
            .clamp(_minRing, _maxRing)
            .toDouble();

        // The window height is set by the Clock tab; in a window shorter
        // than even the smallest layout, scale down rather than overflow.
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              // Never narrower than the controls; the FittedBox above
              // scales the lot in a window narrower than that.
              width: max(_controlsWidth, max(ring, min(c.maxWidth, 320))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlinthRingProgress(
                    value: progress,
                    diameter: ring,
                    thickness: ring * 0.045,
                    color: theme.primaryColor,
                    semanticLabel: l.timeLeft,
                    label: PlinthClock(
                      _fmt(left),
                      size: ring * (left.inHours > 0 ? 0.17 : 0.22),
                      weight: FontWeight.w200,
                      // Spoken as a duration, not read as a time of day.
                      semanticLabel: _spoken(l, left),
                    ),
                  ),
                  if (s.isIdle) ...[
                    const SizedBox(height: _gap),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in TimerService.presets)
                          PlinthChip(
                            label: l.presetMinutes(p.inMinutes),
                            size: PlinthSize.xs,
                            selected: s.duration == p,
                            onSelected: (_) => s.setDuration(p),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: _gap),
                  _Controls(service: s, l: l),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// −1 min / Reset · Start / Pause / Resume · +1 min.
class _Controls extends StatelessWidget {
  final TimerService service;
  final AppLocalizations l;

  const _Controls({required this.service, required this.l});

  @override
  Widget build(BuildContext context) {
    final theme = context.plinth;
    final s = service;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Idle: shorten the set duration. Otherwise: back to idle.
        s.isIdle
            ? PlinthActionIcon(
                semanticLabel: l.removeMinute,
                icon: const Icon(Icons.remove),
                onPressed: s.duration > TimerService.minDuration
                    ? s.removeMinute
                    : null,
                variant: PlinthVariant.light,
                color: 'gray',
                size: PlinthSize.lg,
                circle: true,
              )
            : PlinthActionIcon(
                semanticLabel: l.reset,
                icon: const Icon(Icons.refresh),
                onPressed: s.reset,
                variant: PlinthVariant.light,
                color: 'gray',
                size: PlinthSize.lg,
                circle: true,
              ),
        const SizedBox(width: 28),
        PlinthActionIcon(
          semanticLabel:
              s.isRunning ? l.pause : (s.isPaused ? l.resume : l.start),
          icon: Icon(s.isRunning ? Icons.pause : Icons.play_arrow),
          onPressed: s.isRunning ? s.pause : s.startOrResume,
          variant: PlinthVariant.light,
          color: s.isRunning ? 'red' : theme.primaryColor,
          size: PlinthSize.xl,
          circle: true,
        ),
        const SizedBox(width: 28),
        PlinthActionIcon(
          semanticLabel: l.addMinute,
          icon: const Icon(Icons.add),
          onPressed:
              s.remaining() < TimerService.maxDuration ? s.addMinute : null,
          variant: PlinthVariant.light,
          color: 'gray',
          size: PlinthSize.lg,
          circle: true,
        ),
      ],
    );
  }
}
