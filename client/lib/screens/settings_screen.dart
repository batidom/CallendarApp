import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'settings_account_screen.dart';
import 'settings_calendar_screen.dart';
import 'settings_general_screen.dart';
import 'settings_reminders_screen.dart';
import 'settings_voice_input_screen.dart';

/// Top-level settings landing page: a handful of categories, each pushing
/// its own dedicated screen — the same "list of categories, drill into one"
/// pattern most OS settings apps use, rather than one long scrolling page
/// of every option at once.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _CategoryTile(
            icon: Icons.tune,
            title: l10n.settingsCategoryGeneral,
            subtitle: l10n.settingsCategoryGeneralSubtitle,
            builder: (_) => const GeneralSettingsScreen(),
          ),
          _CategoryTile(
            icon: Icons.calendar_month_outlined,
            title: l10n.settingsCategoryCalendar,
            subtitle: l10n.settingsCategoryCalendarSubtitle,
            builder: (_) => const CalendarSettingsScreen(),
          ),
          _CategoryTile(
            icon: Icons.mic_none_outlined,
            title: l10n.settingsCategoryVoiceInput,
            subtitle: l10n.settingsCategoryVoiceInputSubtitle,
            builder: (_) => const VoiceInputSettingsScreen(),
          ),
          _CategoryTile(
            icon: Icons.notifications_outlined,
            title: l10n.settingsCategoryReminders,
            subtitle: l10n.settingsCategoryRemindersSubtitle,
            builder: (_) => const RemindersSettingsScreen(),
          ),
          _CategoryTile(
            icon: Icons.person_outline,
            title: l10n.settingsCategoryAccount,
            subtitle: l10n.settingsCategoryAccountSubtitle,
            builder: (_) => const AccountSettingsScreen(),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: builder)),
    );
  }
}
