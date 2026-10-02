import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../l10n/app_localizations.dart';
import 'app_window.dart';
import 'notification_service.dart';

/// bClock's tray icon, and closing the window to the tray.
///
/// With close-to-tray on (`AppProvider.closeToTray`, the default), the
/// window's X hides bClock instead of quitting, so alarms, snooze, the timer
/// and the stopwatch keep running in-app. Left-click the icon to show or
/// hide; right-click for Show bClock / Quit. The first hide explains itself
/// with a toast.
///
/// A no-op until [init], so tests (which never call it) don't need the
/// tray or window plugins.
class TrayService with WindowListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  static const String _kHintShown = 'tray.hintShown';
  static const int _hintToastId = 0x40000001;

  // Keep references: a collected TrayIcon removes the icon.
  TrayIcon? _icon;
  MenuItem? _showItem;
  MenuItem? _quitItem;
  bool _ready = false;
  AppLocalizations? _strings;

  /// Creates the tray icon. Call after the first frame, with the UI
  /// language's strings.
  Future<void> init({
    required bool closeToTray,
    required AppLocalizations strings,
  }) async {
    if (!Platform.isWindows || _ready) return;
    final icon = TrayIcon.create();
    final menu = Menu.create();
    final showItem = MenuItem.createWithLabelAndType('', MenuItemType.normal);
    final quitItem = MenuItem.createWithLabelAndType('', MenuItemType.normal);
    if (icon == null || menu == null || showItem == null || quitItem == null) {
      return; // no tray: the X keeps quitting
    }

    icon.icon = ImageAsset.fromAsset('assets/icons/app_icon.png');
    icon.setTooltip('bClock');
    showItem.addListener((e) {
      if (e is MenuItemClickedEvent) unawaited(AppWindow.raise());
    });
    quitItem.addListener((e) {
      if (e is MenuItemClickedEvent) unawaited(quit());
    });
    menu.addItem(showItem);
    menu.addSeparator();
    menu.addItem(quitItem);
    icon.setContextMenu(menu);
    icon.setContextMenuTrigger(ContextMenuTrigger.rightClicked);
    icon.addListener((e) {
      if (e is TrayIconClickedEvent) unawaited(_toggle());
    });

    _icon = icon;
    _showItem = showItem;
    _quitItem = quitItem;
    _ready = true;
    setStrings(strings);
    windowManager.addListener(this);
    await setCloseToTray(closeToTray);
  }

  /// Menu labels in the UI language; called again when it changes.
  void setStrings(AppLocalizations l) {
    _strings = l;
    _showItem?.label = l.trayShow;
    _quitItem?.label = l.trayQuit;
  }

  /// Whether the window's X hides to the tray (true) or quits.
  Future<void> setCloseToTray(bool value) async {
    if (!_ready) return;
    await windowManager.setPreventClose(value);
  }

  Future<void> _toggle() async {
    if (await windowManager.isVisible() && !await windowManager.isMinimized()) {
      await windowManager.hide();
    } else {
      await AppWindow.raise();
    }
  }

  /// Quits for real: the tray's Quit, whatever the close-to-tray setting.
  Future<void> quit() async {
    await windowManager.setPreventClose(false);
    _icon?.dispose();
    _icon = null;
    await windowManager.destroy();
  }

  @override
  Future<void> onWindowClose() async {
    // Only called while preventClose is on, i.e. close-to-tray.
    await windowManager.hide();
    await _hintOnce();
  }

  /// The first time bClock hides, say where it went.
  Future<void> _hintOnce() async {
    final l = _strings;
    final p = await SharedPreferences.getInstance();
    if (l == null || (p.getBool(_kHintShown) ?? false)) return;
    await p.setBool(_kHintShown, true);
    await NotificationService.instance.show(
      _hintToastId,
      title: l.trayHintTitle,
      body: l.trayHintBody,
      actions: const {},
      onAction: (_) {},
    );
  }
}
