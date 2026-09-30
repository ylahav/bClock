# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

bClock is a minimalist **Windows desktop** Flutter app: analog/digital clock, stopwatch, world clocks, and alarms. Primary target is Windows (see `windows/` and MSIX packaging in `pubspec.yaml`); other platforms are not currently built.

## Commands

- Run in dev: `flutter run -d windows`
- Static analysis / lint: `flutter analyze`
- Tests: `flutter test` (single file: `flutter test test/widget_test.dart`)
- Release build: `flutter build windows --release`
- MSIX installer: `flutter pub run msix:create` (config lives under `msix_config:` in `pubspec.yaml`; unsigned by default)
- Fetch deps: `flutter pub get`

## Architecture

### State & persistence
- Global state is a single `AppProvider` (`lib/providers/app_provider.dart`) — a `ChangeNotifier` provided at the root in `main.dart` and consumed via `provider`. It owns theme mode, clock view (analog/digital/both), digital position, clock size, `alwaysOnTop`, and nav-bar visibility.
- Every setter calls `notifyListeners()` and then `_save()` to `SharedPreferences`. `AppProvider.load()` is awaited **before** `runApp` so first frame renders with restored state.
- `setAlwaysOnTop` also calls `windowManager.setAlwaysOnTop` — the provider is the single source of truth for that OS-level flag.

### Screen shell
- `MainScreen` in `main.dart` is a stateful `IndexedStack` of the four screens with a `NavigationBar`. The nav bar can be collapsed via a chevron handle; visibility is persisted (`AppProvider.showNav`).
- `ClockScreen` receives `active: _currentIndex == 0` so it only drives window resizing when it's the visible tab.

### Auto-resizing window (Clock screen)
- `ClockScreen` uses `window_manager` + `WindowListener` to **compute a target window height from clock view/size/controls state** and call `windowManager.setSize`. Any change to clock view, size, controls visibility, or nav visibility triggers `_scheduleFit` → `_fitWindowHeight`.
- `_lastFit*` fields deduplicate fit calls, and `_fittingWindow` guards against re-entrancy when our own resize triggers `onWindowResize`. When editing sizing logic, preserve these guards or you will get resize loops.
- Sizing constants (`_widthFill`, `_navBarHeight`, `_bothHeightFactor`, etc.) at the top of the class encode the layout math — change them, don't sprinkle magic numbers.
- The page header is a `PlinthPage`, whose height follows the type scale, so it is **measured, not a constant**: an outer `LayoutBuilder` (whole tab, window width) and the inner body `LayoutBuilder` give `_pageChrome` (padding + header + gap). `_lastFitChrome` is part of the dedupe. Always pass the **window** width (`page.maxWidth`) to `_fitWindowHeight`, never the body width, or the window shrinks horizontally on every fit.

### Alarm system
- `AlarmService` (`lib/services/alarm_service.dart`) is a singleton started once in `main.dart` and given a `GlobalKey<NavigatorState>` so it can `showDialog` without a `BuildContext`.
- Two firing paths run in parallel:
  1. **In-app polling** — `Timer.periodic` every 10s scans `alarms` for a matching hour/minute. `_firedIds` + `_lastMinute` de-dupes within the current minute.
  2. **Closed-app firing** — `AlarmScheduler` (`lib/services/alarm_scheduler.dart`) syncs one Windows scheduled task per enabled alarm via PowerShell (`Register-ScheduledTask`). Each task runs `bClock.exe --fire <alarmId>`; `main.dart` parses the arg and calls `AlarmService.fireById(id)` after the first frame. `fireById` reads the alarm directly from `SharedPreferences` (since `AlarmScreen` may not have loaded yet) and seeds `_firedIds`/`_lastMinute` so the polling loop won't double-fire.
- `AlarmService.setAlarms(...)` is the single mutation entry point — it updates the polling list AND fire-and-forget syncs the scheduler. `AlarmScreen` calls it after every add/delete/edit/toggle.
- The popup offers Snooze (default 5 min, `AlarmService.snoozeDuration`) and Dismiss. Snooze re-fires via a one-shot `Timer` stored per alarm id in `_snoozeTimers` — a second snooze cancels the pending one instead of stacking.
- Persistence: `AlarmScreen` writes the JSON list to `SharedPreferences` under `AlarmService.alarmsStorageKey` (`'alarms'`). Both `AlarmScreen._load` and `AlarmService.fireById` read from this key. On first run (key missing) the screen seeds two default alarms; after that an empty list is a valid persisted state.
- `AlarmModel.days` is **always stored Monday-first** (index = `DateTime.weekday - 1`); the polling loop and the scheduler's `-DaysOfWeek` both depend on that. The user's week-start setting (`AppProvider.weekStart`, Sunday or Monday) only changes the display order in the alarm day picker, via `WeekStart.dayOrder` — never re-index stored data.
- Sound plays in loop mode via `audioplayers` using the asset `assets/sounds/alarm.wav`; dismiss stops it.
- **Known caveats:** (1) MSIX-packaged builds may be sandboxed and unable to register scheduled tasks — the sync fails silently. (2) If bClock is already running when a task fires, Windows launches a second instance (no single-instance mutex yet). (3) `fireById` and `AlarmScreen._load` race on the shared prefs key; if AlarmScreen wins, a one-shot alarm's in-memory `isEnabled` stays true until app restart. See TODO in `AlarmService.fireById`.

