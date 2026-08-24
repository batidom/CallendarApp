import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../services/address_service.dart';
import '../services/app_settings.dart';
import 'search_picker_dialog.dart';
import 'settings_section_header.dart';

/// Appearance, language, and (desktop-only) startup behavior — the settings
/// that shape the app as a whole rather than any one feature.
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCategoryGeneral)),
      body: ListView(
        children: [
          SettingsSectionHeader(l10n.sectionAppearance),
          for (final mode in ThemeMode.values)
            RadioListTile<ThemeMode>(
              dense: true,
              title: Text(mode.label(l10n)),
              value: mode,
              groupValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) controller.update((s) => s.copyWith(themeMode: value));
              },
            ),
          const Divider(),
          SettingsSectionHeader(l10n.sectionLanguage),
          RadioListTile<AppLanguage>(
            dense: true,
            title: Text(l10n.languageSystemDefault),
            value: AppLanguage.system,
            groupValue: settings.language,
            onChanged: (value) {
              if (value != null) controller.update((s) => s.copyWith(language: value));
            },
          ),
          RadioListTile<AppLanguage>(
            dense: true,
            title: const Text('English'),
            value: AppLanguage.english,
            groupValue: settings.language,
            onChanged: (value) {
              if (value != null) controller.update((s) => s.copyWith(language: value));
            },
          ),
          RadioListTile<AppLanguage>(
            dense: true,
            title: const Text('Polski'),
            value: AppLanguage.polish,
            groupValue: settings.language,
            onChanged: (value) {
              if (value != null) controller.update((s) => s.copyWith(language: value));
            },
          ),
          const Divider(),
          SettingsSectionHeader(l10n.sectionConfirmations),
          SwitchListTile(
            dense: true,
            title: Text(l10n.confirmBeforeLeavingEventLabel),
            subtitle: Text(l10n.confirmBeforeLeavingEventSubtitle),
            value: settings.confirmBeforeLeavingEvent,
            onChanged: (value) => controller.update((s) => s.copyWith(confirmBeforeLeavingEvent: value)),
          ),
          if (!Platform.isAndroid && !Platform.isIOS) ...[
            const Divider(),
            SettingsSectionHeader(l10n.sectionStartup),
            SwitchListTile(
              dense: true,
              title: Text(l10n.launchAtLogin),
              subtitle: Text(l10n.launchAtLoginSubtitle),
              value: settings.launchAtLoginEnabled,
              onChanged: (value) => controller.update((s) => s.copyWith(launchAtLoginEnabled: value)),
            ),
          ],
          const Divider(),
          SettingsSectionHeader(l10n.sectionHomeAddress),
          ListTile(
            dense: true,
            title: Text(l10n.homeAddressLabel),
            subtitle: Text(settings.homeAddress ?? l10n.weatherCityNotSet),
            trailing: Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () async {
                    final result = await showDialog<AddressResult>(
                      context: context,
                      builder: (_) => SearchPickerDialog<AddressResult>(
                        title: l10n.homeAddressSearchDialogTitle,
                        hintText: l10n.homeAddressSearchHint,
                        noResultsText: l10n.homeAddressSearchNoResults,
                        errorText: l10n.homeAddressSearchError,
                        search: (query) => ref.read(addressServiceProvider).search(
                              query,
                              biasLatitude: settings.weatherLat,
                              biasLongitude: settings.weatherLon,
                            ),
                        labelBuilder: (address) => address.displayName,
                      ),
                    );
                    if (result != null) {
                      controller.update(
                        (s) => s.copyWith(
                          homeAddressLocation: (
                            result.displayName,
                            result.latitude,
                            result.longitude,
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    settings.homeAddress == null ? l10n.homeAddressSet : l10n.homeAddressChange,
                  ),
                ),
                if (settings.homeAddress != null)
                  TextButton(
                    onPressed: () => controller
                        .update((s) => s.copyWith(homeAddressLocation: (null, null, null))),
                    child: Text(l10n.weatherClearCity),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.homeAddressSubtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
