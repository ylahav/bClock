# bClock

A minimalist desktop clock for Windows: an analog or digital clock that sizes its
window to fit, a stopwatch, a countdown timer, world clocks, and alarms that
ring even when the app is closed.

Built with Flutter and the [Plinth](https://pub.dev/packages/plinth_components)
UI kit.

| Light | Dark |
|---|---|
| ![bClock in light theme, analog and digital clock](docs/screenshots/clock-light.png) | ![bClock in dark theme, analog and digital clock](docs/screenshots/clock-dark.png) |

## Features

- **Clock** — analog, digital, or both stacked, in three sizes. The window
  resizes itself to fit the clock, and the controls and bottom navigation can be
  collapsed for a bare clock face. Optional *always on top*.
- **Stopwatch** — with laps (fastest and slowest highlighted). A running
  stopwatch keeps counting while the app is closed.
- **Timer** — a countdown with presets (1 to 45 minutes), a custom value in
  hours, minutes and seconds (tap the time, or *Custom…*), and ±1 minute. Like
  the stopwatch it survives the app closing, and it rings even when bClock
  isn't running, the same way alarms do.
- **Meeting planner** — in World clocks, a time slider previews every city at
  a chosen time today and highlights the ones in working hours (9:00 to
  18:00 there).
- **World clocks** — pick cities from a list of 39; times are DST-aware and show
  the local zone abbreviation (EST/EDT, CET/CEST…). Shown as analog, digital, or
  both.
- **Alarms** — repeat on chosen weekdays or fire once, with a label, a 5-minute
  snooze, and a looping sound. A ringing alarm or timer also shows a Windows
  notification, so it's seen behind other windows; Snooze, +1 min and Dismiss
  work from the notification too. They also fire when bClock isn't running (see
  [How alarms work](#how-alarms-work)).
- **Tray** — closing the window hides bClock in the system tray, so alarms,
  snooze, the timer and the stopwatch keep running. Click the tray icon to
  show it; right-click to quit. Can be turned off in Settings.
- **Languages** — English, Spanish, French and Hebrew (right-to-left), or follow
  the Windows language.
- **Light and dark themes**, and a configurable first day of the week (Sunday or
  Monday).

All settings are remembered between runs.

## Requirements

- Windows 10 or 11
- [Flutter](https://docs.flutter.dev/get-started/install/windows) (stable
  channel; developed on 3.47) with the **Desktop development with C++** workload
  of Visual Studio installed

Other platforms aren't built or supported.

## Getting started

```sh
flutter pub get
flutter run -d windows
```

| Task | Command |
|---|---|
| Static analysis | `flutter analyze` |
| Tests | `flutter test` |
| Release build | `flutter build windows --release` |
| Installer (`setup.exe`) | `.\installer\build.ps1` |

The release build lands in `build\windows\x64\runner\Release\`.

**Installer.** [`installer/bclock.iss`](installer/bclock.iss)
packages the release build with [Inno Setup 6](https://jrsoftware.org/isinfo.php)
into `build\installer\bClock_Setup_<version>.exe`.
[`installer/build.ps1`](installer/build.ps1) does it in one step: it runs the
release build, then compiles the installer with the version from
`pubspec.yaml` (`-SkipBuild` reuses an existing build). It installs per user without an admin
prompt, adds a Start menu entry, and its uninstaller also removes the alarm
scheduled tasks. Unsigned, so SmartScreen warns about an unknown publisher.
CI builds it on every push to `main` (artifact `bclock-setup-<sha>`).

## How alarms work

Alarms fire through two independent paths:

1. **While bClock is running**, it checks the alarm list every 10 seconds and
   shows the alarm popup.
2. **While bClock is closed**, each enabled alarm is also registered as a
   Windows scheduled task named `bClock_alarm_<id>`, which launches
   `bclock.exe --fire <id>`. The tasks are re-synced every time an alarm is
   added, edited, toggled or deleted.

If bClock is already open when a task fires, the launch is handed to the
running window instead of starting a second copy.

The `setup.exe` uninstaller removes the tasks. To remove them by hand:

```powershell
Get-ScheduledTask -TaskName 'bClock_alarm_*' | Unregister-ScheduledTask -Confirm:$false
```

If Windows doesn't accept the tasks, the Alarm tab says so, with a *Try again*
button: until it works, alarms only ring while bClock is running (which,
with the tray, includes after you close the window).

### Known limitations

- Alarms fire while bClock is closed only when the user is **logged in**
  (the scheduled tasks use the default trigger settings).
- The tasks ask Windows to **wake the PC from sleep**, which only works when
  the power plan's "Allow wake timers" option is on. It is often off on
  battery: check *Power Options → Change advanced power settings → Sleep →
  Allow wake timers*.

## Project layout

```
lib/
  main.dart               App entry, --fire handling, tab shell
  providers/              AppProvider: all settings, persisted
  screens/                Clock, Stopwatch, Timer, World, Alarms, Settings
  services/               AlarmService (firing, snooze), TimerService and
                          AlarmScheduler (Windows tasks for both)
                          (Windows scheduled tasks)
  models/                 AlarmModel, WorldCity
  widgets/                AnalogClock, DigitalClock
  theme/                  Plinth theme and brand colour
  l10n/                   Translations (.arb) and generated localizations
test/                     Widget tests
windows/                  Windows runner
```

State lives in a single `AppProvider` (`provider` package) and is saved to
`SharedPreferences`.

## Translations

Strings live in `lib/l10n/app_<lang>.arb`, with English (`app_en.arb`) as the
template. To add a language:

1. Copy `app_en.arb` to `app_<code>.arb`, set `"@@locale"`, and translate the
   values (the `@`-prefixed entries are metadata — don't copy them).
2. Run `flutter gen-l10n` (it also runs as part of `flutter run`/`build`).
3. Add the language to the picker list in
   `lib/screens/settings_screen.dart`.

## License

[MIT](LICENSE). That includes the bundled assets: the alarm sound and the
icons are original, generated by [`tools/make_assets.py`](tools/make_assets.py)
(`python tools/make_assets.py`, needs Pillow), not taken from anywhere else.
