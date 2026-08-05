import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../services/app_settings.dart';

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
        ],
      ),
    );
  }
}
