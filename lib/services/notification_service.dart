import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_window.dart';

/// Windows toasts for a ringing alarm or timer, with action buttons.
///
/// The plugin registers bClock's app id ([appUserModelId]) under HKCU on
/// first use, so toasts work without an MSIX identity or a special Start
/// menu shortcut. The uninstaller removes those keys.
///
/// Tests replace [instance] with a fake, so they never show real toasts.
class NotificationService {
  @visibleForTesting
  NotificationService();

  static NotificationService instance = NotificationService();

  /// Keep in step with the `[Registry]` entries in installer/bclock.iss.
  static const String appUserModelId = 'bClock.bClock';
  static const String _activatorGuid = '2ba2c34c-4786-42b2-aab2-988855266b56';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _onAction = <int, ValueChanged<String>>{};
  bool _ready = false;

  Future<void> init() async {
    if (!Platform.isWindows) return;
    final icon = [
      File(Platform.resolvedExecutable).parent.path,
      'data',
      'flutter_assets',
      'assets',
      'icons',
      'app_icon.png',
    ].join(Platform.pathSeparator);
    try {
      _ready = await _plugin.initialize(
            settings: InitializationSettings(
              windows: WindowsInitializationSettings(
                appName: 'bClock',
                appUserModelId: appUserModelId,
                guid: _activatorGuid,
                iconPath: File(icon).existsSync() ? icon : null,
              ),
            ),
            onDidReceiveNotificationResponse: (r) =>
                handleResponse(r.id, r.actionId),
          ) ??
          false;
    } catch (_) {
      // No toasts then; the in-app popup still rings.
      _ready = false;
    }
  }

  /// Shows a toast that stays until answered, with one button per entry of
  /// [actions] (key → label). Pressing one calls [onAction] with its key;
  /// clicking the toast's body only brings bClock to the front.
  Future<void> show(
    int id, {
    required String title,
    required String body,
    required Map<String, String> actions,
    required ValueChanged<String> onAction,
  }) async {
    _onAction[id] = onAction;
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          windows: WindowsNotificationDetails(
            actions: [
              for (final MapEntry(:key, :value) in actions.entries)
                WindowsAction(content: value, arguments: key),
            ],
            // Stays on screen until answered; bClock plays its own sound.
            scenario: WindowsNotificationScenario.reminder,
            audio: WindowsNotificationAudio.silent(),
          ),
        ),
      );
    } catch (_) {
      // The popup still rings.
    }
  }

  /// Withdraws the toast, e.g. once the popup was answered instead.
  Future<void> cancel(int id) async {
    _onAction.remove(id);
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  /// A press on toast [id]: [actionId] is the button's key, or empty for
  /// the toast body.
  @visibleForTesting
  void handleResponse(int? id, String? actionId) {
    unawaited(AppWindow.raise());
    if (id == null || actionId == null || actionId.isEmpty) return;
    _onAction.remove(id)?.call(actionId);
  }
}
