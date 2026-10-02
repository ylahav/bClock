import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:plinth_blocks/plinth_blocks.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/alarm_model.dart';
import '../providers/app_provider.dart';
import '../services/alarm_service.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  // AlarmService owns the list (loaded before the first frame); this
  // screen edits it in place and saves through the service.
  final _service = AlarmService.instance;
  List<AlarmModel> get _alarms => _service.alarms;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onAlarmsChanged);
    // First run: seed after the first frame, when localizations exist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_service.hasSavedAlarms) {
        _service.setAlarms(_defaultAlarms());
      }
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onAlarmsChanged);
    super.dispose();
  }

  void _onAlarmsChanged() => setState(() {});

  // ── Persistence ───────────────────────────────────────────

  void _save() => _service.setAlarms(_alarms);

  /// Seeded once, in the language active at first run; after that the
  /// labels are the user's own text and are not re-translated.
  List<AlarmModel> _defaultAlarms() {
    final l = AppLocalizations.of(context);
    return [
      AlarmModel(
          id: '1',
          hour: 7,
          minute: 0,
          label: l.defaultAlarmWakeUp,
          repeat: true),
      AlarmModel(
          id: '2',
          hour: 8,
          minute: 30,
          label: l.defaultAlarmMorning,
          repeat: false),
    ];
  }

  // ── Smart default: next round 5-min slot ─────────────────

  TimeOfDay _smartDefault() {
    final now = DateTime.now();
    int h = now.hour;
    int m = ((now.minute + 6) ~/ 5) * 5;
    if (m >= 60) {
      m = 0;
      h = (h + 1) % 24;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  // ── Add ───────────────────────────────────────────────────

  Future<void> _addAlarm() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _smartDefault(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _alarms.add(AlarmModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        hour: picked.hour,
        minute: picked.minute,
        repeat: false,
      ));
      _sort();
    });
    _save();
  }

  // ── Edit time ─────────────────────────────────────────────

  Future<void> _editTime(String id) async {
    final alarm = _alarms.firstWhere((a) => a.id == id);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: alarm.hour, minute: alarm.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      alarm.hour = picked.hour;
      alarm.minute = picked.minute;
      _sort();
    });
    _save();
  }

  // ── Edit label ────────────────────────────────────────────

  Future<void> _editLabel(String id) async {
    final alarm = _alarms.firstWhere((a) => a.id == id);
    final controller = TextEditingController(text: alarm.label);
    final modal = PlinthDisclosureController(initiallyOpen: true);
    String? result;

    final l = AppLocalizations.of(context);
    await PlinthModal(
      controller: modal,
      title: l.labelTitle,
      size: PlinthSize.xs,
      child: Builder(
        builder: (ctx) => PlinthStack(
          children: [
            PlinthTextInput(
              controller: controller,
              placeholder: l.labelPlaceholder,
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
              autofocus: true,
              // Enter saves, like the Save button.
              onSubmitted: (value) {
                result = value.trim();
                Navigator.pop(ctx);
              },
            ),
            PlinthGroup(
              mainAxisAlignment: MainAxisAlignment.end,
              gap: PlinthSize.sm,
              children: [
                PlinthButton(
                  variant: PlinthVariant.subtle,
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l.cancel),
                ),
                PlinthButton(
                  onPressed: () {
                    result = controller.text.trim();
                    Navigator.pop(ctx);
                  },
                  child: Text(l.save),
                ),
              ],
            ),
          ],
        ),
      ),
    ).show(context);
    modal.dispose();

    final label = result;
    if (label == null) return;
    setState(() => alarm.label = label);
    _save();
  }

  // ── Helpers ───────────────────────────────────────────────

  void _sort() {
    _alarms.sort((a, b) => a.hour != b.hour
        ? a.hour.compareTo(b.hour)
        : a.minute.compareTo(b.minute));
  }

  void _delete(String id) {
    setState(() => _alarms.removeWhere((a) => a.id == id));
    _save();
  }

  void _toggleEnabled(String id) {
    setState(() {
      final a = _alarms.firstWhere((x) => x.id == id);
      a.isEnabled = !a.isEnabled;
    });
    _save();
  }

  void _toggleRepeat(String id) {
    setState(() {
      final a = _alarms.firstWhere((x) => x.id == id);
      a.repeat = !a.repeat;
    });
    _save();
  }

  void _toggleDay(String id, int i) {
    setState(() {
      _alarms.firstWhere((x) => x.id == id).days[i] =
          !_alarms.firstWhere((x) => x.id == id).days[i];
    });
    _save();
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Narrow weekday names in the UI language, indexed like
    // AlarmModel.days (Monday first). 2024-01-01 was a Monday.
    // Display order comes from the week-start setting instead.
    final dayLabels = List.generate(
      7,
      (i) => DateFormat.EEEEE(Localizations.localeOf(context).toLanguageTag())
          .format(DateTime(2024, 1, 1 + i)),
    );
    final dayOrder = context.watch<AppProvider>().weekStart.dayOrder;

    return PlinthPage(
      title: l.alarmsTitle,
      titleOrder: 4,
      background: Theme.of(context).scaffoldBackgroundColor,
      actions: [
        PlinthTooltip(
          message: l.addAlarm,
          child: PlinthActionIcon(
            semanticLabel: l.addAlarm,
            icon: const Icon(Icons.add),
            onPressed: _addAlarm,
            variant: PlinthVariant.subtle,
            color: 'gray',
          ),
        ),
      ],
      body: _alarms.isEmpty
          ? Center(
              child: PlinthEmptyState(
                icon: const Icon(Icons.alarm_off_outlined),
                title: l.noAlarms,
                action: PlinthButton(
                  variant: PlinthVariant.light,
                  leadingIcon: const Icon(Icons.add),
                  onPressed: _addAlarm,
                  child: Text(l.addAnAlarm),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _alarms.length,
              separatorBuilder: (_, __) => const PlinthDivider(),
              itemBuilder: (context, index) {
                final alarm = _alarms[index];
                return _AlarmTile(
                  alarm: alarm,
                  dayLabels: dayLabels,
                  dayOrder: dayOrder,
                  onEditTime: () => _editTime(alarm.id),
                  onEditLabel: () => _editLabel(alarm.id),
                  onToggleEnabled: () => _toggleEnabled(alarm.id),
                  onToggleRepeat: () => _toggleRepeat(alarm.id),
                  onToggleDay: (i) => _toggleDay(alarm.id, i),
                  onDelete: () => _delete(alarm.id),
                );
              },
            ),
    );
  }
}

// ── Alarm tile ──────────────────────────────────────────────────

class _AlarmTile extends StatelessWidget {
  final AlarmModel alarm;
  final List<String> dayLabels;

  /// Indices into [dayLabels] / [AlarmModel.days], in display order.
  final List<int> dayOrder;
  final VoidCallback onEditTime;
  final VoidCallback onEditLabel;
  final VoidCallback onToggleEnabled;
  final VoidCallback onToggleRepeat;
  final ValueChanged<int> onToggleDay;
  final VoidCallback onDelete;

  const _AlarmTile({
    required this.alarm,
    required this.dayLabels,
    required this.dayOrder,
    required this.onEditTime,
    required this.onEditLabel,
    required this.onToggleEnabled,
    required this.onToggleRepeat,
    required this.onToggleDay,
    required this.onDelete,
  });

  String _nextLabel(BuildContext context, AppLocalizations l) {
    if (!alarm.isEnabled) return l.alarmDisabled;
    return switch (alarm.daysUntilNext) {
      0 => l.today,
      1 => l.tomorrow,
      _ => DateFormat.MMMEd(Localizations.localeOf(context).toLanguageTag())
          .format(alarm.nextOccurrence),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.plinth;
    final l = AppLocalizations.of(context);
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final activeColor = alarm.isEnabled ? theme.text : theme.textDisabled;
    final accentColor = alarm.isEnabled
        ? theme.readableOn(theme.primaryColor, bg)
        : theme.textDisabled;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left column ──────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time (tappable → edit)
                PlinthUnstyledButton(
                  onPressed: onEditTime,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        alarm.timeString,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w200,
                          color: activeColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            bottom: 7, start: 4),
                        child: Text(
                            DateFormat(
                                    'a',
                                    Localizations.localeOf(context)
                                        .toLanguageTag())
                                .format(DateTime(2024, 1, 1, alarm.hour)),
                            style: TextStyle(fontSize: 14, color: accentColor)),
                      ),
                      const Spacer(),
                      // Next occurrence badge
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.only(bottom: 8, end: 4),
                        child: PlinthBadge(
                          _nextLabel(context, l),
                          color: alarm.isEnabled ? theme.primaryColor : 'gray',
                        ),
                      ),
                    ],
                  ),
                ),

                // Label (tappable → edit)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 10),
                  child: PlinthUnstyledButton(
                    onPressed: onEditLabel,
                    child: Row(
                      children: [
                        Flexible(
                          child: PlinthText(
                            alarm.label.isNotEmpty ? alarm.label : l.addLabel,
                            size: PlinthSize.sm,
                            italic: alarm.label.isEmpty,
                            color: 'gray',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_outlined,
                            size: 13, color: theme.textDisabled),
                      ],
                    ),
                  ),
                ),

                // Day toggles
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: dayOrder.map((i) {
                    final on = alarm.days[i];
                    return Semantics(
                      toggled: on,
                      child: PlinthButton(
                        size: PlinthSize.xs,
                        radius: PlinthSize.xl,
                        variant:
                            on ? PlinthVariant.filled : PlinthVariant.light,
                        color: on ? theme.primaryColor : 'gray',
                        onPressed: () => onToggleDay(i),
                        child: Text(dayLabels[i]),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 8),

                // Repeat chip + delete. Delete lives on this full-width
                // row because the confirm step expands inline.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    PlinthChip(
                      label: l.repeat,
                      size: PlinthSize.xs,
                      selected: alarm.repeat,
                      onSelected: (_) => onToggleRepeat(),
                    ),
                    PlinthConfirmButton(
                      label: l.delete,
                      icon: const Icon(Icons.delete_outline),
                      question: l.deleteAlarmQuestion,
                      confirmLabel: l.delete,
                      cancelLabel: l.cancel,
                      size: PlinthSize.xs,
                      onConfirm: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Right column: switch ──────────────────────────
          PlinthSwitch(
              value: alarm.isEnabled, onChanged: (_) => onToggleEnabled()),
        ],
      ),
    );
  }
}
