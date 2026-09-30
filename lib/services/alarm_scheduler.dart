import 'dart:io';
import '../models/alarm_model.dart';

/// Reconciles Windows Task Scheduler entries with the current alarm list so
/// alarms fire even when bClock is closed. On non-Windows platforms this is
/// a no-op.
///
/// Caveats:
///  - MSIX-packaged builds run in an app container; `Register-ScheduledTask`
///    may be denied. Failure is silent (fire-and-forget by the caller).
///  - Tasks fire only when the user is logged in (default trigger settings).
///  - When a task fires and bClock is already running, a second instance
///    launches — we don't currently gate this with a single-instance mutex.
class AlarmScheduler {
  static const String taskPrefix = 'bClock_alarm_';

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

  /// Delete all bClock scheduled tasks and re-register one per enabled alarm.
  /// Fire-and-forget; errors are swallowed.
  static Future<void> sync(List<AlarmModel> alarms) async {
    if (!Platform.isWindows) return;

    final enabled = alarms.where((a) => a.isEnabled).toList();
    final exe = Platform.resolvedExecutable;
    final workDir = File(exe).parent.path;
    final script = _buildScript(enabled, exe, workDir);

    try {
      await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
      );
    } catch (_) {
      // Swallowed — nothing meaningful to do if PowerShell is unavailable.
    }
  }

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
      buf.writeln(_registerCommand(alarm, exe, workDir));
    }
    return buf.toString();
  }

  static String _registerCommand(
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

    // Single-quoted strings in PowerShell are literal — safe for backslashes
    // in paths. Escape any embedded single quote by doubling it.
    final exeQ = exe.replaceAll("'", "''");
    final workQ = workDir.replaceAll("'", "''");

    return "Register-ScheduledTask -TaskName '$name' "
        "-Action (New-ScheduledTaskAction -Execute '$exeQ' "
        "-Argument '--fire ${alarm.id}' -WorkingDirectory '$workQ') "
        "-Trigger ($trigger) -Force | Out-Null";
  }
}
