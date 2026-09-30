import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  static const String _kBaseMs = 'sw.baseMs';
  static const String _kRunStartMs = 'sw.runStartMs';
  static const String _kLaps = 'sw.laps';

  Duration _baseElapsed = Duration.zero;
  DateTime? _runStartAt;
  Timer? _timer;
  final List<Duration> _laps = [];

  bool get _isRunning => _runStartAt != null;

  Duration get _elapsed => _runStartAt == null
      ? _baseElapsed
      : _baseElapsed + DateTime.now().difference(_runStartAt!);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final base = p.getInt(_kBaseMs) ?? 0;
    final startMs = p.getInt(_kRunStartMs);
    final lapsRaw = p.getString(_kLaps);

    if (!mounted) return;
    setState(() {
      _baseElapsed = Duration(milliseconds: base);
      _runStartAt =
          startMs == null ? null : DateTime.fromMillisecondsSinceEpoch(startMs);
      _laps
        ..clear()
        ..addAll((jsonDecode(lapsRaw ?? '[]') as List)
            .map((e) => Duration(milliseconds: e as int)));
    });
    if (_isRunning) _startTicker();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setInt(_kBaseMs, _baseElapsed.inMilliseconds),
      if (_runStartAt == null)
        p.remove(_kRunStartMs)
      else
        p.setInt(_kRunStartMs, _runStartAt!.millisecondsSinceEpoch),
      p.setString(
          _kLaps, jsonEncode(_laps.map((d) => d.inMilliseconds).toList())),
    ]);
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      setState(() {});
    });
  }

  // ── Actions ───────────────────────────────────────────────

  void _startStop() {
    if (_isRunning) {
      _baseElapsed = _elapsed;
      _runStartAt = null;
      _timer?.cancel();
    } else {
      _runStartAt = DateTime.now();
      _startTicker();
    }
    setState(() {});
    _save();
  }

  void _reset() {
    _baseElapsed = Duration.zero;
    _runStartAt = null;
    _timer?.cancel();
    setState(() => _laps.clear());
    _save();
  }

  void _lap() {
    if (_isRunning) {
      setState(() => _laps.insert(0, _elapsed));
      _save();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs =
        (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.plinth;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final l = AppLocalizations.of(context);
    final isRunning = _isRunning;
    final elapsed = _elapsed;

    return PlinthPage(
      title: l.stopwatchTitle,
      titleOrder: 4,
      background: bg,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      body: Column(
        children: [
          const SizedBox(height: 40),

          // Main timer display
          Center(
            child: PlinthClock(
              _fmt(elapsed),
              size: 64,
              weight: FontWeight.w200,
              letterSpacing: -1,
              // Spoken as a duration, not read as a time of day.
              semanticLabel: l.elapsedDuration(
                  elapsed.inMinutes, elapsed.inSeconds.remainder(60)),
            ),
          ),

          const SizedBox(height: 52),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lap / Reset
              PlinthActionIcon(
                semanticLabel: isRunning ? l.lap : l.reset,
                icon: Icon(isRunning ? Icons.flag_outlined : Icons.refresh),
                onPressed: isRunning
                    ? _lap
                    : (elapsed > Duration.zero ? _reset : null),
                variant: PlinthVariant.light,
                color: 'gray',
                size: PlinthSize.lg,
                circle: true,
              ),
              const SizedBox(width: 36),
              // Start / Pause
              PlinthActionIcon(
                semanticLabel: isRunning ? l.pause : l.start,
                icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                onPressed: _startStop,
                variant: PlinthVariant.light,
                color: isRunning ? 'red' : theme.primaryColor,
                size: PlinthSize.xl,
                circle: true,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Lap list
          if (_laps.isNotEmpty) ...[
            const PlinthDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PlinthText(l.lap, size: PlinthSize.xs, color: 'gray'),
                  PlinthText(l.lapTime, size: PlinthSize.xs, color: 'gray'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _laps.length,
                itemBuilder: (context, index) {
                  final lapNum = _laps.length - index;
                  final isSlowest = _laps.length > 1 &&
                      _laps[index] == _laps.reduce((a, b) => a > b ? a : b);
                  final isFastest = _laps.length > 1 &&
                      _laps[index] == _laps.reduce((a, b) => a < b ? a : b);

                  Color labelColor = theme.textMuted;
                  if (isSlowest) labelColor = theme.readableOn('red', bg);
                  if (isFastest) {
                    labelColor = theme.readableOn(theme.primaryColor, bg);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.lapNumber(lapNum),
                          style: TextStyle(color: labelColor),
                        ),
                        Text(
                          _fmt(_laps[index]),
                          style: TextStyle(
                            color: labelColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
