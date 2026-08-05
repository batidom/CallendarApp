import '../data/local/app_database.dart';

enum RecurrenceFrequency { daily, weekly, monthly, yearly }

enum RecurrenceEndType { never, onDate, afterCount }

const _freqCodes = {
  RecurrenceFrequency.daily: 'DAILY',
  RecurrenceFrequency.weekly: 'WEEKLY',
  RecurrenceFrequency.monthly: 'MONTHLY',
  RecurrenceFrequency.yearly: 'YEARLY',
};

const _dayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// A simple RFC 5545-ish recurrence rule (FREQ/INTERVAL/BYDAY/UNTIL/COUNT)
/// encoded to and from the plain string stored in [Event.rrule]. Using the
/// RRULE format (rather than a bespoke encoding) keeps the field compatible
/// with a future Google Calendar sync, which speaks the same format.
class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.byWeekdays = const {},
    this.monthlyByDayOrdinal,
    this.monthlyByDayWeekday,
    this.until,
    this.count,
  });

  final RecurrenceFrequency frequency;
  final int interval;

  /// 1 = Monday .. 7 = Sunday (matches [DateTime.weekday]). Only meaningful
  /// for [RecurrenceFrequency.weekly].
  final Set<int> byWeekdays;

  /// Set together (only for [RecurrenceFrequency.monthly]) to repeat on the
  /// Nth weekday of the month instead of a fixed day-of-month — e.g. "the
  /// 3rd Thursday". [monthlyByDayOrdinal] is 1-4, or -1 for "the last".
  /// Both null means the plain "same day-of-month" mode.
  final int? monthlyByDayOrdinal;
  final int? monthlyByDayWeekday;

  final DateTime? until;
  final int? count;

  String encode() {
    final parts = <String>['FREQ=${_freqCodes[frequency]}'];
    if (interval > 1) parts.add('INTERVAL=$interval');
    if (frequency == RecurrenceFrequency.weekly && byWeekdays.isNotEmpty) {
      final sorted = byWeekdays.toList()..sort();
      parts.add('BYDAY=${sorted.map((d) => _dayCodes[d - 1]).join(',')}');
    }
    if (frequency == RecurrenceFrequency.monthly &&
        monthlyByDayOrdinal != null &&
        monthlyByDayWeekday != null) {
      parts.add('BYDAY=$monthlyByDayOrdinal${_dayCodes[monthlyByDayWeekday! - 1]}');
    }
    if (until != null) {
      final u = until!;
      parts.add('UNTIL=${_pad4(u.year)}${_pad2(u.month)}${_pad2(u.day)}T235959Z');
    } else if (count != null) {
      parts.add('COUNT=$count');
    }
    return parts.join(';');
  }

  static final RegExp _monthlyByDayPattern = RegExp(r'^(-?\d+)([A-Z]{2})$');

  static RecurrenceRule? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final fields = <String, String>{};
    for (final part in raw.split(';')) {
      final eq = part.indexOf('=');
      if (eq == -1) continue;
      fields[part.substring(0, eq)] = part.substring(eq + 1);
    }

    final frequency = _freqCodes.entries
        .firstWhere((e) => e.value == fields['FREQ'], orElse: () => _freqCodes.entries.first)
        .key;

    final interval = int.tryParse(fields['INTERVAL'] ?? '') ?? 1;

    final byWeekdays = <int>{};
    int? monthlyByDayOrdinal;
    int? monthlyByDayWeekday;
    final byDayRaw = fields['BYDAY'];
    if (byDayRaw != null) {
      if (frequency == RecurrenceFrequency.monthly) {
        final match = _monthlyByDayPattern.firstMatch(byDayRaw);
        if (match != null) {
          final idx = _dayCodes.indexOf(match.group(2)!);
          if (idx != -1) {
            monthlyByDayOrdinal = int.parse(match.group(1)!);
            monthlyByDayWeekday = idx + 1;
          }
        }
      } else {
        for (final code in byDayRaw.split(',')) {
          final idx = _dayCodes.indexOf(code);
          if (idx != -1) byWeekdays.add(idx + 1);
        }
      }
    }

    DateTime? until;
    final untilRaw = fields['UNTIL'];
    if (untilRaw != null && untilRaw.length >= 8) {
      until = DateTime(
        int.parse(untilRaw.substring(0, 4)),
        int.parse(untilRaw.substring(4, 6)),
        int.parse(untilRaw.substring(6, 8)),
      );
    }

    final count = int.tryParse(fields['COUNT'] ?? '');

    return RecurrenceRule(
      frequency: frequency,
      interval: interval < 1 ? 1 : interval,
      byWeekdays: byWeekdays,
      monthlyByDayOrdinal: monthlyByDayOrdinal,
      monthlyByDayWeekday: monthlyByDayWeekday,
      until: until,
      count: count,
    );
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');
  static String _pad4(int n) => n.toString().padLeft(4, '0');
}

