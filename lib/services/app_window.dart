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
}
