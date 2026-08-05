import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart' as p;

import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../services/app_settings.dart';
import '../services/notification_popup.dart';
import '../services/reminder_sound_player.dart';
import 'settings_section_header.dart';

/// How a due reminder is announced: which channel (in-app popup vs. Windows
/// notification), what sound plays, and a way to try it out without waiting
/// for a real reminder to fire.
class RemindersSettingsScreen extends ConsumerWidget {
  const RemindersSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCategoryReminders)),
      body: ListView(
        children: [
          SwitchListTile(
            dense: true,
            title: Text(l10n.enableReminderNotifications),
            value: settings.notificationsEnabled,
            onChanged: (value) => controller.update((s) => s.copyWith(notificationsEnabled: value)),
          ),
          AbsorbPointer(
            absorbing: !settings.notificationsEnabled,
            child: Opacity(
              opacity: settings.notificationsEnabled ? 1 : 0.4,
              child: Column(
                children: [
                  RadioListTile<NotificationChannel>(
                    dense: true,
                    title: Text(l10n.inAppPopup),
                    subtitle: Text(l10n.inAppPopupSubtitle),
                    value: NotificationChannel.inApp,
                    groupValue: settings.notificationChannel,
                    onChanged: (value) {
                      if (value != null) controller.update((s) => s.copyWith(notificationChannel: value));
                    },
                  ),
                  RadioListTile<NotificationChannel>(
                    dense: true,
                    title: Text(l10n.windowsNotification),
                    subtitle: Text(l10n.windowsNotificationSubtitle),
                    value: NotificationChannel.system,
                    groupValue: settings.notificationChannel,
                    onChanged: (value) {
                      if (value != null) controller.update((s) => s.copyWith(notificationChannel: value));
                    },
                  ),
                  if (settings.notificationChannel == NotificationChannel.inApp) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Align(alignment: Alignment.centerLeft, child: Text(l10n.popupPosition)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final corner in NotificationCorner.values)
                            ChoiceChip(
                              label: Text(corner.label(l10n)),
                              selected: settings.popupCorner == corner,
                              onSelected: (_) => controller.update((s) => s.copyWith(popupCorner: corner)),
                            ),
                        ],
                      ),
                    ),
                    ListTile(
                      dense: true,
                      title: Text(l10n.popupDuration),
                      subtitle: Slider(
                        min: 3,
                        max: 30,
                        divisions: 27,
                        label: '${settings.popupDurationSeconds}s',
                        value: settings.popupDurationSeconds.toDouble(),
                        onChanged: (value) =>
                            controller.update((s) => s.copyWith(popupDurationSeconds: value.round())),
                      ),
                      trailing: Text('${settings.popupDurationSeconds}s'),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Align(alignment: Alignment.centerLeft, child: Text(l10n.soundSectionLabel)),
                  ),
                  for (final sound in ReminderSound.values)
                    RadioListTile<ReminderSound>(
                      dense: true,
                      title: Text(sound.label(l10n)),
                      subtitle: sound == ReminderSound.custom ? Text(l10n.soundFileFormatsHint) : null,
                      value: sound,
                      groupValue: settings.reminderSound,
                      onChanged: (value) => _onSoundSelected(l10n, controller, settings, value),
                    ),
                  if (settings.reminderSound == ReminderSound.custom)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              settings.customSoundPath == null
                                  ? l10n.noFileChosen
                                  : p.basename(settings.customSoundPath!),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _pickCustomSoundFile(l10n, controller, settings),
                            child: Text(
                              settings.customSoundPath == null ? l10n.actionChooseFile : l10n.actionChange,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.tooltipPreview,
                            icon: const Icon(Icons.play_arrow, size: 20),
                            onPressed:
                                settings.customSoundPath == null ? null : () => playReminderSound(settings),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                      label: Text(l10n.actionSendTestReminder),
                      onPressed: () => _sendTestReminder(l10n, settings),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          SettingsSectionHeader(l10n.sectionOtherNotifications),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              l10n.otherNotificationsSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          SwitchListTile(
            dense: true,
            title: Text(l10n.notificationSoundEnabledLabel),
            value: settings.notificationSoundEnabled,
            onChanged: (value) => controller.update((s) => s.copyWith(notificationSoundEnabled: value)),
          ),
        ],
      ),
    );
  }

  /// Picking a file requires an unsupported-format-safe audio filter and, on
  /// desktop, always returns a real filesystem [PlatformFile.path].
  Future<String?> _pickAudioFile(AppLocalizations l10n) async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      dialogTitle: l10n.dialogChooseReminderSound,
    );
    return result?.files.single.path;
  }

  Future<void> _onSoundSelected(
    AppLocalizations l10n,
    SettingsController controller,
    AppSettings settings,
    ReminderSound? value,
  ) async {
    if (value == null) return;

    var updated = settings.copyWith(reminderSound: value);
    if (value == ReminderSound.custom && settings.customSoundPath == null) {
      final path = await _pickAudioFile(l10n);
      // User backed out of the file dialog without choosing anything — stay
      // on whatever sound was selected before, rather than switching to a
      // "custom" sound with no file behind it.
      if (path == null) return;
      updated = updated.copyWith(customSoundPath: path);
    }

    await controller.update((_) => updated);
    await playReminderSound(updated);
  }

  Future<void> _pickCustomSoundFile(
    AppLocalizations l10n,
    SettingsController controller,
    AppSettings settings,
  ) async {
    final path = await _pickAudioFile(l10n);
    if (path == null) return;
    final updated = settings.copyWith(customSoundPath: path);
    await controller.update((_) => updated);
    await playReminderSound(updated);
  }

  Future<void> _sendTestReminder(AppLocalizations l10n, AppSettings settings) async {
    await playReminderSound(settings);

    if (settings.notificationChannel == NotificationChannel.system) {
      await LocalNotification(title: l10n.testReminderTitle, body: l10n.testReminderBody).show();
    } else {
      await spawnReminderPopup(
        title: l10n.testReminderTitle,
        message: l10n.testReminderBody,
        corner: settings.popupCorner,
        durationSeconds: settings.popupDurationSeconds,
      );
    }
  }
}
