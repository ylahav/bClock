import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Turns the window into mini mode's small, frameless, always-on-top clock
/// and back. Replaced in tests, which have no window plugin.
///
/// The normal window's bounds and the mini window's position are saved, so
/// each mode comes back where it was left, also across restarts.
class MiniWindow {
  MiniWindow._();

  static const String _kNormal = 'mini.normalBounds';
  static const String _kPosition = 'mini.position';

  static const Size _normalMinimum = Size(240, 240);
  static const Size _miniMinimum = Size(100, 60);
  static const Size _normalDefault = Size(340, 300);

  /// Shrinks the window to [size] with no title bar. [saveNormal] is false
  /// when starting up already in mini mode: the bounds on screen then are
  /// not the normal window's.
  static Future<void> Function(Size size, {bool saveNormal}) enter = _enter;

  /// Restores the normal window, with the user's [alwaysOnTop] setting.
  static Future<void> Function({required bool alwaysOnTop}) exit = _exit;

  static Future<void> _enter(Size size, {bool saveNormal = true}) async {
    final p = await SharedPreferences.getInstance();
    if (saveNormal) {
      final b = await windowManager.getBounds();
      await p.setStringList(
          _kNormal, [b.left, b.top, b.width, b.height].map(_str).toList());
    }
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden,
        windowButtonVisibility: false);
    await windowManager.setMinimumSize(_miniMinimum);
    await windowManager.setSize(size);
    await windowManager.setResizable(false);
    await windowManager.setAlwaysOnTop(true);
    final at = _numbers(p.getStringList(_kPosition), 2);
    if (at != null) await windowManager.setPosition(Offset(at[0], at[1]));
  }

  static Future<void> _exit({required bool alwaysOnTop}) async {
    final p = await SharedPreferences.getInstance();
    final at = await windowManager.getPosition();
    await p.setStringList(_kPosition, [at.dx, at.dy].map(_str).toList());

    await windowManager.setResizable(true);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(_normalMinimum);
    await windowManager.setAlwaysOnTop(alwaysOnTop);
    final b = _numbers(p.getStringList(_kNormal), 4);
    if (b != null) {
      await windowManager.setBounds(Rect.fromLTWH(b[0], b[1], b[2], b[3]));
    } else {
      await windowManager.setSize(_normalDefault);
      await windowManager.center();
    }
  }

  static String _str(double v) => v.toString();

  /// [count] saved numbers, or null if missing or malformed.
  static List<double>? _numbers(List<String>? raw, int count) {
    if (raw == null || raw.length != count) return null;
    final values = raw.map(double.tryParse).toList();
    return values.contains(null) ? null : values.cast<double>();
  }
}
