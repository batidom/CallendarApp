import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'app_settings.dart';

/// Spawns a small independent, always-on-top popup window for a fired
/// reminder — a genuinely separate OS window (its own Flutter engine), not
/// just a widget inside the main app, so it's visible even while the main
/// calendar window is hidden in the tray. See main.dart for the entrypoint
/// that receives this payload and screens/notification_popup_screen.dart for
/// the window's own content/self-positioning. [corner]/[durationSeconds] come
/// from the user's settings, passed through as plain JSON since the spawned
/// window runs in its own isolate/engine with no shared memory.
Future<void> spawnReminderPopup({
  required String title,
  required String message,
  required NotificationCorner corner,
  required int durationSeconds,
}) async {
  await WindowController.create(WindowConfiguration(
    arguments: jsonEncode({
      'title': title,
      'message': message,
      'corner': corner.name,
      'durationSeconds': durationSeconds,
    }),
  ));
}
