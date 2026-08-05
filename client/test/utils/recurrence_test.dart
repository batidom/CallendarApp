import 'package:calendar_client/data/local/app_database.dart';
import 'package:calendar_client/utils/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

Event _event({
  String id = 'e1',
  DateTime? startTime,
  DateTime? endTime,
  String? rrule,
  String? excludedOccurrences,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Event(
    id: id,
    userId: 'u1',
    title: 'Test event',
    isAllDay: false,
    createdAt: now,
    updatedAt: now,
    myRole: 'owner',
    startTime: startTime,
    endTime: endTime,
    rrule: rrule,
    excludedOccurrences: excludedOccurrences,
  );
}

void main() {
  group('RecurrenceRule.encode / decode', () {
    test('round-trips a plain weekly rule', () {
      const rule = RecurrenceRule(frequency: RecurrenceFrequency.weekly, byWeekdays: {1, 3, 5});
      final decoded = RecurrenceRule.decode(rule.encode());
      expect(decoded!.frequency, RecurrenceFrequency.weekly);
      expect(decoded.byWeekdays, {1, 3, 5});
    });

    test('omits INTERVAL when it is 1, includes it otherwise', () {
      expect(const RecurrenceRule(frequency: RecurrenceFrequency.daily).encode(), 'FREQ=DAILY');
      expect(
        const RecurrenceRule(frequency: RecurrenceFrequency.daily, interval: 2).encode(),
        'FREQ=DAILY;INTERVAL=2',
      );
    });

    test('encodes and decodes a monthly "Nth weekday" rule', () {
      const rule = RecurrenceRule(
        frequency: RecurrenceFrequency.monthly,
        monthlyByDayOrdinal: 3,
        monthlyByDayWeekday: 4, // Thursday
      );
      expect(rule.encode(), 'FREQ=MONTHLY;BYDAY=3TH');
      final decoded = RecurrenceRule.decode(rule.encode());
      expect(decoded!.monthlyByDayOrdinal, 3);
      expect(decoded.monthlyByDayWeekday, 4);
    });

    test('encodes UNTIL as an end-of-day UTC timestamp', () {
      final rule = RecurrenceRule(frequency: RecurrenceFrequency.yearly, until: DateTime(2026, 3, 5));
      expect(rule.encode(), 'FREQ=YEARLY;UNTIL=20260305T235959Z');
    });

    test('decode returns null for empty/null input', () {
      expect(RecurrenceRule.decode(null), isNull);
      expect(RecurrenceRule.decode(''), isNull);
      expect(RecurrenceRule.decode('   '), isNull);
    });

    test('decode clamps a nonsensical interval up to 1', () {
      final decoded = RecurrenceRule.decode('FREQ=DAILY;INTERVAL=0');
      expect(decoded!.interval, 1);
    });
  });

  group('monthlyWeekdayOrdinal', () {
    test('the first through fourth occurrence are numbered 1-4', () {
      expect(monthlyWeekdayOrdinal(DateTime(2026, 3, 5)), 1); // 1st Thursday
      expect(monthlyWeekdayOrdinal(DateTime(2026, 3, 12)), 2);
      expect(monthlyWeekdayOrdinal(DateTime(2026, 3, 19)), 3);
      expect(monthlyWeekdayOrdinal(DateTime(2026, 3, 26)), 4);
    });

    test('a 5th occurrence is reported as -1 ("last")', () {
      // March 2026 has a 5th Sunday (the 29th).
      expect(monthlyWeekdayOrdinal(DateTime(2026, 3, 29)), -1);
    });
  });

  group('excluded occurrences encode/decode', () {
    test('round-trips through UTC', () {
      final instants = [DateTime.utc(2026, 5, 1, 9), DateTime.utc(2026, 5, 8, 9)];
      final encoded = encodeExcludedOccurrences(instants);
      final decoded = decodeExcludedOccurrences(encoded);
      expect(decoded.map((d) => d.toUtc()).toSet(), instants.toSet());
    });

    test('empty list encodes to null', () {
      expect(encodeExcludedOccurrences([]), isNull);
    });

    test('decode of null/empty returns an empty list', () {
      expect(decodeExcludedOccurrences(null), isEmpty);
      expect(decodeExcludedOccurrences(''), isEmpty);
    });
  });

  group('expandEventOccurrences', () {
    test('a non-recurring event yields itself once if in range', () {
      final start = DateTime.utc(2026, 6, 10, 9);
      final end = DateTime.utc(2026, 6, 10, 10);
      final occurrences = expandEventOccurrences(
        _event(startTime: start, endTime: end),
        rangeStart: DateTime.utc(2026, 6, 1),
        rangeEndExclusive: DateTime.utc(2026, 7, 1),
      );
      expect(occurrences, hasLength(1));
      expect(occurrences.single.start, start);
    });

    test('a non-recurring event outside the range yields nothing', () {
      final occurrences = expandEventOccurrences(
        _event(startTime: DateTime.utc(2026, 8, 10, 9), endTime: DateTime.utc(2026, 8, 10, 10)),
        rangeStart: DateTime.utc(2026, 6, 1),
        rangeEndExclusive: DateTime.utc(2026, 7, 1),
      );
      expect(occurrences, isEmpty);
    });

    test('a task with no startTime never produces occurrences', () {
      final occurrences = expandEventOccurrences(
        _event(),
        rangeStart: DateTime.utc(2026, 6, 1),
        rangeEndExclusive: DateTime.utc(2026, 7, 1),
      );
      expect(occurrences, isEmpty);
    });

    test('a daily rule produces one occurrence per day in range', () {
      final start = DateTime.utc(2026, 6, 1, 9);
      final rule = const RecurrenceRule(frequency: RecurrenceFrequency.daily).encode();
      final occurrences = expandEventOccurrences(
        _event(startTime: start, endTime: start.add(const Duration(hours: 1)), rrule: rule),
        rangeStart: DateTime.utc(2026, 6, 1),
        rangeEndExclusive: DateTime.utc(2026, 6, 8),
      );
      expect(occurrences, hasLength(7));
    });

    test('an UNTIL cutoff stops generation', () {
      final start = DateTime.utc(2026, 6, 1, 9);
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        until: DateTime.utc(2026, 6, 3),
      ).encode();
      final occurrences = expandEventOccurrences(
        _event(startTime: start, endTime: start.add(const Duration(hours: 1)), rrule: rule),
        rangeStart: DateTime.utc(2026, 6, 1),
        rangeEndExclusive: DateTime.utc(2026, 6, 30),
      );
      expect(occurrences, hasLength(3)); // Jun 1, 2, 3
    });

    test('an excluded occurrence is skipped', () {
      final start = DateTime.utc(2026, 6, 1, 9);
      final rule = const RecurrenceRule(frequency: RecurrenceFrequency.daily).encode();
      final excluded = encodeExcludedOccurrences([DateTime.utc(2026, 6, 2, 9)]);
      final occurrences = expandEventOccurrences(
        _event(
          startTime: start,
          endTime: start.add(const Duration(hours: 1)),
          rrule: rule,
          excludedOccurrences: excluded,
        ),
        rangeStart: DateTime.utc(2026, 6, 1),
        rangeEndExclusive: DateTime.utc(2026, 6, 4),
      );
      expect(occurrences.map((o) => o.start.day), [1, 3]);
    });
  });
}
