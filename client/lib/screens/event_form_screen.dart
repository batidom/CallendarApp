import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/local/app_database.dart';
import '../data/remote/api_exception.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../utils/recurrence.dart';
import '../utils/reminders.dart';
import 'event_attachments_section.dart';
import 'event_invite_section.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.existingEvent, this.initialDay, this.occurrenceStart});

  final Event? existingEvent;
  final DateTime? initialDay;

  /// Which specific occurrence of a recurring [existingEvent] was tapped —
  /// distinct from the master's own stored startTime, which only anchors
  /// the very first occurrence. Required to know what "this event only"
  /// means when editing/deleting one instance of a series.
  final DateTime? occurrenceStart;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

enum _ReminderUnit {
  minutes(1),
  hours(60),
  days(1440);

  const _ReminderUnit(this.minutesMultiplier);
  final int minutesMultiplier;
}

/// How much of a recurring series an edit/delete should apply to.
enum _RecurringEditScope { thisEvent, allEvents }

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late DateTime _startTime;
  late DateTime _endTime;
  // The day picker used only while scheduled-but-loose (see below) — once a
  // specific time is set, the Start/End pickers already encode the day.
  late DateTime _day;
  bool _isAllDay = false;
  bool _isSubmitting = false;

  // Generated up front so the invite section (and the picker dialogs inside
  // it) has a stable id to stage against even before a brand-new event is
  // saved for the first time — see EventsRepository.createEvent's optional
  // `id` param, which lets this exact id become the real one on save.
  late final String _eventId = widget.existingEvent?.id ?? const Uuid().v4();
  InviteStaging _inviteStaging = const InviteStaging();

  // Three states: !_hasSchedule = backlog idea; _hasSchedule &&
  // !_hasSpecificTime = loose item for _day; _hasSchedule &&
  // _hasSpecificTime = a normal timed event. Repeat/reminders only apply
  // in the last state.
  bool _hasSchedule = true;
  bool _hasSpecificTime = true;

  RecurrenceFrequency? _repeatFrequency;
  int _repeatInterval = 1;
  Set<int> _repeatWeekdays = {};
  // Monthly-only: false = "same day-of-month" (e.g. the 15th), true = "the
  // Nth weekday" (e.g. the 3rd Thursday), always derived from _startTime
  // rather than manually configurable to an arbitrary weekday.
  bool _monthlyByWeekday = false;
  RecurrenceEndType _repeatEndType = RecurrenceEndType.never;
  DateTime? _repeatUntil;
  int _repeatCount = 10;

  // Kept sorted so the chips render in a stable, ascending order.
  final SplayTreeSet<int> _selectedReminderMinutes = SplayTreeSet<int>();
  // Custom (non-preset) reminder values the user has added, so their chips
  // stick around and stay tappable to toggle on/off, rather than
  // disappearing the moment they're deselected.
  final SplayTreeSet<int> _customReminderOptions = SplayTreeSet<int>();
  final _customReminderAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final event = widget.existingEvent;
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(text: event?.description ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');

    if (event != null) {
      _hasSchedule = event.assignedDate != null || event.startTime != null;
      _hasSpecificTime = event.startTime != null;
    }

    // A tapped occurrence's own start/end (when editing one instance of a
    // recurring series) takes priority over the master's stored anchor
    // time, which only represents the very first occurrence.
    final occurrenceStart = widget.occurrenceStart;
    final effectiveStartTime = occurrenceStart ?? event?.startTime;
    final effectiveEndTime = occurrenceStart != null && event?.startTime != null && event?.endTime != null
        ? occurrenceStart.add(event!.endTime!.difference(event.startTime!))
        : event?.endTime;

    final baseDay = widget.initialDay ?? DateTime.now();
    final referenceDay = effectiveStartTime ?? event?.assignedDate ?? baseDay;
    _day = DateTime(referenceDay.year, referenceDay.month, referenceDay.day);
    _startTime = effectiveStartTime ?? DateTime(referenceDay.year, referenceDay.month, referenceDay.day, 9);
    _endTime = effectiveEndTime ?? _startTime.add(const Duration(hours: 1));
    _isAllDay = event?.isAllDay ?? false;

    final existingRule = RecurrenceRule.decode(event?.rrule);
    if (existingRule != null) {
      _repeatFrequency = existingRule.frequency;
      _repeatInterval = existingRule.interval;
      _repeatWeekdays = existingRule.byWeekdays;
      _monthlyByWeekday =
          existingRule.monthlyByDayOrdinal != null && existingRule.monthlyByDayWeekday != null;
      if (existingRule.until != null) {
        _repeatEndType = RecurrenceEndType.onDate;
        _repeatUntil = existingRule.until;
      } else if (existingRule.count != null) {
        _repeatEndType = RecurrenceEndType.afterCount;
        _repeatCount = existingRule.count!;
      }
    }

    _selectedReminderMinutes.addAll(decodeReminderMinutes(event?.reminderMinutes));
    _customReminderOptions
        .addAll(_selectedReminderMinutes.where((m) => !reminderPresets.contains(m)));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _customReminderAmountController.dispose();
    super.dispose();
  }

  // Day is set once via the single "Day" field above; Start/End only ever
  // touch the time-of-day, so adjusting one never disturbs the other.

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _startTime : _endTime;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null || !mounted) return;
    _applyDateTime(
      isStart: isStart,
      DateTime(current.year, current.month, current.day, time.hour, time.minute),
    );
  }

  void _applyDateTime(DateTime combined, {required bool isStart}) {
    setState(() {
      if (isStart) {
        _startTime = combined;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = combined;
      }
    });
  }

  // Writes land in the local database immediately (offline-first) and sync
  // to the server in the background, so these complete fast regardless of
  // connectivity — no network error handling needed here.

  bool get _isRecurringOccurrence =>
      widget.existingEvent?.rrule != null && widget.occurrenceStart != null;

  Future<_RecurringEditScope?> _askEditScope({required bool isDelete}) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<_RecurringEditScope>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isDelete ? l10n.deleteRecurringEventTitle : l10n.editRecurringEventTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_RecurringEditScope.thisEvent),
            child: Text(l10n.scopeThisEvent),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_RecurringEditScope.allEvents),
            child: Text(l10n.scopeAllEvents),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    var scope = _RecurringEditScope.allEvents;
    if (_isRecurringOccurrence) {
      final chosen = await _askEditScope(isDelete: false);
      if (chosen == null) return;
      scope = chosen;
    }

    setState(() => _isSubmitting = true);

    final repository = ref.read(eventsRepositoryProvider);
    final description =
        _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
    final location =
        _locationController.text.trim().isEmpty ? null : _locationController.text.trim();
    final title = _titleController.text.trim();

    final isTimed = _hasSchedule && _hasSpecificTime;
    final isLoose = _hasSchedule && !_hasSpecificTime;
    final reminderMinutes = isTimed ? _selectedReminderMinutes.toList() : const <int>[];

    if (widget.existingEvent == null) {
      await repository.createEvent(
        id: _eventId,
        title: title,
        description: description,
        location: location,
        assignedDate: isLoose ? _day : null,
        startTime: isTimed ? _startTime : null,
        endTime: isTimed ? _endTime : null,
        isAllDay: isTimed && _isAllDay,
        rrule: isTimed ? _buildRrule() : null,
        reminderMinutes: reminderMinutes,
      );
    } else if (_isRecurringOccurrence && scope == _RecurringEditScope.thisEvent) {
      // A single occurrence becomes its own standalone event — it never
      // carries a repeat pattern of its own, regardless of what the (now
      // irrelevant, since it belongs to the untouched master) repeat
      // section shows. Deliberately not passed `id: _eventId` here — this
      // creates a brand new override row distinct from the master, and
      // _eventId is the master's id in this branch (existingEvent is set).
      // Any invite staging done in this session is applied to _eventId
      // below, i.e. to the master's invite list, not this new override.
      await repository.createEvent(
        title: title,
        description: description,
        location: location,
        startTime: _startTime,
        endTime: _endTime,
        isAllDay: _isAllDay,
        reminderMinutes: reminderMinutes,
        recurrenceOverrideOf: widget.existingEvent!.id,
        originalOccurrenceStart: widget.occurrenceStart,
      );
      await repository.excludeOccurrence(widget.existingEvent!.id, widget.occurrenceStart!);
    } else {
      DateTime? newStartTime;
      DateTime? newEndTime;
      if (isTimed) {
        if (_isRecurringOccurrence) {
          // Only the time-of-day can meaningfully change for the whole
          // series — the recurrence pattern's anchor date has to stay put,
          // or which weekday/day-of-month it lands on would silently shift.
          final originalAnchor = widget.existingEvent!.startTime!;
          final baseline = widget.occurrenceStart!;
          final timeDelta = Duration(
            hours: _startTime.hour - baseline.hour,
            minutes: _startTime.minute - baseline.minute,
          );
          newStartTime = originalAnchor.add(timeDelta);
          newEndTime = newStartTime.add(_endTime.difference(_startTime));
        } else {
          newStartTime = _startTime;
          newEndTime = _endTime;
        }
      }
      final rrule = isTimed ? _buildRrule() : null;

      await repository.updateEvent(
        widget.existingEvent!.id,
        title: title,
        description: description,
        clearDescription: description == null,
        location: location,
        clearLocation: location == null,
        clearSchedule: !_hasSchedule,
        assignedDate: isLoose ? _day : null,
        startTime: newStartTime,
        endTime: newEndTime,
        clearTime: isLoose,
        isAllDay: isTimed && _isAllDay,
        rrule: rrule,
        clearRrule: rrule == null,
        reminderMinutes: reminderMinutes,
      );
    }

    if (!_inviteStaging.isEmpty) {
      if (widget.existingEvent == null) {
        // createEvent() above only wrote the event locally and kicked off a
        // background sync — force it to actually land server-side first, or
        // the invite call below could race ahead of the event existing.
        await repository.syncEventNow(_eventId);
      }
      await _applyInviteStaging(_eventId);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _applyInviteStaging(String eventId) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      if (_inviteStaging.newUserIds.isNotEmpty || _inviteStaging.newGroupIds.isNotEmpty) {
        await apiClient.inviteToEvent(
          eventId,
          userIds: _inviteStaging.newUserIds.toList(),
          groupIds: _inviteStaging.newGroupIds.toList(),
        );
      }
      for (final inviteId in _inviteStaging.revokedInviteIds) {
        await apiClient.revokeEventInvite(eventId, inviteId);
      }
      ref.invalidate(eventInvitesProvider(eventId));
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final message = error is ApiException ? error.message : error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inviteApplyFailed(message))),
        );
      }
    }
  }

  // Repeat/reminders only make sense with a specific time, so dropping the
  // time (or the schedule entirely) clears them rather than leaving stale
  // state hidden behind a toggle that could get silently resubmitted later.
  void _resetTimeOnlyState() {
    _repeatFrequency = null;
    _repeatEndType = RecurrenceEndType.never;
    _repeatUntil = null;
    _selectedReminderMinutes.clear();
  }

  Future<void> _pickDay() async {
    final current = _hasSpecificTime ? _startTime : _day;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return;
    final newDay = DateTime(date.year, date.month, date.day);

    setState(() {
      if (_hasSpecificTime) {
        // Shift both start and end by the same number of days so their
        // times-of-day (and the gap between them) stay untouched.
        final dayDelta = newDay.difference(DateTime(current.year, current.month, current.day));
        _startTime = _startTime.add(dayDelta);
        _endTime = _endTime.add(dayDelta);
      } else {
        _day = newDay;
      }
    });
  }

  // Moving a task between backlog and a specific day/time is done by
  // dragging it on the calendar screen; these two actions only cover
  // toggling a specific time on/off for a task that's already scheduled.

  void _addSpecificTime() {
    setState(() {
      _startTime = DateTime(_day.year, _day.month, _day.day, _startTime.hour, _startTime.minute);
      _endTime = _startTime.add(const Duration(hours: 1));
      _hasSpecificTime = true;
    });
  }

  void _removeSpecificTime() {
    setState(() {
      _day = DateTime(_startTime.year, _startTime.month, _startTime.day);
      _hasSpecificTime = false;
      _resetTimeOnlyState();
    });
  }

  String? _buildRrule() {
    final freq = _repeatFrequency;
    if (freq == null) return null;
    final useMonthlyByWeekday = freq == RecurrenceFrequency.monthly && _monthlyByWeekday;
    return RecurrenceRule(
      frequency: freq,
      interval: _repeatInterval,
      byWeekdays: freq == RecurrenceFrequency.weekly ? _repeatWeekdays : const {},
      monthlyByDayOrdinal: useMonthlyByWeekday ? monthlyWeekdayOrdinal(_startTime) : null,
      monthlyByDayWeekday: useMonthlyByWeekday ? _startTime.weekday : null,
      until: _repeatEndType == RecurrenceEndType.onDate ? _repeatUntil : null,
      count: _repeatEndType == RecurrenceEndType.afterCount ? _repeatCount : null,
    ).encode();
  }

  Future<void> _pickRepeatUntil() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _repeatUntil ?? _startTime.add(const Duration(days: 30)),
      firstDate: _startTime,
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _repeatUntil = date);
  }

  String _intervalUnitLabel(RecurrenceFrequency freq, AppLocalizations l10n) {
    switch (freq) {
      case RecurrenceFrequency.daily:
        return l10n.repeatUnitDay(_repeatInterval);
      case RecurrenceFrequency.weekly:
        return l10n.repeatUnitWeek(_repeatInterval);
      case RecurrenceFrequency.monthly:
        return l10n.repeatUnitMonth(_repeatInterval);
      case RecurrenceFrequency.yearly:
        return l10n.repeatUnitYear(_repeatInterval);
    }
  }

  static const _weekdayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

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

  // The day lives solely in the "Day" field above; this row only ever picks
  // a time-of-day, so it never disturbs the day.
  Widget _buildTimeRow({
    required String label,
    required DateTime value,
    required VoidCallback onPickTime,
    Widget? trailing,
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
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _buildRepeatSection(AppLocalizations l10n) {
    final freq = _repeatFrequency;
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
          onChanged: (value) => setState(() {
            _repeatFrequency = value;
            if (value == RecurrenceFrequency.weekly && _repeatWeekdays.isEmpty) {
              _repeatWeekdays = {_startTime.weekday};
            }
          }),
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
                  initialValue: '$_repeatInterval',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) setState(() => _repeatInterval = parsed);
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
                final selected = _repeatWeekdays.contains(day);
                return FilterChip(
                  label: Text(_weekdayLabels[i]),
                  selected: selected,
                  onSelected: (value) => setState(() {
                    if (value) {
                      _repeatWeekdays.add(day);
                    } else if (_repeatWeekdays.length > 1) {
                      _repeatWeekdays.remove(day);
                    }
                  }),
                );
              }),
            ),
          ],
          if (freq == RecurrenceFrequency.monthly) ...[
            const SizedBox(height: 4),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.repeatMonthlyByDay(_startTime.day)),
              value: false,
              groupValue: _monthlyByWeekday,
              onChanged: (value) => setState(() => _monthlyByWeekday = value!),
            ),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.repeatMonthlyByWeekday(
                _ordinalLabel(monthlyWeekdayOrdinal(_startTime), l10n),
                _fullWeekdayLabel(_startTime.weekday, l10n),
              )),
              value: true,
              groupValue: _monthlyByWeekday,
              onChanged: (value) => setState(() => _monthlyByWeekday = value!),
            ),
          ],
          const SizedBox(height: 12),
          Text(l10n.endsWord, style: const TextStyle(fontWeight: FontWeight.w600)),
          RadioListTile<RecurrenceEndType>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.repeatEndNever),
            value: RecurrenceEndType.never,
            groupValue: _repeatEndType,
            onChanged: (value) => setState(() => _repeatEndType = value!),
          ),
          RadioListTile<RecurrenceEndType>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(_repeatUntil == null
                ? l10n.repeatEndOnDate
                : l10n.repeatEndOnDateWithValue(DateFormat.yMMMd().format(_repeatUntil!))),
            value: RecurrenceEndType.onDate,
            groupValue: _repeatEndType,
            onChanged: (value) async {
              setState(() => _repeatEndType = value!);
              await _pickRepeatUntil();
            },
          ),
          RadioListTile<RecurrenceEndType>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.repeatEndAfterCount(_repeatCount)),
            value: RecurrenceEndType.afterCount,
            groupValue: _repeatEndType,
            onChanged: (value) => setState(() => _repeatEndType = value!),
          ),
          if (_repeatEndType == RecurrenceEndType.afterCount)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Row(
                children: [
                  Text(l10n.occurrencesLabel),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: TextFormField(
                      initialValue: '$_repeatCount',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) setState(() => _repeatCount = parsed);
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (widget.existingEvent?.rrule != null)
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

  Widget _buildRemindersSection(AppLocalizations l10n) {
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
                selected: _selectedReminderMinutes.contains(minutes),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _selectedReminderMinutes.add(minutes);
                  } else {
                    _selectedReminderMinutes.remove(minutes);
                  }
                }),
              ),
            for (final minutes in _customReminderOptions)
              FilterChip(
                label: Text(reminderLabel(minutes, l10n)),
                selected: _selectedReminderMinutes.contains(minutes),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _selectedReminderMinutes.add(minutes);
                  } else {
                    _selectedReminderMinutes.remove(minutes);
                  }
                }),
                onDeleted: () => setState(() {
                  _customReminderOptions.remove(minutes);
                  _selectedReminderMinutes.remove(minutes);
                }),
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
    setState(() {
      if (!reminderPresets.contains(minutes)) {
        _customReminderOptions.add(minutes);
      }
      _selectedReminderMinutes.add(minutes);
    });
  }

  Future<void> _delete() async {
    final event = widget.existingEvent;
    if (event == null) return;

    var scope = _RecurringEditScope.allEvents;
    if (_isRecurringOccurrence) {
      final chosen = await _askEditScope(isDelete: true);
      if (chosen == null) return;
      scope = chosen;
    }

    setState(() => _isSubmitting = true);

    final repository = ref.read(eventsRepositoryProvider);
    if (_isRecurringOccurrence && scope == _RecurringEditScope.thisEvent) {
      await repository.excludeOccurrence(event.id, widget.occurrenceStart!);
    } else {
      await repository.deleteEvent(event.id);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmLeaveEvent(Event event, AppLocalizations l10n) async {
    // Skipped entirely once the user has opted out via the dialog's "Don't
    // ask me again" checkbox below — re-enabled from General settings,
    // since there's otherwise no way back from that choice.
    if (!ref.read(settingsControllerProvider).confirmBeforeLeavingEvent) {
      await _leaveEvent(event);
      return;
    }

    var dontAskAgain = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.leaveEventDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.leaveEventDialogMessage),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.actionDontAskAgain),
                value: dontAskAgain,
                onChanged: (value) => setDialogState(() => dontAskAgain = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.actionLeaveEvent),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    // Only persisted on an actual confirm — checking the box then hitting
    // Cancel shouldn't silently suppress the warning for a leave that never
    // happened.
    if (dontAskAgain) {
      await ref
          .read(settingsControllerProvider.notifier)
          .update((s) => s.copyWith(confirmBeforeLeavingEvent: false));
    }

    await _leaveEvent(event);
  }

  Future<void> _leaveEvent(Event event) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(eventsRepositoryProvider).leaveEvent(event.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingEvent != null;
    final event = widget.existingEvent;

    final currentUserId = ref.watch(currentUserIdProvider).valueOrNull;
    final isOwnEvent = event == null || currentUserId == null || event.userId == currentUserId;

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.eventFormEditTitle : l10n.eventFormNewTitle),
        actions: [
          if (isEditing && isOwnEvent)
            IconButton(
              onPressed: _isSubmitting ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          if (isEditing && !isOwnEvent)
            IconButton(
              tooltip: l10n.actionLeaveEvent,
              onPressed: _isSubmitting ? null : () => _confirmLeaveEvent(event, l10n),
              icon: const Icon(Icons.exit_to_app),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!isOwnEvent)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.group_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      event.ownerDisplayName != null
                          ? l10n.sharedByOwner(event.ownerDisplayName!)
                          : l10n.sharedWithYou,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(labelText: l10n.fieldTitle),
              textInputAction: TextInputAction.next,
              autofocus: true,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? l10n.validatorTitleRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: l10n.fieldDescription),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.fieldLocation,
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            if (_hasSchedule) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.fieldDay),
                subtitle: Text(DateFormat.yMMMd().format(_hasSpecificTime ? _startTime : _day)),
                onTap: _pickDay,
                trailing: _hasSpecificTime
                    ? TextButton(onPressed: _removeSpecificTime, child: Text(l10n.actionNoSpecificTime))
                    : TextButton(onPressed: _addSpecificTime, child: Text(l10n.actionAddATime)),
              ),
              if (_hasSpecificTime) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.allDay),
                  value: _isAllDay,
                  onChanged: (value) => setState(() => _isAllDay = value),
                ),
                _buildTimeRow(
                  label: l10n.labelStart,
                  value: _startTime,
                  onPickTime: () => _pickTime(isStart: true),
                ),
                _buildTimeRow(
                  label: l10n.labelEnd,
                  value: _endTime,
                  onPickTime: () => _pickTime(isStart: false),
                ),
                const SizedBox(height: 12),
                _buildRepeatSection(l10n),
                const SizedBox(height: 20),
                _buildRemindersSection(l10n),
              ],
            ],
            if (isEditing) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              EventAttachmentsSection(eventId: event!.id, canManage: true),
            ],
            if (isOwnEvent) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              EventInviteSection(
                eventId: _eventId,
                eventExistsOnServer: isEditing,
                onStagingChanged: (staging) => setState(() => _inviteStaging = staging),
              ),
            ] else if (isEditing) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              SharedWithReadOnlySection(eventId: _eventId),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _save,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? l10n.actionSaveChanges : l10n.actionCreateEvent),
            ),
          ],
        ),
      ),
    );
  }
}
