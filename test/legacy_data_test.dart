import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bclock/services/legacy_data.dart';

void main() {
  late Directory root;
  late Directory oldDir;
  late Directory newDir;
  File prefs(Directory d) =>
      File('${d.path}${Platform.pathSeparator}shared_preferences.json');

  setUp(() {
    root = Directory.systemTemp.createTempSync('bclock_legacy_');
    oldDir = Directory('${root.path}${Platform.pathSeparator}old')
      ..createSync();
    // The new folder does not exist yet on a first run after upgrading.
    newDir = Directory('${root.path}${Platform.pathSeparator}new');
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('an upgrade carries the saved data over, and keeps the original',
      () async {
    prefs(oldDir).writeAsStringSync('{"flutter.alarms":"[]"}');

    expect(await copyLegacyPrefs(oldDir: oldDir, newDir: newDir), isTrue);

    expect(prefs(newDir).readAsStringSync(), '{"flutter.alarms":"[]"}');
    expect(prefs(oldDir).existsSync(), isTrue);
  });

  test('data already in the new folder is never overwritten', () async {
    prefs(oldDir).writeAsStringSync('old');
    newDir.createSync();
    prefs(newDir).writeAsStringSync('new');

    expect(await copyLegacyPrefs(oldDir: oldDir, newDir: newDir), isFalse);

    expect(prefs(newDir).readAsStringSync(), 'new');
  });

  test('a fresh install, with nothing to carry over, does nothing', () async {
    expect(await copyLegacyPrefs(oldDir: oldDir, newDir: newDir), isFalse);

    expect(newDir.existsSync(), isFalse);
  });
}
