import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/sound_options.dart';
import '../providers/app_provider.dart';
import '../services/alarm_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Sentinel for "follow the OS" — PlinthSelect needs a non-null value
  /// per option.
  static const _system = 'system';

  /// Endonyms, deliberately untranslated: a user lost in the wrong
  /// language still needs to find their own.
  static const _languages = [
    PlinthSelectOption('en', 'English'),
    PlinthSelectOption('fr', 'Français'),
    PlinthSelectOption('es', 'Español'),
    PlinthSelectOption('he', 'עברית'),
  ];

  /// Asks for an audio file; null if cancelled. Replaced in tests (no
  /// file-picker plugin). Limited to formats Windows' player handles.
  @visibleForTesting
  static Future<String?> Function() pickSoundFile = () async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Audio', extensions: ['wav', 'mp3', 'm4a']),
    ]);
    return file?.path;
  };

  static String _dayName(BuildContext context, DateTime day) =>
      DateFormat.EEEE(Localizations.localeOf(context).toLanguageTag())
          .format(day);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final l = AppLocalizations.of(context);

    return PlinthPage(
      title: l.settings,
      titleOrder: 4,
      background: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      // PlinthPage has no implicit back button (AppBar did).
      leading: PlinthTooltip(
        message: l.back,
        child: PlinthActionIcon(
          semanticLabel: l.back,
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.maybePop(context),
          variant: PlinthVariant.subtle,
          color: 'gray',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          // ── Clock Display ──────────────────────────────────
          _SectionHeader(l.sectionClockDisplay),

          _SettingBlock(
            title: l.defaultView,
            subtitle: l.defaultViewHint,
            child: PlinthSegmentedControl<ClockView>(
              items: [
                PlinthSegmentedControlItem(ClockView.digital, l.viewDigital),
                PlinthSegmentedControlItem(ClockView.both, l.viewBoth),
                PlinthSegmentedControlItem(ClockView.analog, l.viewAnalog),
              ],
              value: p.clockView,
              onChanged: p.setClockView,
            ),
          ),

          // Digital position — only shown when "Both" is active
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: p.clockView == ClockView.both
                ? _SettingBlock(
                    title: l.digitalPosition,
                    subtitle: l.digitalPositionHint,
                    child: PlinthSegmentedControl<DigitalPosition>(
                      items: [
                        PlinthSegmentedControlItem(
                            DigitalPosition.above, l.aboveAnalog),
                        PlinthSegmentedControlItem(
                            DigitalPosition.below, l.belowAnalog),
                      ],
                      value: p.digitalPosition,
                      onChanged: p.setDigitalPosition,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          _SettingBlock(
            title: l.clockSize,
            subtitle: l.clockSizeHint,
            child: PlinthSegmentedControl<ClockSizeOption>(
              items: [
                PlinthSegmentedControlItem(ClockSizeOption.small, l.sizeSmall),
                PlinthSegmentedControlItem(
                    ClockSizeOption.medium, l.sizeMedium),
                PlinthSegmentedControlItem(ClockSizeOption.large, l.sizeLarge),
              ],
              value: p.clockSize,
              onChanged: p.setClockSize,
            ),
          ),

          const _Divider(),

          // ── Appearance ────────────────────────────────────
          _SectionHeader(l.sectionAppearance),

          _SwitchBlock(
            child: PlinthSwitch(
              label: l.darkMode,
              description: p.isDark ? l.usingDarkTheme : l.usingLightTheme,
              value: p.isDark,
              onChanged: (_) => p.toggleTheme(),
            ),
          ),

          const _Divider(),

          // ── Window ────────────────────────────────────────
          _SectionHeader(l.sectionWindow),

          _SwitchBlock(
            child: PlinthSwitch(
              label: l.alwaysOnTop,
              description: l.alwaysOnTopHint,
              value: p.alwaysOnTop,
              onChanged: p.setAlwaysOnTop,
            ),
          ),

          _SwitchBlock(
            child: PlinthSwitch(
              label: l.closeToTray,
              description: l.closeToTrayHint,
              value: p.closeToTray,
              onChanged: p.setCloseToTray,
            ),
          ),

          const _Divider(),

          // ── Alarm sound ───────────────────────────────────
          _SectionHeader(l.sectionAlarmSound),
          _AlarmSoundSettings(sound: p.sound, onChanged: p.setSound),

          const _Divider(),

          // ── Language ──────────────────────────────────────
          _SectionHeader(l.sectionLanguage),

          _SettingBlock(
            title: l.language,
            subtitle: l.languageHint,
            child: PlinthSelect<String>(
              options: [
                PlinthSelectOption(_system, l.languageSystem),
                ..._languages,
              ],
              value: p.languageCode ?? _system,
              onChanged: (v) =>
                  p.setLanguageCode(v == null || v == _system ? null : v),
            ),
          ),

          _SettingBlock(
            title: l.weekStart,
            subtitle: l.weekStartHint,
            child: PlinthSegmentedControl<WeekStart>(
              // Day names from the UI locale. 2024-01-01 was a Monday.
              items: [
                PlinthSegmentedControlItem(
                    WeekStart.sunday, _dayName(context, DateTime(2024, 1, 7))),
                PlinthSegmentedControlItem(
                    WeekStart.monday, _dayName(context, DateTime(2024, 1, 1))),
              ],
              value: p.weekStart,
              onChanged: p.setWeekStart,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Alarm sound ─────────────────────────────────────────────

/// Sound, volume, gradual increase and Preview for the ring.
class _AlarmSoundSettings extends StatelessWidget {
  final SoundOptions sound;
  final ValueChanged<SoundOptions> onChanged;

  const _AlarmSoundSettings({required this.sound, required this.onChanged});

  /// Picking "Your own file…" asks for the file straight away; cancelling
  /// with no file chosen before leaves the previous sound.
  Future<void> _pick(AlarmSound choice) async {
    if (choice != AlarmSound.custom) {
      onChanged(sound.copyWith(sound: choice));
      return;
    }
    final path = await SettingsScreen.pickSoundFile();
    if (path != null) {
      onChanged(sound.copyWith(sound: AlarmSound.custom, customPath: path));
    } else if (sound.customPath != null) {
      onChanged(sound.copyWith(sound: AlarmSound.custom));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final path = sound.customPath;
    final custom = sound.sound == AlarmSound.custom && path != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingBlock(
          title: l.alarmSound,
          subtitle: l.alarmSoundHint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlinthSelect<AlarmSound>(
                options: [
                  PlinthSelectOption(AlarmSound.beeps, l.soundBeeps),
                  PlinthSelectOption(AlarmSound.chime, l.soundChime),
                  PlinthSelectOption(AlarmSound.pulse, l.soundPulse),
                  PlinthSelectOption(AlarmSound.custom, l.soundCustom),
                ],
                value: sound.sound,
                onChanged: (v) {
                  if (v != null) _pick(v);
                },
              ),
              if (custom) ...[
                const SizedBox(height: 8),
                // The file's name; the full path is in the tooltip.
                PlinthTooltip(
                  message: path,
                  child: PlinthText(
                    path.split(RegExp(r'[\\/]')).last,
                    size: PlinthSize.sm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!File(path).existsSync()) ...[
                  const SizedBox(height: 4),
                  PlinthText(l.soundFileMissing,
                      size: PlinthSize.xs, color: 'red'),
                ],
                const SizedBox(height: 8),
                PlinthButton(
                  variant: PlinthVariant.light,
                  size: PlinthSize.xs,
                  onPressed: () => _pick(AlarmSound.custom),
                  child: Text(l.chooseFile),
                ),
              ],
            ],
          ),
        ),
        _SettingBlock(
          title: l.alarmVolume,
          subtitle: '${(sound.volume * 100).round()}%',
          child: Semantics(
            label: l.alarmVolume,
            child: PlinthSlider(
              value: sound.volume,
              min: 0.05,
              max: 1,
              divisions: 19,
              onChanged: (v) => onChanged(sound.copyWith(volume: v)),
            ),
          ),
        ),
        _SwitchBlock(
          child: PlinthSwitch(
            label: l.fadeIn,
            description: l.fadeInHint,
            value: sound.fadeIn,
            onChanged: (v) => onChanged(sound.copyWith(fadeIn: v)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 14),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: PlinthButton(
              variant: PlinthVariant.light,
              leadingIcon: const Icon(Icons.play_arrow),
              onPressed: AlarmService.instance.preview,
              child: Text(l.previewSound),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
      child: PlinthText(
        title.toUpperCase(),
        size: PlinthSize.xs,
        weight: FontWeight.w600,
        color: context.plinth.primaryColor,
      ),
    );
  }
}

class _SettingBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingBlock({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.plinth;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlinthText(title, weight: theme.weight(PlinthWeight.medium)),
          const SizedBox(height: 3),
          PlinthText(subtitle, size: PlinthSize.xs, color: 'gray'),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SwitchBlock extends StatelessWidget {
  final Widget child;
  const _SwitchBlock({required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: child,
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const PlinthDivider();
}
