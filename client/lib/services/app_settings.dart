import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/generated/app_localizations.dart';

/// Which screen corner a reminder popup window appears in.
enum NotificationCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Whether a fired reminder shows as our own popup window or a native
/// Windows/macOS/Linux notification.
enum NotificationChannel { inApp, system }

/// The sound played the moment a reminder fires. [custom] plays whatever
/// file the user picked ([AppSettings.customSoundPath]) via audioplayers;
/// the rest are the OS's built-in system sounds.
enum ReminderSound { none, click, alert, custom }

/// Which weekday the calendar grid's first column shows.
enum WeekStartDay { monday, sunday }

/// The app's display language. [system] follows the OS locale (falling back
/// to English if the OS locale isn't one of [AppLocalizations.supportedLocales]).
enum AppLanguage { system, english, polish }

extension AppLanguageLocale on AppLanguage {
  Locale? get locale => switch (this) {
        AppLanguage.system => null,
        AppLanguage.english => const Locale('en'),
        AppLanguage.polish => const Locale('pl'),
      };
}

extension WeekStartDayLabel on WeekStartDay {
  String label(AppLocalizations l10n) => switch (this) {
        WeekStartDay.monday => l10n.weekdayMonday,
        WeekStartDay.sunday => l10n.weekdaySunday,
      };
}

extension ReminderSoundLabel on ReminderSound {
  String label(AppLocalizations l10n) => switch (this) {
        ReminderSound.none => l10n.soundNone,
        ReminderSound.click => l10n.soundClick,
        ReminderSound.alert => l10n.soundAlert,
        ReminderSound.custom => l10n.soundCustom,
      };

  // Bundled asset path for the built-in sounds, played via audioplayers
  // rather than SystemSound.play() so [AppSettings.reminderVolume] actually
  // applies — the OS system-sound API has no volume parameter.
  String? get assetPath => switch (this) {
        ReminderSound.none => null,
        ReminderSound.click => 'sounds/click.wav',
        ReminderSound.alert => 'sounds/alert.wav',
        ReminderSound.custom => null,
      };
}

extension NotificationCornerLabel on NotificationCorner {
  String label(AppLocalizations l10n) => switch (this) {
        NotificationCorner.topLeft => l10n.cornerTopLeft,
        NotificationCorner.topRight => l10n.cornerTopRight,
        NotificationCorner.bottomLeft => l10n.cornerBottomLeft,
        NotificationCorner.bottomRight => l10n.cornerBottomRight,
      };
}

extension ThemeModeLabel on ThemeMode {
  String label(AppLocalizations l10n) => switch (this) {
        ThemeMode.system => l10n.themeSystem,
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
      };
}

