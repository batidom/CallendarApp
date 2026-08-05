import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';

/// Plays the sound configured in [settings] — one of the OS's built-in
/// system sounds, or the user's own audio file for [ReminderSound.custom]
/// (mp3/wav/ogg/etc. via audioplayers).
Future<void> playReminderSound(AppSettings settings) async {
  if (settings.reminderSound != ReminderSound.custom) {
    final systemSound = settings.reminderSound.systemSound;
    if (systemSound != null) await SystemSound.play(systemSound);
    return;
  }

  final path = settings.customSoundPath;
  if (path == null) return;

  // A fresh player per playback, disposed once it's done — this only ever
  // plays a few-second notification clip, not a track needing a persistent
  // player instance.
  final player = AudioPlayer();
  unawaited(player.onPlayerComplete.first.then((_) => player.dispose()).catchError((_) {}));
  try {
    await player.play(DeviceFileSource(path));
  } catch (_) {
    // Missing/moved file, unsupported codec, etc. — nothing to recover here.
    await player.dispose();
  }
}