/// The ordinal (1-4, or -1 for "last") of [date]'s weekday within its month
/// — e.g. the 3rd Thursday. A forward count that would reach a nonexistent
/// 5th occurrence is treated as "last" instead, since months don't reliably
/// have one.
int monthlyWeekdayOrdinal(DateTime date) {
  final ordinal = ((date.day - 1) ~/ 7) + 1;
  return ordinal >= 5 ? -1 : ordinal;
}

int? _nthWeekdayOfMonth(int year, int month, int weekday, int ordinal) {
  final daysInMonth = _daysInMonth(year, month);
  if (ordinal > 0) {
    final firstOfMonth = DateTime(year, month, 1);
    final firstWeekdayOffset = (weekday - firstOfMonth.weekday + 7) % 7;
    final day = 1 + firstWeekdayOffset + (ordinal - 1) * 7;
    return day <= daysInMonth ? day : null;
  }
  final lastOfMonth = DateTime(year, month, daysInMonth);
  final lastWeekdayOffset = (lastOfMonth.weekday - weekday + 7) % 7;
  return daysInMonth - lastWeekdayOffset;
}

/// Encodes/decodes the comma-separated list of excluded occurrence instants
/// stored on a recurring master's [Event.excludedOccurrences] — the slots
/// where a "this event only" edit or delete has removed that occurrence
/// from the series (see EventsRepository.excludeOccurrence).
List<DateTime> decodeExcludedOccurrences(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((s) => DateTime.tryParse(s.trim()))
      .whereType<DateTime>()
      .map((d) => d.toLocal())
      .toList();
}

String? encodeExcludedOccurrences(List<DateTime> instants) {
  if (instants.isEmpty) return null;
  final unique = <DateTime>{};
  for (final instant in instants) {
    unique.add(instant.toUtc());
  }
  return unique.map((d) => d.toIso8601String()).join(',');
}

/// One concrete occurrence of an [Event] on the calendar: [master] is the
/// stored row (used for edit navigation, drag data, and color), while
/// [start]/[end] are this specific instance's date/time.
class EventOccurrence {
  const EventOccurrence(this.master, this.start, this.end);

  final Event master;
  final DateTime start;
  final DateTime end;

  bool get isRecurring => master.rrule != null;
}

// Safety cap on how many periods a generator will step through — well
// beyond anything a real range/until/count would need, just a guard against
// a runaway loop.
const _maxGeneratorSteps = 3660;

