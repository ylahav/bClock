# Roadmap

What's planned for bClock, roughly in order. ⭐ marks the next things to pick
up. Items move to **Done** with the PR that shipped them.

## Next

- ⭐ **Meeting planner** in World clocks: a time slider that shows every city
  at that moment, with working hours highlighted.
- **Make scheduler failures visible.** Each alarm change re-registers all tasks
  through a hidden PowerShell and ignores errors. Sync once edits settle, and
  warn when it fails, so an alarm never silently won't ring.

## Later

- **Mini mode:** a tiny, borderless, always-on-top clock to park anywhere.
- **Alarm sound options:** custom sounds, volume, and a gradual fade-in.
- **Skip next** occurrence of a repeating alarm (e.g. on a holiday).
- **Hourly chime** (optional).
- **Keyboard shortcuts:** Space start/stop and L lap on the stopwatch, 1–4 to
  switch tabs.
- **Export stopwatch laps** as CSV.
- **Start with Windows** setting (a per-user Startup entry; no admin needed).
- **Automatic updates:** check GitHub Releases on launch.
- **Code signing**, to remove SmartScreen's "unknown publisher" warning.

## Housekeeping

- **Clock tab sizing:** the clock now scales down instead of overflowing, but
  the sizing math can still predict a clock wider than the window. A simpler
  model would let the window fit exactly.
- **Split `test/widget_test.dart`** per screen. It has grown to cover every
  screen, and parallel PRs that each add a test there conflict.

## Done

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
