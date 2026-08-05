import '../l10n/generated/app_localizations.dart';

/// Reminders are stored locally as a comma-separated list of "minutes before
/// start" values (e.g. "0,10,1440") directly on the event row, the same way
/// [Event.rrule] stores its pattern as a single string — this keeps a
/// reminder set an atomic part of the event instead of needing its own sync
/// queue and pending-operation tracking.
List<int> decodeReminderMinutes(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toList();
}

String? encodeReminderMinutes(List<int> minutes) {
  if (minutes.isEmpty) return null;
  final sorted = minutes.toSet().toList()..sort();
  return sorted.join(',');
}

/// Common one-tap presets, ordered as they should appear in the UI.
const reminderPresets = <int>[0, 10, 30, 60, 1440];

String reminderLabel(int minutesBefore, AppLocalizations l10n) {
  if (minutesBefore == 0) return l10n.reminderAtStartTime;
  if (minutesBefore < 60) return l10n.reminderMinutesBefore(minutesBefore);
  if (minutesBefore % 1440 == 0) {
    return l10n.reminderDaysBefore(minutesBefore ~/ 1440);
  }
  if (minutesBefore % 60 == 0) {
    return l10n.reminderHoursBefore(minutesBefore ~/ 60);
  }
  return l10n.reminderMinutesBefore(minutesBefore);
}
