import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/local/app_database.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/providers.dart';
import '../services/app_settings.dart';
import '../services/app_window_controller.dart';
import '../services/reminder_engine.dart';
import '../utils/calendar_grid.dart';
import '../utils/event_colors.dart';
import '../utils/notification_formatting.dart';
import '../utils/recurrence.dart';
import 'assistant_screen.dart';
import 'event_form_screen.dart';
import 'notifications_screen.dart';
import 'pending_invite_screen.dart';
import 'settings_screen.dart';
import 'social_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final _quickAddController = TextEditingController();
  DateTime _notificationsSeenAt = DateTime.now();
  // Tracks the newest server notification a sound has already played for —
  // null until the first successful fetch, which deliberately doesn't sound
  // off for whatever's already sitting there from before the app opened
  // (see the ref.listen in build()).
  DateTime? _lastSoundedNotificationAt;
  Timer? _notificationsPollTimer;
  Timer? _eventsPollTimer;
  Timer? _liveTickTimer;

  @override
  void initState() {
    super.initState();
    // notificationsProvider is a plain FutureProvider — it fetches once and
    // then sits stale until something invalidates it, so without this the
    // bell badge would never reflect a change made by someone else while
    // the app is already open (you'd only see it after closing/reopening).
    _notificationsPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(notificationsProvider);
    });

    // eventsForVisibleRangeProvider only pulls from the server once, when
    // the visible month first changes — the grid itself is a live Drift
    // stream off the *local* DB, so it updates instantly for edits made in
    // this window, but a change made by someone else (or from another
    // window on this machine) never arrives until something re-runs
    // refreshRange. Calling it directly (rather than invalidating the
    // provider) writes straight into the local DB, which the already-live
    // stream picks up on its own — no stream teardown, no loading flicker.
    _eventsPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final weekStartDay = ref.read(settingsControllerProvider).weekStartDay;
      final range = gridRangeForMonth(
        ref.read(visibleMonthProvider),
        weekStartDay,
      );
      ref
          .read(eventsRepositoryProvider)
          .refreshRange(range.start, range.endExclusive)
          .catchError(
            (Object error) =>
                debugPrint('Failed to poll events from server: $error'),
          );
    });

    // "Happening now" highlighting (_buildAgendaTile) depends purely on the
    // clock, not on any provider changing — without this it would only ever
    // recompute when something else happens to trigger a rebuild.
    _liveTickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _notificationsPollTimer?.cancel();
    _eventsPollTimer?.cancel();
    _liveTickTimer?.cancel();
    _quickAddController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsForVisibleRangeProvider);
    final weekStartDay = ref.watch(settingsControllerProvider).weekStartDay;
    final fired = ref.watch(reminderEngineProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Sounds off for a new server-side notification (friend request,
    // invite response, someone changing a shared event, etc. — see
    // formatServerNotification) the moment the 30s poll (initState) turns
    // up something newer than the last one already sounded for. A separate
    // concern from the bell's unseen-count badge above, which only tracks
    // what the user has visually looked at.
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(notificationsProvider, (previous, next) {
      final notifications = next.valueOrNull;
      if (notifications == null || notifications.isEmpty) return;
      final newest = DateTime.parse(notifications.first['createdAt'] as String);
      final cutoff = _lastSoundedNotificationAt;
      _lastSoundedNotificationAt = newest;
      if (cutoff == null) return;
      if (newest.isAfter(cutoff) && ref.read(settingsControllerProvider).notificationSoundEnabled) {
        SystemSound.play(SystemSoundType.alert);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(theme, l10n),
            Expanded(
              child: eventsAsync.when(
                data: (events) => _buildBody(events, weekStartDay, fired, l10n),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text(l10n.eventsLoadError(error.toString()))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(l10n.calendarTitle, style: theme.textTheme.titleMedium),
          const Spacer(),
          _buildNotificationsButton(theme, l10n),
          _buildSocialButton(theme, l10n),
          IconButton(
            tooltip: l10n.tooltipAssistant,
            icon: const Icon(Icons.smart_toy_outlined, size: 18),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
          ),
          IconButton(
            tooltip: l10n.tooltipSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            tooltip: l10n.tooltipSignOut,
            icon: const Icon(Icons.logout, size: 18),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          IconButton(
            tooltip: l10n.tooltipHideEsc,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => AppWindowController.instance.toggleVisibility(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsButton(ThemeData theme, AppLocalizations l10n) {
    final List<FiredReminder> fired = ref.watch(reminderEngineProvider);
    final serverNotifications =
        ref.watch(notificationsProvider).valueOrNull ?? const [];

    final items = <NotificationItem>[
      for (final entry in fired)
        NotificationItem(message: entry.message(l10n), time: entry.firedAt),
      for (final notification in serverNotifications)
        NotificationItem(
          message: formatServerNotification(notification, l10n),
          time: DateTime.parse(notification['createdAt'] as String).toLocal(),
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    final unseenCount = items
        .where((i) => i.time.isAfter(_notificationsSeenAt))
        .length;

    return PopupMenuButton<String>(
      tooltip: l10n.tooltipNotifications,
      onOpened: () => setState(() => _notificationsSeenAt = DateTime.now()),
      onSelected: (value) {
        if (value == 'view_all') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        }
      },
      itemBuilder: (context) => [
        if (items.isEmpty)
          PopupMenuItem(enabled: false, child: Text(l10n.noNotificationsYet))
        else
          for (final item in items.take(10))
            PopupMenuItem(
              enabled: false,
              child: SizedBox(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.message,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      DateFormat.MMMd().add_jm().format(item.time),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'view_all',
          child: Row(
            children: [
              const Icon(Icons.history, size: 16),
              const SizedBox(width: 8),
              Text(l10n.actionViewAllNotifications),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Badge(
          isLabelVisible: unseenCount > 0,
          label: Text('$unseenCount'),
          child: const Icon(Icons.notifications_outlined, size: 18),
        ),
      ),
    );
  }

  Widget _buildSocialButton(ThemeData theme, AppLocalizations l10n) {
    final pendingInvites =
        ref.watch(pendingEventInvitesProvider).valueOrNull ?? const [];
    final incomingRequests =
        ref.watch(incomingFriendRequestsProvider).valueOrNull ?? const [];
    final badgeCount = pendingInvites.length + incomingRequests.length;

    return IconButton(
      tooltip: l10n.tooltipFriendsGroups,
      icon: Badge(
        isLabelVisible: badgeCount > 0,
        label: Text('$badgeCount'),
        child: const Icon(Icons.people_outline, size: 18),
      ),
      // Tapping an invite in the Invites tab pops SocialScreen with that
      // invite's day instead of resolving it there (see _EventInvitesTab) —
      // jump the calendar to it so the pending-invite tile is right there
      // to accept/decline.
      onPressed: () async {
        final targetDay = await Navigator.of(context).push<DateTime>(
          MaterialPageRoute(builder: (_) => const SocialScreen()),
        );
        if (targetDay != null) _goToDay(targetDay);
      },
    );
  }

  Widget _buildMonthHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _goToPreviousMonth,
          ),
          Expanded(
            child: Center(
              child: TextButton(
                onPressed: () => _pickMonthYear(l10n),
                child: Text(
                  DateFormat.yMMMM().format(_focusedDay),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _goToNextMonth,
          ),
        ],
      ),
    );
  }

  void _goToPreviousMonth() =>
      _goToMonth(DateTime(_focusedDay.year, _focusedDay.month - 1, 1));

  void _goToNextMonth() =>
      _goToMonth(DateTime(_focusedDay.year, _focusedDay.month + 1, 1));

  void _goToMonth(DateTime month) {
    setState(() {
      _focusedDay = month;
      _selectedDay = month;
    });
    ref.read(visibleMonthProvider.notifier).state = month;
  }

  // Jumps straight to a specific day (as opposed to _goToMonth, which always
  // lands on the 1st) — used to bring a pending invite's day into view when
  // the user taps it from the Invites tab instead of resolving it there
  // (see _buildSocialButton).
  void _goToDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    setState(() {
      _focusedDay = normalized;
      _selectedDay = normalized;
    });
    ref.read(visibleMonthProvider.notifier).state = normalized;
  }

  Future<void> _pickMonthYear(AppLocalizations l10n) async {
    int selectedMonth = _focusedDay.month;
    int selectedYear = _focusedDay.year;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(l10n.goToMonthTitle),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: selectedMonth,
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (month) => DropdownMenuItem(
                            value: month,
                            child: Text(
                              DateFormat.MMMM().format(DateTime(2024, month)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedMonth = value!),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: selectedYear,
                    items: List.generate(21, (i) => 2020 + i)
                        .map(
                          (year) => DropdownMenuItem(
                            value: year,
                            child: Text('$year'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedYear = value!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.actionCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(DateTime(selectedYear, selectedMonth, 1)),
                  child: Text(l10n.actionGo),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) _goToMonth(result);
  }

  Widget _buildBody(
    List<Event> events,
    WeekStartDay weekStartDay,
    List<FiredReminder> fired,
    AppLocalizations l10n,
  ) {
    final gridRange = gridRangeForMonth(_focusedDay, weekStartDay);

    final timedByDay = <DateTime, List<EventOccurrence>>{};
    final looseByDay = <DateTime, List<Event>>{};
    final backlog = <Event>[];

    for (final event in events) {
      if (event.startTime != null) {
        final occurrences = expandEventOccurrences(
          event,
          rangeStart: gridRange.start,
          rangeEndExclusive: gridRange.endExclusive,
        );
        for (final occurrence in occurrences) {
          final day = DateTime(
            occurrence.start.year,
            occurrence.start.month,
            occurrence.start.day,
          );
          timedByDay.putIfAbsent(day, () => []).add(occurrence);
        }
        continue;
      }

      final date = event.assignedDate;
      if (date == null) {
        backlog.add(event);
        continue;
      }
      final key = DateTime(date.year, date.month, date.day);
      looseByDay.putIfAbsent(key, () => []).add(event);
    }

    // Manually-ordered items (drag-to-reorder) sort by that position first;
    // anything never touched falls back to creation order, after all of them.
    backlog.sort((a, b) {
      final orderA = a.backlogOrder;
      final orderB = b.backlogOrder;
      if (orderA != null && orderB != null) return orderA.compareTo(orderB);
      if (orderA != null) return -1;
      if (orderB != null) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });

    final selectedDayKey = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final selectedDayTimed = timedByDay[selectedDayKey] ?? [];
    final selectedDayLoose = looseByDay[selectedDayKey] ?? [];

    return Column(
      children: [
        _buildMonthHeader(l10n),
        TableCalendar<void>(
          locale: Localizations.localeOf(context).languageCode,
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _focusedDay,
          daysOfWeekHeight: 20,
          rowHeight: 40,
          headerVisible: false,
          startingDayOfWeek: weekStartDay == WeekStartDay.monday
              ? StartingDayOfWeek.monday
              : StartingDayOfWeek.sunday,
          selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) =>
                _dayCellBuilder(context, day),
            todayBuilder: (context, day, focusedDay) => _dayCellBuilder(
              context,
              day,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              textStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            selectedBuilder: (context, day, focusedDay) => _dayCellBuilder(
              context,
              day,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              textStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            outsideBuilder: (context, day, focusedDay) => _dayCellBuilder(
              context,
              day,
              textStyle: TextStyle(color: Colors.grey.shade400),
            ),
            markerBuilder: (context, day, _) =>
                _buildDayMarkers(context, day, timedByDay, looseByDay),
          ),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
            ref.read(visibleMonthProvider.notifier).state = focusedDay;
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _buildDayAgenda(
                  selectedDayTimed,
                  selectedDayLoose,
                  fired,
                  l10n,
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildBacklogPanel(backlog, l10n)),
            ],
          ),
        ),
      ],
    );
  }

  // A day with a pending invite always shows its mail badge dead-center —
  // not the group of markers as a whole, the badge itself — with any normal
  // event dots trailing off to its right. Achieved by mirroring the dots'
  // width as invisible space on the left: a Row that's symmetric around the
  // badge centers *it* when the whole (fixed-size) Row is centered, without
  // needing to know the day cell's actual pixel width. A day with no
  // pending invite just gets the plain centered dot row, as before.
  Widget? _buildDayMarkers(
    BuildContext context,
    DateTime day,
    Map<DateTime, List<EventOccurrence>> timedByDay,
    Map<DateTime, List<Event>> looseByDay,
  ) {
    final key = DateTime(day.year, day.month, day.day);
    final dayTimed = timedByDay[key] ?? const <EventOccurrence>[];
    final dayLoose = looseByDay[key] ?? const <Event>[];

    // A still-pending invite is represented by the mail badge instead of a
    // normal dot — it isn't "my" event yet, just something waiting on a
    // response, so mixing it into the plain dot row would make it look like
    // a committed event before the user's even seen it.
    final dotIds = [
      ...dayTimed
          .where((e) => e.master.myRole != 'invited')
          .map((e) => e.master.id),
      ...dayLoose.where((e) => e.myRole != 'invited').map((e) => e.id),
    ];
    final hasPendingInvite =
        dayTimed.any((e) => e.master.myRole == 'invited') ||
        dayLoose.any((e) => e.myRole == 'invited');

    if (dotIds.isEmpty && !hasPendingInvite) return null;

    const dotSize = 5.0;
    const dotSpacing = 2.0;
    const mailSize = 11.0;
    const mailGap = 4.0;

    final shownDots = dotIds.take(3).toList();
    Widget dot(String id) => Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: colorForEvent(id),
        shape: BoxShape.circle,
      ),
    );

    if (!hasPendingInvite) {
      return Positioned(
        bottom: 1,
        left: 0,
        right: 0,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final id in shownDots)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: dotSpacing / 2,
                  ),
                  child: dot(id),
                ),
            ],
          ),
        ),
      );
    }

    final mailBadge = Container(
      width: mailSize,
      height: mailSize,
      decoration: BoxDecoration(
        color: Colors.blue.shade400,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 1,
        ),
      ),
      child: const Icon(Icons.mail_outline, size: 7, color: Colors.white),
    );

    // Total width of everything trailing the badge on the right, mirrored
    // as blank space on the left so the badge itself lands at true center.
    // Each dot's own symmetric padding (see `dot` above) means it occupies
    // dotSize + dotSpacing, not just dotSize.
    final trailingWidth = shownDots.isEmpty
        ? 0.0
        : mailGap + shownDots.length * (dotSize + dotSpacing);

    return Positioned(
      bottom: 1,
      left: 0,
      right: 0,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: trailingWidth),
            mailBadge,
            if (shownDots.isNotEmpty) SizedBox(width: mailGap),
            for (final id in shownDots)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: dotSpacing / 2),
                child: dot(id),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dayCellBuilder(
    BuildContext context,
    DateTime day, {
    BoxDecoration? decoration,
    TextStyle? textStyle,
  }) {
    return DragTarget<Event>(
      onAcceptWithDetails: (details) => _onItemDroppedOnDay(details.data, day),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.all(2),
          decoration: isHovering
              ? BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(38),
                  shape: BoxShape.circle,
                )
              : decoration,
          alignment: Alignment.center,
          child: Text('${day.day}', style: textStyle),
        );
      },
    );
  }

  /// Dispatches a drag-and-drop onto [day]. A timed event keeps its time and
  /// just moves date; a loose or backlog task is assigned to [day] with no
  /// time. Dropping a backlog idea onto a day also opens the edit form right
  /// away, so the user can flesh it out (description, a specific time) on
  /// the spot instead of it silently becoming a bare loose item.
  Future<void> _onItemDroppedOnDay(Event event, DateTime day) async {
    // Recurring event tiles aren't wrapped in a Draggable, so this shouldn't
    // be reachable — kept as a safety net against moving a whole series by
    // accident, which would be ambiguous (move the pattern? just one day?).
    if (event.rrule != null) return;

    if (event.startTime != null) {
      await _moveTimedEventToDay(event, day);
      return;
    }

    final wasBacklog = event.assignedDate == null;
    await ref.read(eventsRepositoryProvider).assignToDay(event.id, day);
    if (!wasBacklog || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(
          existingEvent: event.copyWith(assignedDate: Value(day)),
        ),
      ),
    );
  }

  Future<void> _moveTimedEventToDay(Event event, DateTime day) async {
    final start = event.startTime!;
    final newStart = DateTime(
      day.year,
      day.month,
      day.day,
      start.hour,
      start.minute,
    );
    DateTime? newEnd;
    final end = event.endTime;
    if (end != null) {
      newEnd = newStart.add(end.difference(start));
    }

    await ref
        .read(eventsRepositoryProvider)
        .updateEvent(event.id, startTime: newStart, endTime: newEnd);
  }

  Widget _buildDayAgenda(
    List<EventOccurrence> timed,
    List<Event> loose,
    List<FiredReminder> fired,
    AppLocalizations l10n,
  ) {
    final timedEntries = timed.map(_AgendaEntry.timed).toList()
      ..sort((a, b) => a.start!.compareTo(b.start!));
    final looseEntries = loose.map(_AgendaEntry.loose).toList();
    final isEmpty = looseEntries.isEmpty && timedEntries.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
          child: Row(
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat.yMMMEd().format(_selectedDay),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              IconButton.filled(
                tooltip: l10n.tooltipAddEvent,
                icon: const Icon(Icons.add, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventFormScreen(initialDay: _selectedDay),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: isEmpty
              ? Center(
                  child: Text(
                    l10n.noEventsOnThisDay,
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : _FadingList(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    if (looseEntries.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                        child: Text(
                          l10n.anytime,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      ...looseEntries.map(
                        (entry) => _buildAgendaTile(entry, fired, l10n),
                      ),
                    ],
                    ...timedEntries.map(
                      (entry) => _buildAgendaTile(entry, fired, l10n),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAgendaTile(
    _AgendaEntry entry,
    List<FiredReminder> fired,
    AppLocalizations l10n,
  ) {
    final isPendingInvite = entry.event.myRole == 'invited';

    final now = DateTime.now();
    final start = entry.start;
    final end = entry.end;
    // A not-yet-accepted invite gets its own distinct styling below instead
    // — "happening now"/reminder highlighting is for events the user has
    // actually taken on.
    final isHappeningNow =
        !isPendingInvite &&
        !entry.isLoose &&
        start != null &&
        end != null &&
        !now.isBefore(start) &&
        now.isBefore(end);
    // "Happening now" takes precedence — once the event's actually started,
    // knowing its reminder fired earlier isn't the interesting fact anymore.
    // Reminders only exist on timed events (see assertScheduleConsistent on
    // the backend), and firedAt/occurrenceStart pin this to the exact
    // occurrence, so a recurring series only highlights the instance that
    // actually fired.
    final hasFiredReminder =
        !isHappeningNow &&
        !entry.isLoose &&
        start != null &&
        now.isBefore(end ?? start.add(const Duration(hours: 1))) &&
        fired.any(
          (f) => f.eventId == entry.event.id && f.occurrenceStart == start,
        );

    return _AgendaTile(
      title: entry.title,
      subtitle: entry.isLoose
          ? l10n.anytime
          : _formatRange(
              entry.start!,
              entry.end,
              isAllDay: entry.isAllDay,
              l10n: l10n,
            ),
      colorId: entry.id,
      isPending: entry.isPending,
      isRecurring: entry.isRecurring,
      isLoose: entry.isLoose,
      hasDescription: entry.hasDescription,
      isHappeningNow: isHappeningNow,
      hasFiredReminder: hasFiredReminder,
      isShared: entry.event.myRole != 'owner',
      isPendingInvite: isPendingInvite,
      ownerName: entry.event.ownerDisplayName,
      draggable: !entry.isRecurring && !isPendingInvite,
      dragData: entry.event,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => isPendingInvite
              ? PendingInviteScreen(event: entry.event)
              : EventFormScreen(
                  existingEvent: entry.event,
                  occurrenceStart: entry.isLoose ? null : entry.start,
                ),
        ),
      ),
    );
  }

  Widget _buildBacklogPanel(List<Event> backlog, AppLocalizations l10n) {
    return DragTarget<Event>(
      onAcceptWithDetails: (details) =>
          ref.read(eventsRepositoryProvider).moveToBacklog(details.data.id),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          color: isHovering
              ? Theme.of(context).colorScheme.primary.withAlpha(20)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.somedayHeader,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _quickAddController,
                  decoration: InputDecoration(
                    hintText: l10n.addSomedayHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    final text = value.trim();
                    if (text.isEmpty) return;
                    ref.read(eventsRepositoryProvider).createQuickTask(text);
                    _quickAddController.clear();
                  },
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: backlog.isEmpty
                    ? Center(
                        child: Text(
                          l10n.dragIdeasHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      )
                    // Reordering here is a distinct drag affordance from each
                    // chip's own Draggable<Event> (drag OUT onto a calendar
                    // day) — see _BacklogChip's drag_indicator handle, which
                    // is the only thing wired to onReorder below.
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        buildDefaultDragHandles: false,
                        itemCount: backlog.length,
                        onReorderItem: (oldIndex, newIndex) =>
                            _reorderBacklog(backlog, oldIndex, newIndex),
                        itemBuilder: (context, index) => _BacklogChip(
                          key: ValueKey(backlog[index].id),
                          event: backlog[index],
                          index: index,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Recomputes a full 0..N-1 order for the whole backlog rather than trying
  // to slot the moved item between its new neighbors — simplest scheme given
  // these lists are always small, and it keeps every item's backlogOrder
  // dense/unambiguous instead of needing fractional/gap-based positions.
  void _reorderBacklog(List<Event> backlog, int oldIndex, int newIndex) {
    final reordered = List<Event>.of(backlog);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final repository = ref.read(eventsRepositoryProvider);
    for (var i = 0; i < reordered.length; i++) {
      repository.updateEvent(reordered[i].id, backlogOrder: i);
    }
  }

  String _formatRange(
    DateTime start,
    DateTime? end, {
    required bool isAllDay,
    required AppLocalizations l10n,
  }) {
    if (isAllDay) return l10n.allDay;
    String two(int n) => n.toString().padLeft(2, '0');
    final startStr = '${two(start.hour)}:${two(start.minute)}';
    if (end == null) return l10n.durationTbd(startStr);
    return '$startStr - ${two(end.hour)}:${two(end.minute)}';
  }
}

/// Normalizes a timed occurrence or a loose task into one shape so the day
/// agenda can render and sort them together.
class _AgendaEntry {
  _AgendaEntry.timed(EventOccurrence occurrence)
    : event = occurrence.master,
      start = occurrence.start,
      end = occurrence.end,
      isLoose = false;

  _AgendaEntry.loose(this.event) : start = null, end = null, isLoose = true;

  final Event event;
  final DateTime? start;
  final DateTime? end;
  final bool isLoose;

  String get id => event.id;
  String get title => event.title;
  bool get isAllDay => event.isAllDay;
  bool get isPending => event.pendingOperation != null;
  bool get isRecurring => event.rrule != null;
  bool get hasDescription => (event.description ?? '').trim().isNotEmpty;
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({
    required this.title,
    required this.subtitle,
    required this.colorId,
    required this.isPending,
    required this.dragData,
    required this.onTap,
    this.isRecurring = false,
    this.isLoose = false,
    this.hasDescription = false,
    this.draggable = true,
    this.isHappeningNow = false,
    this.hasFiredReminder = false,
    this.isShared = false,
    this.isPendingInvite = false,
    this.ownerName,
  });

  final String title;
  final String subtitle;
  final String colorId;
  final bool isPending;
  final bool isRecurring;
  final bool isLoose;
  final bool hasDescription;
  final bool draggable;
  // Mutually exclusive (see _buildAgendaTile) — a timed event currently
  // between its start/end, vs. one whose reminder fired but hasn't started
  // (or has no end) yet. Different colors so the two states read distinctly
  // at a glance rather than just "something about this one is special".
  final bool isHappeningNow;
  final bool hasFiredReminder;
  // True when this task belongs to someone else and was shared with the
  // current user (myRole != 'owner') — surfaced as a small icon so a task
  // someone else added is obviously distinct from the user's own, without
  // having to open it first.
  final bool isShared;
  // True for a still-pending invite (myRole == 'invited') — takes over the
  // tile's whole appearance (see build below) rather than just adding an
  // icon, since this isn't "my" task yet at all, just something waiting on
  // a yes/no from the user.
  final bool isPendingInvite;
  final String? ownerName;
  final Event dragData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorForEvent(colorId);
    final l10n = AppLocalizations.of(context)!;
    final highlightColor = isHappeningNow
        ? Colors.green
        : hasFiredReminder
        ? Colors.amber.shade800
        : null;

    // Loose (no specific time) tasks render as a light, outlined chip —
    // visually distinct from a fully-scheduled tile with a solid color bar,
    // so it's obvious at a glance which tasks are still just placeholders.
    // A highlight (happening now / reminder fired) takes priority over that
    // styling, but loose tasks never carry one anyway (see _buildAgendaTile).
    // A pending invite overrides all of the above — see isPendingInvite.
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: isPendingInvite
            ? BoxDecoration(
                border: Border.all(color: Colors.blue.shade300, width: 1.2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue.withAlpha(14),
              )
            : highlightColor != null
            ? BoxDecoration(
                border: Border.all(color: highlightColor),
                borderRadius: BorderRadius.circular(8),
                color: highlightColor.withAlpha(28),
              )
            : isLoose
            ? BoxDecoration(
                border: Border.all(color: color.withAlpha(160)),
                borderRadius: BorderRadius.circular(8),
                color: color.withAlpha(12),
              )
            : null,
        child: Row(
          children: [
            if (isPendingInvite)
              Icon(Icons.mail_outline, size: 18, color: Colors.blue.shade400)
            else if (isLoose)
              Icon(Icons.circle_outlined, size: 14, color: color)
            else
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isLoose ? FontWeight.normal : FontWeight.w500,
                      fontStyle: isLoose ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  Text(
                    isPendingInvite
                        ? (ownerName != null
                              ? l10n.sharedByOwner(ownerName!)
                              : l10n.pendingInviteBadge)
                        : subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPendingInvite
                          ? Colors.blue.shade400
                          : Colors.grey.shade600,
                      fontWeight: isPendingInvite
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (isShared && !isPendingInvite)
              Tooltip(
                message: ownerName != null
                    ? l10n.tooltipSharedEvent(ownerName!)
                    : l10n.sharedWithYou,
                child: Icon(
                  Icons.group_outlined,
                  size: 15,
                  color: Colors.blue.shade400,
                ),
              ),
            if (hasDescription)
              Tooltip(
                message: l10n.tooltipHasDescription,
                child: Icon(Icons.notes, size: 15, color: Colors.grey.shade500),
              ),
            if (isRecurring)
              Tooltip(
                message: l10n.tooltipRepeats,
                child: Icon(
                  Icons.repeat,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              ),
            if (isPending)
              Tooltip(
                message: l10n.tooltipNotSynced,
                child: Icon(
                  Icons.cloud_off,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );

    if (!draggable) return content;

    // A plain (not long-press) drag, matching the backlog chips — the inner
    // InkWell still gets a clean tap when the pointer doesn't move far
    // enough to count as a drag, so quick taps keep opening the edit form.
    return Draggable<Event>(
      data: dragData,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 220, child: content),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: content),
      child: content,
    );
  }
}

/// A [ListView] with a fade-to-background hint at the bottom edge that only
/// appears while there's more content below the visible area.
class _FadingList extends StatefulWidget {
  const _FadingList({required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  State<_FadingList> createState() => _FadingListState();
}

class _FadingListState extends State<_FadingList> {
  final _controller = ScrollController();
  bool _hasMoreBelow = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
  }

  @override
  void didUpdateWidget(covariant _FadingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The list content (e.g. selected day, backlog) may have changed size
    // without a scroll event, so re-check after the new layout settles.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
  }

  void _updateFade() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final hasMore =
        position.maxScrollExtent > 0 &&
        position.pixels < position.maxScrollExtent - 2;
    if (hasMore != _hasMoreBelow && mounted) {
      setState(() => _hasMoreBelow = hasMore);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          controller: _controller,
          padding: widget.padding,
          children: widget.children,
        ),
        if (_hasMoreBelow)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 20,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).scaffoldBackgroundColor.withAlpha(0),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BacklogChip extends ConsumerWidget {
  const _BacklogChip({super.key, required this.event, required this.index});

  final Event event;
  // Position within the currently-displayed backlog list — only used to
  // wire up the drag_indicator handle to ReorderableListView's onReorder;
  // unrelated to backlogOrder itself, which is recomputed for the whole
  // list once a drag actually completes (see _reorderBacklog).
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorForEvent(event.id);
    final hasDescription = (event.description ?? '').trim().isNotEmpty;
    final isPendingInvite = event.myRole == 'invited';
    final l10n = AppLocalizations.of(context)!;

    final content = Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPendingInvite ? Colors.blue.shade300 : color,
        ),
        borderRadius: BorderRadius.circular(6),
        color: isPendingInvite ? Colors.blue.withAlpha(14) : null,
      ),
      child: Row(
        children: [
          // A separate drag affordance from the rest of the chip (which
          // stays a Draggable<Event> for dragging OUT onto a calendar day)
          // — grabbing this handle instead reorders within this list. A
          // still-pending invite can't be scheduled until accepted, so it
          // skips both drag affordances (see the outer Draggable below too).
          if (!isPendingInvite)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: l10n.pendingInviteBadge,
                child: Icon(
                  Icons.mail_outline,
                  size: 14,
                  color: Colors.blue.shade400,
                ),
              ),
            ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => isPendingInvite
                      ? PendingInviteScreen(event: event)
                      : EventFormScreen(existingEvent: event),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          fontWeight: isPendingInvite
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isPendingInvite ? Colors.blue.shade400 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (event.myRole != 'owner' && !isPendingInvite)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message: event.ownerDisplayName != null
                              ? l10n.tooltipSharedEvent(event.ownerDisplayName!)
                              : l10n.sharedWithYou,
                          child: Icon(
                            Icons.group_outlined,
                            size: 12,
                            color: Colors.blue.shade400,
                          ),
                        ),
                      ),
                    if (hasDescription)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.notes,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    if (event.pendingOperation != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.cloud_off,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    // Deleting is owner-only server-side (see
                    // EventsService.remove / findOwnedOrThrow) — any
                    // accepted invitee can change an event's
                    // content/schedule but not remove it entirely.
                    if (event.myRole == 'owner')
                      InkWell(
                        onTap: () => ref
                            .read(eventsRepositoryProvider)
                            .deleteEvent(event.id),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isPendingInvite) return content;

    return Draggable<Event>(
      data: event,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 200, child: content),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: content),
      child: content,
    );
  }
}
