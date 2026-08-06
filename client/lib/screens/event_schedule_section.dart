import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';

/// The "Day" row (with its "add/remove a specific time" toggle) plus, once a
/// specific time is set, the All Day switch and Start/End time rows.
/// Purely presentational — [EventFormScreen] owns the actual day/time state,
/// since saving needs to read it directly.
class EventScheduleSection extends StatelessWidget {
  const EventScheduleSection({
    super.key,
    required this.hasSpecificTime,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.onPickDay,
    required this.onRemoveSpecificTime,
    required this.onAddSpecificTime,
    required this.onAllDayChanged,
    required this.onPickStartTime,
    required this.onPickEndTime,
  });

  final bool hasSpecificTime;
  final DateTime day;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final VoidCallback onPickDay;
  final VoidCallback onRemoveSpecificTime;
  final VoidCallback onAddSpecificTime;
  final ValueChanged<bool> onAllDayChanged;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndTime;

  Widget _buildTimeRow(
    BuildContext context, {
    required String label,
    required DateTime value,
    required VoidCallback onPickTime,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          OutlinedButton(
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: onPickTime,
            child: Text(DateFormat.jm().format(value)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.fieldDay),
          subtitle: Text(DateFormat.yMMMd().format(hasSpecificTime ? startTime : day)),
          onTap: onPickDay,
          trailing: hasSpecificTime
              ? TextButton(onPressed: onRemoveSpecificTime, child: Text(l10n.actionNoSpecificTime))
              : TextButton(onPressed: onAddSpecificTime, child: Text(l10n.actionAddATime)),
        ),
        if (hasSpecificTime) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.allDay),
            value: isAllDay,
            onChanged: onAllDayChanged,
          ),
          _buildTimeRow(context, label: l10n.labelStart, value: startTime, onPickTime: onPickStartTime),
          _buildTimeRow(context, label: l10n.labelEnd, value: endTime, onPickTime: onPickEndTime),
        ],
      ],
    );
  }
}
