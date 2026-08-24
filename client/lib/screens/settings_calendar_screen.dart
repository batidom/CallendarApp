import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../services/app_settings.dart';
import '../services/weather_service.dart';
import 'search_picker_dialog.dart';
import 'settings_section_header.dart';

class CalendarSettingsScreen extends ConsumerWidget {
  const CalendarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCategoryCalendar)),
      body: ListView(
        children: [
          for (final day in WeekStartDay.values)
            RadioListTile<WeekStartDay>(
              dense: true,
              title: Text(l10n.weekStartsOn(day.label(l10n))),
              value: day,
              groupValue: settings.weekStartDay,
              onChanged: (value) {
                if (value != null) controller.update((s) => s.copyWith(weekStartDay: value));
              },
            ),
          const Divider(),
          SettingsSectionHeader(l10n.sectionWeather),
          ListTile(
            dense: true,
            title: Text(l10n.weatherCityLabel),
            subtitle: Text(settings.weatherCity ?? l10n.weatherCityNotSet),
            trailing: Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () async {
                    final result = await showDialog<WeatherCityResult>(
                      context: context,
                      builder: (_) => SearchPickerDialog<WeatherCityResult>(
                        title: l10n.weatherSearchDialogTitle,
                        hintText: l10n.weatherSearchHint,
                        noResultsText: l10n.weatherSearchNoResults,
                        errorText: l10n.weatherSearchError,
                        search: ref.read(weatherServiceProvider).searchCity,
                        labelBuilder: (city) => city.displayName,
                      ),
                    );
                    if (result != null) {
                      controller.update(
                        (s) => s.copyWith(
                          weatherLocation: (
                            result.displayName,
                            result.latitude,
                            result.longitude,
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    settings.weatherCity == null ? l10n.weatherSetCity : l10n.weatherChangeCity,
                  ),
                ),
                if (settings.weatherCity != null)
                  TextButton(
                    onPressed: () =>
                        controller.update((s) => s.copyWith(weatherLocation: (null, null, null))),
                    child: Text(l10n.weatherClearCity),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.weatherCitySubtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
