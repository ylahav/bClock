import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/alarm_model.dart';
import 'package_identity.dart';

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
  /// Returns whether Windows now holds exactly those tasks; false means
  /// alarms will only ring while bClock is running.
  static Future<bool> sync(List<AlarmModel> alarms) async {
    if (!Platform.isWindows) return true;

    final enabled = alarms.where((a) => a.isEnabled).toList();
    final exe = launchPath();
    return _run(buildScript(enabled, exe, File(exe).parent.path));
  }

  /// Registers the countdown timer's task to launch `bclock.exe
  /// --timer-done` at [endAt], or removes it when [endAt] is null.
  /// Returns whether PowerShell ran it without error.
  static Future<bool> syncTimer(DateTime? endAt) async {
    if (!Platform.isWindows) return true;
    final exe = launchPath();
    return _run(timerCommand(endAt, exe, File(exe).parent.path));
  }

  /// What a task runs to start bClock. A plain install runs the exe; the
  /// packaged (Store) build must go through its execution alias, since its
  /// exe sits in a protected folder whose path changes with every update.
  static String launchPath() =>
      isPackaged ? executionAliasPath : Platform.resolvedExecutable;

  /// Runs [script], stopping at its first error. True if it exited 0.
  static Future<bool> _run(String script) async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          "\$ErrorActionPreference = 'Stop'\n$script",
        ],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false; // PowerShell unavailable
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

  /// The PowerShell that replaces every alarm task, then checks that
  /// Windows holds exactly one per enabled alarm (exit 3 if not).
  @visibleForTesting
  static String buildScript(
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
    // A registration can fail without an error PowerShell stops on.
    buf.writeln(
      "if (@(Get-ScheduledTask -TaskName '$taskPrefix*' "
      "-ErrorAction SilentlyContinue).Count -ne ${enabled.length}) { exit 3 }",
    );
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
