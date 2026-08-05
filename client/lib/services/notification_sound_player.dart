import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'app_settings.dart';

/// Plays the bundled notification chime at [AppSettings.notificationVolume].
/// Deliberately not [SystemSound.play] (used by the calendar reminder
/// sounds) — the OS system-sound API has no volume parameter, so a
/// user-controllable volume needs a real bundled asset played through
/// audioplayers instead.
Future<void> playNotificationSound(AppSettings settings) async {
  if (settings.notificationVolume <= 0) return;

  final player = AudioPlayer();
  unawaited(player.onPlayerComplete.first.then((_) => player.dispose()).catchError((_) {}));
  try {
    await player.play(AssetSource('sounds/notification.wav'), volume: settings.notificationVolume);
  } catch (_) {
    // Playback device unavailable, etc. — nothing to recover here.
    await player.dispose();
  }
}