/// User-configurable app preferences, persisted locally (they're a per-device
/// UI preference, not something that needs to sync across devices).
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.notificationChannel = NotificationChannel.inApp,
    this.popupCorner = NotificationCorner.bottomRight,
    this.popupDurationSeconds = 8,
    this.reminderSound = ReminderSound.alert,
    this.customSoundPath,
    this.reminderVolume = 0.7,
    this.weekStartDay = WeekStartDay.monday,
    this.language = AppLanguage.system,
    this.microphoneDeviceId,
    this.microphoneDeviceLabel,
    this.launchAtLoginEnabled = false,
    this.confirmBeforeLeavingEvent = true,
    this.notificationSoundEnabled = true,
    this.notificationVolume = 0.7,
  });

  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final NotificationChannel notificationChannel;
  final NotificationCorner popupCorner;
  final int popupDurationSeconds;
  final ReminderSound reminderSound;
  // Absolute path to the user's chosen audio file, used when reminderSound
  // is ReminderSound.custom. Kept even when a different sound is selected,
  // so switching back to "Custom sound file" doesn't forget the choice.
  final String? customSoundPath;
  // 0.0-1.0, applied to whichever reminder sound is selected (built-in or
  // custom file) via audioplayers.
  final double reminderVolume;
  final WeekStartDay weekStartDay;
  final AppLanguage language;
  // Platform device id for the assistant's voice-command mic. Null means
  // "use the OS default recording device" — worth pinning explicitly on
  // machines with several input devices (headset, webcam, etc.), since the
  // OS default silently picking the wrong one records near-silence rather
  // than erroring, which just looks like a broken transcription.
  final String? microphoneDeviceId;
  final String? microphoneDeviceLabel;
  // Opt-in: registers the app to launch (minimized to tray) on OS login.
  // Off by default — modifying the user's system startup list is exactly
  // the kind of side effect that shouldn't happen without explicit consent.
  final bool launchAtLoginEnabled;
  // Whether leaving a shared event asks for confirmation first — the
  // "Don't ask me again" checkbox on that dialog flips this off; the
  // General settings screen offers a switch to turn it back on since
  // there's otherwise no way to undo a "don't ask again" choice.
  final bool confirmBeforeLeavingEvent;
  // Separate from [notificationsEnabled]/[reminderSound] above, which are
  // about calendar reminders — this covers the *other* notification
  // system entirely: the bell dropdown's server-side notifications (friend
  // requests/acceptances, event invites, someone changing a shared event,
  // etc., see calendar_screen.dart's notifications poll). One shared
  // on/off rather than per-type, matching how [notificationsEnabled]
  // already works.
  final bool notificationSoundEnabled;
  // 0.0-1.0, applied to the bundled notification chime via audioplayers.
  // Only affects the "other notifications" sound above — reminders use the
  // OS's own system sounds (or a custom file played at full volume), which
  // don't offer a volume knob to hook into.
  final double notificationVolume;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    NotificationChannel? notificationChannel,
    NotificationCorner? popupCorner,
    int? popupDurationSeconds,
    ReminderSound? reminderSound,
    String? customSoundPath,
    double? reminderVolume,
    WeekStartDay? weekStartDay,
    AppLanguage? language,
    (String?, String?)? microphoneDevice,
    bool? launchAtLoginEnabled,
    bool? confirmBeforeLeavingEvent,
    bool? notificationSoundEnabled,
    double? notificationVolume,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationChannel: notificationChannel ?? this.notificationChannel,
      popupCorner: popupCorner ?? this.popupCorner,
      popupDurationSeconds: popupDurationSeconds ?? this.popupDurationSeconds,
      reminderSound: reminderSound ?? this.reminderSound,
      customSoundPath: customSoundPath ?? this.customSoundPath,
      reminderVolume: reminderVolume ?? this.reminderVolume,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      language: language ?? this.language,
      microphoneDeviceId: microphoneDevice != null ? microphoneDevice.$1 : microphoneDeviceId,
      microphoneDeviceLabel: microphoneDevice != null ? microphoneDevice.$2 : microphoneDeviceLabel,
      launchAtLoginEnabled: launchAtLoginEnabled ?? this.launchAtLoginEnabled,
      confirmBeforeLeavingEvent: confirmBeforeLeavingEvent ?? this.confirmBeforeLeavingEvent,
      notificationSoundEnabled: notificationSoundEnabled ?? this.notificationSoundEnabled,
      notificationVolume: notificationVolume ?? this.notificationVolume,
    );
  }
}

