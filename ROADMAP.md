# Roadmap

What's planned for bClock, roughly in order. ⭐ marks the next things to pick
up. Items move to **Done** with the PR that shipped them.

## Next

Nothing is queued. Pick from Later.

## On hold

- **Code signing**, to remove SmartScreen's "unknown publisher" warning.
  **Chosen route: the Microsoft Store**, which signs MSIX packages for free.
  The package side is ready (`msix_config`, an execution alias for the alarm
  tasks, tested locally as a registered package). Waiting on: a Partner
  Center account, the reserved app name, and its identity values. The other
  options looked at, as of October 2026:
  - [SignPath Foundation](https://signpath.org): free for open source, but
    wants an established project with a reputation. Revisit once bClock has
    users and release history.
  - Certum Open Source Code Signing: from about €49, a cloud certificate
    (no hardware token). The realistic paid route for an individual.
  - Azure Trusted Signing: individual developers in the USA and Canada
    only.

## Later

- **Skip next** occurrence of a repeating alarm (e.g. on a holiday).
- **Keyboard shortcuts:** Space start/stop and L lap on the stopwatch, 1–4 to
  switch tabs.
- **Export stopwatch laps** as CSV.
- **Start with Windows** setting (a per-user Startup entry; no admin needed).
- **Automatic updates:** check GitHub Releases on launch.
- **Timer scheduling warning:** the timer's task sync reports failure, but
  only alarms show a warning for it.

## Housekeeping

- **Clock tab sizing:** the clock now scales down instead of overflowing, but
  the sizing math can still predict a clock wider than the window. A simpler
  model would let the window fit exactly.
- **Split `test/widget_test.dart`** per screen. It has grown to cover every
  screen, and parallel PRs that each add a test there conflict.

## Done

- Hourly chime: an optional bell on the hour, within chosen hours of the
  day, while bClock is running.
- Mini mode: a small, frameless, always-on-top clock; drag to move,
  double-click to return; remembered across restarts.
- Unanswered alarms stop after a minute and ring again a configurable number
  of times, a configurable interval apart, then leave a "Missed alarm" note.
- Alarm sound options: three built-in sounds or your own file, volume, and
  a gradual volume increase, with Preview in Settings.
- GitHub Releases: pushing a `v<version>` tag builds and publishes the
  installer. Exe metadata is real (publisher Yair Lahav), with saved data
  carried over from the old `com.example` folder.
- Original, generated alarm sound and icons (`tools/make_assets.py`).
- Scheduler failures are visible: the sync verifies its tasks, runs once
  edits settle, and the Alarm tab warns (with Try again) when it fails.
- Meeting planner in World clocks: a time slider previews every city, with
  working hours highlighted and counted.
- Keep running in the tray: closing hides bClock (setting, on by default);
  tray icon shows it, right-click to quit; a ring brings the window back.
- Windows notifications for a ringing alarm or timer, with Snooze / +1 min /
  Dismiss on the toast; answering either the toast or the popup ends both.
- Countdown timer tab: presets, ±1 min, survives restarts, rings with bClock
  closed via a scheduled task.
- Alarm tasks wake the PC, run on battery, and aren't stopped on unplug or
  after 72 hours; tasks re-sync on launch.
- `installer/build.ps1`: one command for `setup.exe`; CI uses it (#4).
- Drag to reorder world clocks, with a screen-reader alternative (#2).
- Clock tab no longer overflows a short window (#3).
- World clock list persists across restarts (#1).
- One bClock per exe: a second launch hands over to the running one (#1).
- `AlarmService` owns the alarm list; fixes one-shot alarms re-enabling (#1).
- Inno Setup installer replaces MSIX; CI builds it on `main` (#1).
- Dialogs take focus on open; Enter saves an alarm label (#1, Plinth 1.9.0).
