import 'package:flutter/material.dart';
import 'package:plinth_components/plinth_components.dart';
import 'package:intl/intl.dart';

class DigitalClock extends StatelessWidget {
  final DateTime time;

  /// Font size for the HH:mm portion
  final double fontSize;

  /// Hide the date line (used in "both" mode to save space)
  final bool compact;

  const DigitalClock({
    super.key,
    required this.time,
    this.fontSize = 72,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.plinth;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final timeStr = DateFormat('HH:mm').format(time);
    final seconds = DateFormat('ss').format(time);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.MMMMEEEEd(locale).format(time);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Seconds trail the minutes in every language; don't let an RTL
        // locale swap them to the left.
        PlinthLtr(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              PlinthClock(
                timeStr,
                size: fontSize,
                weight: FontWeight.w200,
                letterSpacing: -3,
              ),
              const SizedBox(width: 2),
              PlinthClock(
                seconds,
                size: fontSize * 0.36,
                weight: FontWeight.w300,
                color: theme.primaryColor,
                on: bg,
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(
            date,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w300,
              color: theme.textMuted,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}
