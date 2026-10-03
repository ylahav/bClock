import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Whether bClock is running as an MSIX package (the Microsoft Store
/// build) rather than from a plain folder (the setup.exe install, or a dev
/// build).
///
/// It matters for anything that names the executable: a packaged app's
/// files live in a protected, versioned folder, so Windows has to start it
/// through its app execution alias instead.
final bool isPackaged = _detectPackage();

/// The alias declared as `execution_alias` in pubspec.yaml's msix_config.
const String executionAlias = 'bclock.exe';

/// Where Windows puts a packaged app's execution alias for this user.
String get executionAliasPath =>
    '${Platform.environment['LOCALAPPDATA']}\\Microsoft\\WindowsApps\\$executionAlias';

// kernel32's GetCurrentPackageFullName reports this when the process has no
// package identity.
const int _appModelErrorNoPackage = 15700;

bool _detectPackage() {
  if (!Platform.isWindows) return false;
  try {
    final getName = DynamicLibrary.open('kernel32.dll').lookupFunction<
        Int32 Function(Pointer<Uint32>, Pointer<Uint16>),
        int Function(Pointer<Uint32>, Pointer<Uint16>)>(
      'GetCurrentPackageFullName',
    );
    final length = calloc<Uint32>();
    try {
      // With no buffer it only answers whether there is a package.
      return getName(length, nullptr) != _appModelErrorNoPackage;
    } finally {
      calloc.free(length);
    }
  } catch (_) {
    return false;
  }
}
