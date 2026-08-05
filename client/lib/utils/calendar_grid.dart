import '../services/app_settings.dart';

/// The inclusive start / exclusive end of the full week-grid a month view
/// displays — including the leading/trailing days borrowed from the
/// neighboring months to complete the first/last row. Shared by whatever
/// fetches/watches events for the calendar and whatever buckets them by day,
/// so both agree on exactly which days are actually visible on screen.
({DateTime start, DateTime endExclusive}) gridRangeForMonth(DateTime month, WeekStartDay weekStartDay) {
  final monthStart = DateTime(month.year, month.month, 1);
  final lastDayOfMonth = DateTime(month.year, month.month + 1, 1).subtract(const Duration(days: 1));

  final start = _startOfGridWeek(monthStart, weekStartDay);
  final endExclusive = _startOfGridWeek(lastDayOfMonth, weekStartDay).add(const Duration(days: 7));
  return (start: start, endExclusive: endExclusive);
}

DateTime _startOfGridWeek(DateTime date, WeekStartDay weekStartDay) {
  // DateTime.weekday: 1 = Monday .. 7 = Sunday.
  final offset = weekStartDay == WeekStartDay.monday ? date.weekday - 1 : date.weekday % 7;
  return DateTime(date.year, date.month, date.day).subtract(Duration(days: offset));
}