### Theming
- UI is built on **Plinth** (`plinth_components`, published on pub.dev; source at `../plinth_ui`). `AppTheme` (`lib/theme/app_theme.dart`) builds a `PlinthTheme` with a `'brand'` ramp anchored to `AppTheme.brandColor` (`#2196F3`) as `primaryColor`, registers it as a `ThemeData` extension, and derives Material's `ColorScheme` from it via `toColorScheme()` so the remaining Material widgets agree. Scaffold / nav / app-bar backgrounds are hard-coded greys (`0xFFF8F9FA` / `0xFF111111`) — keep that if you touch the theme.
- Read colours from `context.plinth` (`text`, `textMuted`, `textDisabled`, `surface`, `readableOn(name, bg)` for palette colours used as text/icons), not `Theme.of(context).colorScheme`. Component `color:` props take palette keys (`'gray'`, `'red'`, `theme.primaryColor`), not `Color`s.
- Screens are `PlinthPage` (from `plinth_blocks`, public pub.dev release only) with `titleOrder: 4` and `background: Theme.of(context).scaffoldBackgroundColor` to keep the greys. `PlinthPage` has no implicit back button — pushed routes (Settings) pass `leading` explicitly. Screens import `package:plinth_blocks/plinth_blocks.dart`, which re-exports `plinth_components`.
- Destructive row actions use `PlinthConfirmButton` (alarm delete), placed on a full-width row because its confirm step expands inline; always pass localized `question`/`confirmLabel`/`cancelLabel` (defaults are English).
- Material widgets still in use only where Plinth has no equivalent: `NavigationBar`, `showTimePicker`, `GridView`/`ListView`. Dialogs are `PlinthModal(...).show(context)` with a throwaway `PlinthDisclosureController`.

### Widgets
- `AnalogClock` and `DigitalClock` in `lib/widgets/` are pure presentational: they receive `time` + a size (`size` for analog, `fontSize` for digital) and are re-rendered every second by their parent's `Timer.periodic`. Do not add clocks/timers inside these widgets.
- Changing numbers (clock digits, stopwatch) render with `PlinthClock` (tabular figures, line height 1, size-aware contrast floor), not `Text`/`PlinthText`. A **duration** needs a `semanticLabel` (`l.elapsedDuration`), or screen readers read `01:30` as a time of day.

### Stopwatch
- `StopwatchScreen` doesn't use `Stopwatch` — instead, `_baseElapsed` (Duration) + `_runStartAt` (DateTime?, null when paused). Displayed elapsed = `_baseElapsed + (running ? now - _runStartAt : 0)`. This is what makes a running stopwatch survive app close: `_runStartAt` is a wall-clock timestamp, so reopening hours later computes the correct elapsed. Persisted to `SharedPreferences` (`sw.baseMs`, `sw.runStartMs`, `sw.laps`) **only on state transitions** (start/pause/reset/lap) — never on tick.

### World clocks
- `WorldCity` (`lib/models/world_city.dart`) holds a hard-coded `pool` and `defaults`. Each entry stores an **IANA zone id** (`tz`, e.g. `America/New_York`) — no cached offset. Time is resolved via `tz.TZDateTime.from(utcNow, tz.getLocation(city.tz))`, which is DST-aware; the abbreviation shown in the UI comes from `TZDateTime.timeZoneName` (so "EST" flips to "EDT" automatically). tzdata is initialized once in `main.dart` via `timezone/data/latest_all.dart`. `==`/`hashCode` keys on `(city, country)`.

## Conventions

- Use `provider`'s `context.watch<AppProvider>()` in `build`, `context.read<AppProvider>()` for one-off reads (event handlers, async gaps). Don't introduce a second state-management library.
- Persist any new user-facing setting through `AppProvider` with a `_kSomething` key and add it to both `load()` and `_save()`.
- Windows sizing changes should route through `ClockScreen._fitWindowHeight`; don't call `windowManager.setSize` directly from other screens.