/// Reads/writes [AppSettings] to local prefs, one key per field so a future
/// new setting doesn't require migrating old stored data.
class SettingsRepository {
  static const _themeModeKey = 'settings_theme_mode';
  static const _notificationsEnabledKey = 'settings_notifications_enabled';
  static const _notificationChannelKey = 'settings_notification_channel';
  static const _popupCornerKey = 'settings_popup_corner';
  static const _popupDurationSecondsKey = 'settings_popup_duration_seconds';
  static const _reminderSoundKey = 'settings_reminder_sound';
  static const _customSoundPathKey = 'settings_custom_sound_path';
  static const _reminderVolumeKey = 'settings_reminder_volume';
  static const _weekStartDayKey = 'settings_week_start_day';
  static const _languageKey = 'settings_language';
  static const _microphoneDeviceIdKey = 'settings_microphone_device_id';
  static const _microphoneDeviceLabelKey = 'settings_microphone_device_label';
  static const _launchAtLoginEnabledKey = 'settings_launch_at_login_enabled';
  static const _confirmBeforeLeavingEventKey = 'settings_confirm_before_leaving_event';
  static const _notificationSoundEnabledKey = 'settings_notification_sound_enabled';
  static const _notificationVolumeKey = 'settings_notification_volume';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = AppSettings();
    return AppSettings(
      themeMode: _enumFromName(ThemeMode.values, prefs.getString(_themeModeKey), defaults.themeMode),
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ?? defaults.notificationsEnabled,
      notificationChannel: _enumFromName(
        NotificationChannel.values,
        prefs.getString(_notificationChannelKey),
        defaults.notificationChannel,
      ),
      popupCorner:
          _enumFromName(NotificationCorner.values, prefs.getString(_popupCornerKey), defaults.popupCorner),
      popupDurationSeconds: prefs.getInt(_popupDurationSecondsKey) ?? defaults.popupDurationSeconds,
      reminderSound:
          _enumFromName(ReminderSound.values, prefs.getString(_reminderSoundKey), defaults.reminderSound),
      customSoundPath: prefs.getString(_customSoundPathKey),
      reminderVolume: prefs.getDouble(_reminderVolumeKey) ?? defaults.reminderVolume,
      weekStartDay:
          _enumFromName(WeekStartDay.values, prefs.getString(_weekStartDayKey), defaults.weekStartDay),
      language: _enumFromName(AppLanguage.values, prefs.getString(_languageKey), defaults.language),
      microphoneDeviceId: prefs.getString(_microphoneDeviceIdKey),
      microphoneDeviceLabel: prefs.getString(_microphoneDeviceLabelKey),
      launchAtLoginEnabled: prefs.getBool(_launchAtLoginEnabledKey) ?? defaults.launchAtLoginEnabled,
      confirmBeforeLeavingEvent:
          prefs.getBool(_confirmBeforeLeavingEventKey) ?? defaults.confirmBeforeLeavingEvent,
      notificationSoundEnabled:
          prefs.getBool(_notificationSoundEnabledKey) ?? defaults.notificationSoundEnabled,
      notificationVolume: prefs.getDouble(_notificationVolumeKey) ?? defaults.notificationVolume,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, settings.themeMode.name);
    await prefs.setBool(_notificationsEnabledKey, settings.notificationsEnabled);
    await prefs.setString(_notificationChannelKey, settings.notificationChannel.name);
    await prefs.setString(_popupCornerKey, settings.popupCorner.name);
    await prefs.setInt(_popupDurationSecondsKey, settings.popupDurationSeconds);
    await prefs.setString(_reminderSoundKey, settings.reminderSound.name);
    if (settings.customSoundPath != null) {
      await prefs.setString(_customSoundPathKey, settings.customSoundPath!);
    } else {
      await prefs.remove(_customSoundPathKey);
    }
    await prefs.setDouble(_reminderVolumeKey, settings.reminderVolume);
    await prefs.setString(_weekStartDayKey, settings.weekStartDay.name);
    await prefs.setString(_languageKey, settings.language.name);
    if (settings.microphoneDeviceId != null) {
      await prefs.setString(_microphoneDeviceIdKey, settings.microphoneDeviceId!);
      await prefs.setString(_microphoneDeviceLabelKey, settings.microphoneDeviceLabel ?? '');
    } else {
      await prefs.remove(_microphoneDeviceIdKey);
      await prefs.remove(_microphoneDeviceLabelKey);
    }
    await prefs.setBool(_launchAtLoginEnabledKey, settings.launchAtLoginEnabled);
    await prefs.setBool(_confirmBeforeLeavingEventKey, settings.confirmBeforeLeavingEvent);
    await prefs.setBool(_notificationSoundEnabledKey, settings.notificationSoundEnabled);
    await prefs.setDouble(_notificationVolumeKey, settings.notificationVolume);
  }

  static T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

/// Loads settings once at startup, then applies+persists incremental
/// changes from the settings screen. Other providers (e.g. the reminder
/// engine) hold onto this notifier and read `.state` at the moment they need
/// the current value, rather than watching it, so a settings change doesn't
/// require them to be rebuilt.
class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._repository) : super(const AppSettings()) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    state = await _repository.load();
  }

  Future<void> update(AppSettings Function(AppSettings current) updater) async {
    state = updater(state);
    await _repository.save(state);
  }
}
