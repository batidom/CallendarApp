import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

/// Registers Calendar App to launch on OS login (per the *current* OS user
/// only — launch_at_startup writes to the per-user HKCU Run key on Windows,
/// not the machine-wide HKLM one, so this never affects other Windows
/// accounts on a shared PC). The app always starts hidden in the tray
/// regardless of how it was launched (see AppWindowController.init), so
/// nothing further is needed to make this "start minimized".
class LaunchAtLoginService {
  LaunchAtLoginService._();

  static bool _isSetUp = false;

  static void _ensureSetUp() {
    if (_isSetUp) return;
    launchAtStartup.setup(appName: 'Calendar App', appPath: Platform.resolvedExecutable);
    _isSetUp = true;
  }

  /// Brings the OS registration in line with [enabled]. Called once at
  /// startup (to repair the registration if the app was moved/rebuilt to a
  /// new path since it was last enabled) and again whenever the user flips
  /// the setting.
  static Future<void> reconcile(bool enabled) async {
    _ensureSetUp();
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}
