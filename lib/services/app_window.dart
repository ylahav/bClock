import 'package:window_manager/window_manager.dart';

/// Window actions the services need. Replaced in tests, which have no
/// window plugin.
class AppWindow {
  AppWindow._();

  /// Shows bClock (from the tray, or minimised) and brings it to the front.
  static Future<void> Function() raise = () async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  };

  /// Starts moving the window with the pointer: mini mode has no title bar
  /// to drag.
  static Future<void> Function() startDrag = windowManager.startDragging;

  /// Leaves mini mode if it is on (set by main.dart): a ring's popup needs
  /// the full window. A no-op otherwise.
  static Future<void> Function() leaveMini = () async {};

  /// The full window, in front: what a ring needs before its popup.
  static Future<void> showForPopup() async {
    await leaveMini();
    await raise();
  }
}