/// Expands [event] into the concrete occurrences that fall within
/// `[rangeStart, rangeEndExclusive)`. Non-recurring events yield at most one
/// occurrence (themselves, if in range). A task with no [Event.startTime]
/// (a backlog idea or a loose day item) never occurs here — it's rendered
/// directly from its backlog/assignedDate bucket instead.
List<EventOccurrence> expandEventOccurrences(
  Event event, {
  required DateTime rangeStart,
  required DateTime rangeEndExclusive,
}) {
  final startTime = event.startTime;
  if (startTime == null) return const [];
  final endTime = event.endTime ?? startTime;

  final rule = RecurrenceRule.decode(event.rrule);
  if (rule == null) {
    if (endTime.isBefore(rangeStart) || !startTime.isBefore(rangeEndExclusive)) {
      return const [];
    }
    return [EventOccurrence(event, startTime, endTime)];
  }

  final duration = endTime.difference(startTime);
  final untilCutoff =
      rule.until == null ? null : DateTime(rule.until!.year, rule.until!.month, rule.until!.day, 23, 59, 59);
  final excluded = decodeExcludedOccurrences(event.excludedOccurrences);

  final results = <EventOccurrence>[];
  var occurrenceIndex = 0;

  for (final start in _generateStarts(rule, startTime)) {
    if (untilCutoff != null && start.isAfter(untilCutoff)) break;
    if (!start.isBefore(rangeEndExclusive)) break;

    occurrenceIndex++;
    if (rule.count != null && occurrenceIndex > rule.count!) break;

    // A "this event only" edit or delete removes this slot from the series
    // — either it's now rendered by a standalone override row instead, or
    // it's simply gone.
    if (excluded.any((e) => e.isAtSameMomentAs(start))) continue;

    if (!start.isBefore(rangeStart)) {
      results.add(EventOccurrence(event, start, start.add(duration)));
    }
  }

  return results;
}

Iterable<DateTime> _generateStarts(RecurrenceRule rule, DateTime seriesStart) sync* {
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      var current = seriesStart;
      for (var i = 0; i < _maxGeneratorSteps; i++) {
        yield current;
        current = current.add(Duration(days: rule.interval));
      }
      return;

    case RecurrenceFrequency.weekly:
      final weekdays = rule.byWeekdays.isEmpty ? {seriesStart.weekday} : rule.byWeekdays;
      final anchorWeekStart = _mondayOf(seriesStart);
      var day = DateTime(seriesStart.year, seriesStart.month, seriesStart.day);
      for (var i = 0; i < _maxGeneratorSteps * 7; i++) {
        final weeksSince = _mondayOf(day).difference(anchorWeekStart).inDays ~/ 7;
        if (weeksSince % rule.interval == 0 && weekdays.contains(day.weekday)) {
          yield DateTime(day.year, day.month, day.day, seriesStart.hour, seriesStart.minute, seriesStart.second);
        }
        day = day.add(const Duration(days: 1));
      }
      return;

    case RecurrenceFrequency.monthly:
      for (var k = 0; k < _maxGeneratorSteps; k++) {
        final totalMonths = seriesStart.month - 1 + rule.interval * k;
        final year = seriesStart.year + totalMonths ~/ 12;
        final month = totalMonths % 12 + 1;
        if (rule.monthlyByDayOrdinal != null && rule.monthlyByDayWeekday != null) {
          final day = _nthWeekdayOfMonth(year, month, rule.monthlyByDayWeekday!, rule.monthlyByDayOrdinal!);
          if (day != null) {
            yield DateTime(year, month, day, seriesStart.hour, seriesStart.minute, seriesStart.second);
          }
        } else if (seriesStart.day <= _daysInMonth(year, month)) {
          yield DateTime(
              year, month, seriesStart.day, seriesStart.hour, seriesStart.minute, seriesStart.second);
        }
      }
      return;

    case RecurrenceFrequency.yearly:
      for (var k = 0; k < _maxGeneratorSteps; k++) {
        final year = seriesStart.year + rule.interval * k;
        if (seriesStart.day <= _daysInMonth(year, seriesStart.month)) {
          yield DateTime(year, seriesStart.month, seriesStart.day, seriesStart.hour, seriesStart.minute,
              seriesStart.second);
        }
      }
      return;
  }
}

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

int _daysInMonth(int year, int month) {
  final firstOfNextMonth = DateTime(year, month + 1, 1);
  return firstOfNextMonth.subtract(const Duration(days: 1)).day;
}
