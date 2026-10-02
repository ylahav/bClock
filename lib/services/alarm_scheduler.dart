import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/alarm_model.dart';

/// Reconciles Windows Task Scheduler entries with the current alarm list so
/// alarms fire even when bClock is closed. On non-Windows platforms this is
/// a no-op.
///
/// Caveats:
///  - Tasks fire only when the user is logged in (default trigger settings).
///  - Waking from sleep also needs Windows' "Allow wake timers" power
///    option, which is often off on battery.
///  - When a task fires and bClock is already running, the Windows runner
///    forwards `--fire <id>` to the running instance (see single_instance.h).
class AlarmScheduler {
  static const String taskPrefix = 'bClock_alarm_';

  /// The countdown timer's task. Outside [taskPrefix] on purpose: [sync]
  /// wipes every `bClock_alarm_*` task on each alarm change.
  static const String timerTaskName = 'bClock_timer';

  static const List<String> _dayFull = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _taskName(String id) => '$taskPrefix$id';

  /// Task settings. Windows' defaults are wrong for an alarm: it would not
  /// wake a sleeping PC, would not start on battery, would be stopped on
  /// unplugging, and would kill the bClock it launched after 72 hours.
  static const String _settings = 'New-ScheduledTaskSettingsSet -WakeToRun '
      '-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries '
      '-ExecutionTimeLimit ([TimeSpan]::Zero)';

  /// Delete all bClock scheduled tasks and re-register one per enabled alarm.
  /// Fire-and-forget; errors are swallowed.
  static Future<void> sync(List<AlarmModel> alarms) async {
    if (!Platform.isWindows) return;

    final enabled = alarms.where((a) => a.isEnabled).toList();
    final exe = Platform.resolvedExecutable;
    final workDir = File(exe).parent.path;
    await _run(_buildScript(enabled, exe, workDir));
  }

  /// Registers the countdown timer's task to launch `bclock.exe
  /// --timer-done` at [endAt], or removes it when [endAt] is null.
  /// Fire-and-forget; errors are swallowed.
  static Future<void> syncTimer(DateTime? endAt) async {
    if (!Platform.isWindows) return;
    final exe = Platform.resolvedExecutable;
    await _run(timerCommand(endAt, exe, File(exe).parent.path));
  }

  static Future<void> _run(String script) async {
    try {
      await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
      );
    } catch (_) {
      // Swallowed — nothing meaningful to do if PowerShell is unavailable.
    }
  }

  /// The PowerShell that replaces the timer's task.
  @visibleForTesting
  static String timerCommand(DateTime? endAt, String exe, String workDir) {
    final remove = "Unregister-ScheduledTask -TaskName '$timerTaskName' "
        "-Confirm:\$false -ErrorAction SilentlyContinue";
    if (endAt == null) return remove;
    String two(int n) => n.toString().padLeft(2, '0');
    final at = '${endAt.year}-${two(endAt.month)}-${two(endAt.day)}'
        'T${two(endAt.hour)}:${two(endAt.minute)}:${two(endAt.second)}';
    return "$remove\n"
        "Register-ScheduledTask -TaskName '$timerTaskName' "
        "-Action (New-ScheduledTaskAction -Execute '${_quote(exe)}' "
        "-Argument '--timer-done' -WorkingDirectory '${_quote(workDir)}') "
        "-Trigger (New-ScheduledTaskTrigger -Once -At '$at') "
        "-Settings ($_settings) -Force | Out-Null";
  }

  // Single-quoted strings in PowerShell are literal — safe for backslashes
  // in paths. Escape any embedded single quote by doubling it.
  static String _quote(String s) => s.replaceAll("'", "''");

  static String _buildScript(
    List<AlarmModel> enabled,
    String exe,
    String workDir,
  ) {
    final buf = StringBuffer();
    // Wipe any existing bClock tasks so we don't leave stale entries.
    buf.writeln(
      "Get-ScheduledTask -TaskName '$taskPrefix*' -ErrorAction SilentlyContinue | "
      "Unregister-ScheduledTask -Confirm:\$false -ErrorAction SilentlyContinue",
    );
    for (final alarm in enabled) {
      buf.writeln(registerCommand(alarm, exe, workDir));
    }
    return buf.toString();
  }

  /// The PowerShell line that registers [alarm]'s task.
  @visibleForTesting
  static String registerCommand(
    AlarmModel alarm,
    String exe,
    String workDir,
  ) {
    final name = _taskName(alarm.id);
    final time =
        '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}';

    final String trigger;
    if (alarm.repeat) {
      if (alarm.days.any((d) => d)) {
        final days = <String>[];
        for (var i = 0; i < 7; i++) {
          if (alarm.days[i]) days.add(_dayFull[i]);
        }
        trigger =
            "New-ScheduledTaskTrigger -Weekly -DaysOfWeek ${days.join(',')} -At '$time'";
      } else {
        trigger = "New-ScheduledTaskTrigger -Daily -At '$time'";
      }
    } else {
      final next = alarm.nextOccurrence;
      final iso = '${next.year.toString().padLeft(4, '0')}-'
          '${next.month.toString().padLeft(2, '0')}-'
          '${next.day.toString().padLeft(2, '0')}'
          'T$time:00';
      trigger = "New-ScheduledTaskTrigger -Once -At '$iso'";
    }

    return "Register-ScheduledTask -TaskName '$name' "
        "-Action (New-ScheduledTaskAction -Execute '${_quote(exe)}' "
        "-Argument '--fire ${alarm.id}' -WorkingDirectory '${_quote(workDir)}') "
        "-Trigger ($trigger) -Settings ($_settings) -Force | Out-Null";
  }
}
