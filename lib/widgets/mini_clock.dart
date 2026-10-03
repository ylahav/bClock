import 'dart:async';
import 'package:flutter/material.dart';
import 'package:plinth_components/plinth_components.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_provider.dart';
import '../services/app_window.dart';
import 'analog_clock.dart';
import 'digital_clock.dart';

/// Mini mode's whole window: just the clock, in the user's clock view,
/// scaled to fit. Drag it anywhere to move the window; double-click, or the
/// button that appears on hover, goes back to the full app.
class MiniClock extends StatefulWidget {
  final ClockView view;
  final DigitalPosition digitalPosition;
  final VoidCallback onExit;

  const MiniClock({
    super.key,
    required this.view,
    required this.digitalPosition,
    required this.onExit,
  });

  @override
  State<MiniClock> createState() => _MiniClockState();
}

class _MiniClockState extends State<MiniClock> {
  late DateTime _now = DateTime.now();
  late final Timer _timer;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Widget _clock() {
    final digital = DigitalClock(time: _now, fontSize: 56, compact: true);
    final analog = AnalogClock(time: _now, size: 200);
    return switch (widget.view) {
      ClockView.digital => digital,
      ClockView.analog => analog,
      ClockView.both => Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.digitalPosition == DigitalPosition.above
              ? [digital, const SizedBox(height: 12), analog]
              : [analog, const SizedBox(height: 12), digital],
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Stack(
          children: [
            // There is no title bar: the clock itself is the drag handle.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => AppWindow.startDrag(),
                onDoubleTap: widget.onExit,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: FittedBox(child: _clock()),
                ),
              ),
            ),
            if (_hovering)
              PositionedDirectional(
                top: 2,
                end: 2,
                child: PlinthTooltip(
                  message: l.exitMiniMode,
                  child: PlinthActionIcon(
                    semanticLabel: l.exitMiniMode,
                    icon: const Icon(Icons.open_in_full),
                    onPressed: widget.onExit,
                    variant: PlinthVariant.light,
                    color: 'gray',
                    size: PlinthSize.xs,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
