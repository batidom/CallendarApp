import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../utils/reminders.dart';

enum _ReminderUnit {
  minutes(1),
  hours(60),
  days(1440);

  const _ReminderUnit(this.minutesMultiplier);
  final int minutesMultiplier;
}

/// The "Reminders" block of the event form: preset chips, any custom values
/// already added, and an "Add custom" chip that prompts for an amount+unit.
/// [EventFormScreen] owns the actual selected/custom minute sets (needed
/// directly when saving) — this widget only owns the transient text
/// controller for its own custom-reminder dialog.
class EventRemindersSection extends StatefulWidget {
  const EventRemindersSection({
    super.key,
    required this.selectedMinutes,
    required this.customOptions,
    required this.onToggle,
    required this.onDeleteCustom,
    required this.onCustomAdded,
  });

  final Set<int> selectedMinutes;
  final Set<int> customOptions;
  final void Function(int minutes, bool selected) onToggle;
  final ValueChanged<int> onDeleteCustom;
  final ValueChanged<int> onCustomAdded;

  @override
  State<EventRemindersSection> createState() => _EventRemindersSectionState();
}

class _EventRemindersSectionState extends State<EventRemindersSection> {
  final _customReminderAmountController = TextEditingController();

  @override
  void dispose() {
    _customReminderAmountController.dispose();
    super.dispose();
  }

  Future<void> _promptCustomReminder(AppLocalizations l10n) async {
    _customReminderAmountController.clear();
    var unit = _ReminderUnit.minutes;

    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.customReminderDialogTitle),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _customReminderAmountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.fieldAmount),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<_ReminderUnit>(
                value: unit,
                items: [
                  DropdownMenuItem(value: _ReminderUnit.minutes, child: Text(l10n.unitMinutes)),
                  DropdownMenuItem(value: _ReminderUnit.hours, child: Text(l10n.unitHours)),
                  DropdownMenuItem(value: _ReminderUnit.days, child: Text(l10n.unitDays)),
                ],
                onChanged: (value) => setDialogState(() => unit = value!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.actionCancel)),
            FilledButton(
              onPressed: () {
                final amount = int.tryParse(_customReminderAmountController.text);
                if (amount == null || amount <= 0) return;
                Navigator.of(context).pop(amount * unit.minutesMultiplier);
              },
              child: Text(l10n.actionAdd),
            ),
          ],
        ),
      ),
    );

    if (minutes == null) return;
    widget.onCustomAdded(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.remindersHeader, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final minutes in reminderPresets)
              FilterChip(
                label: Text(reminderLabel(minutes, l10n)),
                selected: widget.selectedMinutes.contains(minutes),
                onSelected: (selected) => widget.onToggle(minutes, selected),
              ),
            for (final minutes in widget.customOptions)
              FilterChip(
                label: Text(reminderLabel(minutes, l10n)),
                selected: widget.selectedMinutes.contains(minutes),
                onSelected: (selected) => widget.onToggle(minutes, selected),
                onDeleted: () => widget.onDeleteCustom(minutes),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(l10n.actionCustom),
              onPressed: () => _promptCustomReminder(l10n),
            ),
          ],
        ),
      ],
    );
  }
}
