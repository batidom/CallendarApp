import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../utils/recurrence.dart';

/// The "Repeat" block of the event form: frequency, interval, weekday
/// picker (weekly only), monthly-by-day-vs-weekday choice, and the end
/// condition (never / on date / after N occurrences). Purely presentational
/// — [EventFormScreen] owns all of the underlying repeat state and passes it
/// down, since saving needs to read it directly when building the rrule.
class EventRepeatSection extends StatelessWidget {
  const EventRepeatSection({
    super.key,
    required this.frequency,
    required this.interval,
    required this.weekdays,
    required this.monthlyByWeekday,
    required this.endType,
    required this.until,
    required this.count,
    required this.startTime,
    required this.isEditingSeries,
    required this.onFrequencyChanged,
    required this.onIntervalChanged,
    required this.onWeekdayToggled,
    required this.onMonthlyByWeekdayChanged,
    required this.onEndTypeChanged,
    required this.onCountChanged,
  });

  final RecurrenceFrequency? frequency;
  final int interval;
  final Set<int> weekdays;
  // Monthly-only: false = "same day-of-month" (e.g. the 15th), true = "the
  // Nth weekday" (e.g. the 3rd Thursday) — always derived from [startTime]
  // rather than manually configurable to an arbitrary weekday.
  final bool monthlyByWeekday;
  final RecurrenceEndType endType;
  final DateTime? until;
  final int count;
  // Used to compute the weekly default weekday and the monthly ordinal/
  // weekday labels — this section never edits the event's own start time.
  final DateTime startTime;
  // Whether this is editing an existing recurring series (vs. setting up a
  // brand-new repeat) — shows a footer notice that changes apply to the
  // whole series.
  final bool isEditingSeries;

  final ValueChanged<RecurrenceFrequency?> onFrequencyChanged;
  final ValueChanged<int> onIntervalChanged;
  final void Function(int weekday, bool selected) onWeekdayToggled;
  final ValueChanged<bool> onMonthlyByWeekdayChanged;
  // Handles both the simple never/afterCount selections and onDate (which
  // also needs to prompt for the actual date) — see EventFormScreen._save's
  // sibling _pickRepeatUntil for why this stays async.
  final Future<void> Function(RecurrenceEndType type) onEndTypeChanged;
  final ValueChanged<int> onCountChanged;

  static const _weekdayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  String _intervalUnitLabel(RecurrenceFrequency freq, AppLocalizations l10n) {
    switch (freq) {
      case RecurrenceFrequency.daily:
        return l10n.repeatUnitDay(interval);
      case RecurrenceFrequency.weekly:
        return l10n.repeatUnitWeek(interval);
      case RecurrenceFrequency.monthly:
        return l10n.repeatUnitMonth(interval);
      case RecurrenceFrequency.yearly:
        return l10n.repeatUnitYear(interval);
    }
  }

  String _fullWeekdayLabel(int weekday, AppLocalizations l10n) => switch (weekday) {
        1 => l10n.weekdayMonday,
        2 => l10n.weekdayTuesday,
        3 => l10n.weekdayWednesday,
        4 => l10n.weekdayThursday,
        5 => l10n.weekdayFriday,
        6 => l10n.weekdaySaturday,
        _ => l10n.weekdaySunday,
      };

  String _ordinalLabel(int ordinal, AppLocalizations l10n) => switch (ordinal) {
        1 => l10n.ordinalFirst,
        2 => l10n.ordinalSecond,
        3 => l10n.ordinalThird,
        4 => l10n.ordinalFourth,
        _ => l10n.ordinalLast,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final freq = frequency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<RecurrenceFrequency?>(
          initialValue: freq,
          decoration: InputDecoration(labelText: l10n.fieldRepeat),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.repeatNone)),
            DropdownMenuItem(value: RecurrenceFrequency.daily, child: Text(l10n.repeatDaily)),
            DropdownMenuItem(value: RecurrenceFrequency.weekly, child: Text(l10n.repeatWeekly)),
            DropdownMenuItem(value: RecurrenceFrequency.monthly, child: Text(l10n.repeatMonthly)),
            DropdownMenuItem(value: RecurrenceFrequency.yearly, child: Text(l10n.repeatYearly)),
          ],
          onChanged: onFrequencyChanged,
        ),
        if (freq != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.everyWord),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: TextFormField(
                  initialValue: '$interval',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) onIntervalChanged(parsed);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(_intervalUnitLabel(freq, l10n)),
            ],
          ),
          if (freq == RecurrenceFrequency.weekly) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = weekdays.contains(day);
                return FilterChip(
                  label: Text(_weekdayLabels[i]),
                  selected: selected,
                  onSelected: (value) => onWeekdayToggled(day, value),
                );
              }),
            ),
          ],
          if (freq == RecurrenceFrequency.monthly) ...[
            const SizedBox(height: 4),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.repeatMonthlyByDay(startTime.day)),
              value: false,
              groupValue: monthlyByWeekday,
              onChanged: (value) => onMonthlyByWeekdayChanged(value!),
            ),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.repeatMonthlyByWeekday(
                _ordinalLabel(monthlyWeekdayOrdinal(startTime), l10n),
                _fullWeekdayLabel(startTime.weekday, l10n),
              )),
              value: true,
              groupValue: monthlyByWeekday,
              onChanged: (value) => onMonthlyByWeekdayChanged(value!),
            ),
          ],
          const SizedBox(height: 12),
          Text(l10n.endsWord, style: const TextStyle(fontWeight: FontWeight.w600)),
          RadioListTile<RecurrenceEndType>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.repeatEndNever),
            value: RecurrenceEndType.never,
            groupValue: endType,
            onChanged: (value) => onEndTypeChanged(value!),
          ),
          RadioListTile<RecurrenceEndType>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(until == null
                ? l10n.repeatEndOnDate
                : l10n.repeatEndOnDateWithValue(DateFormat.yMMMd().format(until!))),
            value: RecurrenceEndType.onDate,
            groupValue: endType,
            onChanged: (value) => onEndTypeChanged(value!),
          ),
          RadioListTile<RecurrenceEndType>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.repeatEndAfterCount(count)),
            value: RecurrenceEndType.afterCount,
            groupValue: endType,
            onChanged: (value) => onEndTypeChanged(value!),
          ),
          if (endType == RecurrenceEndType.afterCount)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Row(
                children: [
                  Text(l10n.occurrencesLabel),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: TextFormField(
                      initialValue: '$count',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) onCountChanged(parsed);
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (isEditingSeries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.seriesChangeNotice,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
        ],
      ],
    );
  }
}
