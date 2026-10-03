import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Carries bClock's saved data over from its old folder.
///
/// On Windows the data folder is `%APPDATA%\<CompanyName>\<ProductName>`,
/// taken from the exe's version info. Up to 1.2.1 those were the Flutter
/// template's defaults, so the data sat in `com.example\bclock`; from 1.2.2
/// they are `Yair Lahav\bClock`. Without this, an upgrade would start with
/// no settings, alarms, timer or world clocks.
///
/// Call before anything reads SharedPreferences.
Future<void> migrateLegacyData() async {
  if (!Platform.isWindows) return;
  final appData = Platform.environment['APPDATA'];
  if (appData == null) return;
  try {
    await copyLegacyPrefs(
      oldDir: Directory('$appData\\com.example\\bclock'),
      newDir: await getApplicationSupportDirectory(),
    );
  } catch (_) {
    // Start fresh rather than fail to start.
  }
}

/// Copies the settings file from [oldDir] to [newDir] unless [newDir]
/// already has one. Copies rather than moves, so an older bClock still
/// finds its data. Returns whether it copied.
@visibleForTesting
Future<bool> copyLegacyPrefs({
  required Directory oldDir,
  required Directory newDir,
}) async {
  const name = 'shared_preferences.json';
  final from = File('${oldDir.path}${Platform.pathSeparator}$name');
  final to = File('${newDir.path}${Platform.pathSeparator}$name');
  if (await to.exists() || !await from.exists()) return false;
  await newDir.create(recursive: true);
  await from.copy(to.path);
  return true;
}
