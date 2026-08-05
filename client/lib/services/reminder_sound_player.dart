import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'app_settings.dart';

/// Plays the sound configured in [settings] at [AppSettings.reminderVolume]
/// — one of the bundled built-in sounds, or the user's own audio file for
/// [ReminderSound.custom] (mp3/wav/ogg/etc.), both via audioplayers.
Future<void> playReminderSound(AppSettings settings) async {
  final Source? source = settings.reminderSound == ReminderSound.custom
      ? (settings.customSoundPath == null ? null : DeviceFileSource(settings.customSoundPath!))
      : (settings.reminderSound.assetPath == null ? null : AssetSource(settings.reminderSound.assetPath!));
  if (source == null) return;

  // A fresh player per playback, disposed once it's done — this only ever
  // plays a few-second notification clip, not a track needing a persistent
  // player instance.
  final player = AudioPlayer();
  unawaited(player.onPlayerComplete.first.then((_) => player.dispose()).catchError((_) {}));
  try {
    await player.play(source, volume: settings.reminderVolume);
  } catch (_) {
    // Missing/moved file, unsupported codec, etc. — nothing to recover here.
    await player.dispose();
  }
}
