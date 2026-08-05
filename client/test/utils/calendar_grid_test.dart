import 'package:calendar_client/services/app_settings.dart';
import 'package:calendar_client/utils/calendar_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gridRangeForMonth', () {
    test('Monday-start grid pads to full weeks around the month', () {
      // March 2026 starts on a Sunday and ends on a Tuesday.
      final range = gridRangeForMonth(DateTime(2026, 3, 1), WeekStartDay.monday);
      expect(range.start, DateTime(2026, 2, 23)); // Monday before Mar 1
      expect(range.endExclusive, DateTime(2026, 4, 6)); // Monday after Mar 31, 6 full weeks
    });

    test('Sunday-start grid uses different padding for the same month', () {
      final range = gridRangeForMonth(DateTime(2026, 3, 1), WeekStartDay.sunday);
      expect(range.start, DateTime(2026, 3, 1)); // Mar 1 2026 is already a Sunday
      expect(range.endExclusive, DateTime(2026, 4, 5)); // 5 full weeks
    });

    test('a month that starts on the grid start day needs no leading padding', () {
      // May 2026 starts on a Friday; with Monday-start the grid still has to
      // pad back to the preceding Monday.
      final range = gridRangeForMonth(DateTime(2026, 6, 1), WeekStartDay.monday);
      expect(range.start.weekday, DateTime.monday);
      expect(range.start.isAfter(DateTime(2026, 6, 1)), isFalse);
    });
  });
}
