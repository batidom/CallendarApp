import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';

import '../data/local/app_database.dart';
import '../l10n/generated/app_localizations.dart';
import '../repositories/events_repository.dart';
import '../utils/app_locale.dart';
import '../utils/recurrence.dart';
import '../utils/reminders.dart';
import 'app_settings.dart';
import 'notification_popup.dart';
import 'reminder_sound_player.dart';

// Popup windows (desktop_multi_window) and native OS notifications
// (local_notifier) only support Windows/macOS/Linux; on mobile a fired
// reminder still shows in the in-app history/badge, and sound alone.
bool get _supportsDesktopNotifications => !(Platform.isAndroid || Platform.isIOS);

/// One reminder that has come due. This is our own in-app notification —
/// deliberately not an OS toast, since the user wants a dedicated in-app
/// system (with more channels/styling to come once there's a settings panel).
class FiredReminder {
  const FiredReminder({
    required this.key,
    required this.eventId,
    required this.eventTitle,
    required this.occurrenceStart,
    required this.minutesBefore,
    required this.firedAt,
  });

  final String key;
  final String eventId;
  final String eventTitle;
  final DateTime occurrenceStart;
  final int minutesBefore;
  final DateTime firedAt;

  String message(AppLocalizations l10n) => minutesBefore == 0
      ? l10n.reminderStartingNow(eventTitle)
      : l10n.reminderWithLabel(eventTitle, reminderLabel(minutesBefore, l10n).toLowerCase());
}

const _scanInterval = Duration(seconds: 20);
// On a cold start, only fire reminders that became due within this window —
// otherwise a long-overdue recurring reminder would dump a burst of stale
// notifications the moment the app opens.
const _startupLookback = Duration(minutes: 2);
const _maxHistory = 30;

/// Periodically expands every event with at least one reminder into its
/// upcoming occurrences and fires any reminder whose due time has just
/// passed. State is the recent-notifications history, newest first.
class ReminderEngine extends StateNotifier<List<FiredReminder>> {
  ReminderEngine(this._repository, this._settings) : super(const []) {
    _subscription = _repository.watchEventsWithReminders().listen((events) {
      _events = events;
      _scan();
    });
    _timer = Timer.periodic(_scanInterval, (_) => _scan());
  }

  final EventsRepository _repository;
  // Held onto (not watched) so a settings change doesn't rebuild the whole
  // engine — `.state` is simply read fresh each time a reminder fires.
  final SettingsController _settings;
  StreamSubscription<List<Event>>? _subscription;
  Timer? _timer;
  List<Event> _events = const [];
  final Set<String> _firedKeys = {};
  DateTime? _lastScan;

  void _scan() {
    final now = DateTime.now();
    final earliestDue = _lastScan ?? now.subtract(_startupLookback);
    final newlyFired = <FiredReminder>[];

    for (final event in _events) {
      // A still-pending invite (see EventsService.myInviteFields) is now
      // visible on the calendar (see calendar_screen.dart's pending-invite
      // tile) but hasn't been accepted — firing a reminder for it would be
      // reminding the user about something they haven't agreed to yet.
      if (event.myRole == 'invited') continue;

      final minutesList = decodeReminderMinutes(event.reminderMinutes);
      if (minutesList.isEmpty) continue;

      final maxMinutesBefore = minutesList.reduce((a, b) => a > b ? a : b);
      final occurrences = expandEventOccurrences(
        event,
        rangeStart: now.subtract(_startupLookback),
        rangeEndExclusive: now.add(Duration(minutes: maxMinutesBefore + 2)),
      );

      for (final occurrence in occurrences) {
        for (final minutesBefore in minutesList) {
          final dueAt = occurrence.start.subtract(Duration(minutes: minutesBefore));
          if (dueAt.isAfter(now) || !dueAt.isAfter(earliestDue)) continue;

          final key = '${event.id}|${occurrence.start.toIso8601String()}|$minutesBefore';
          if (_firedKeys.add(key)) {
            newlyFired.add(FiredReminder(
              key: key,
              eventId: event.id,
              eventTitle: event.title,
              occurrenceStart: occurrence.start,
              minutesBefore: minutesBefore,
              firedAt: now,
            ));
          }
        }
      }
    }

    _lastScan = now;
    if (newlyFired.isNotEmpty) {
      state = [...newlyFired, ...state].take(_maxHistory).toList();
      _announce(newlyFired);
    }
  }

  void _announce(List<FiredReminder> fired) {
    final settings = _settings.state;
    if (!settings.notificationsEnabled) return;

    unawaited(playReminderSound(settings));

    if (!_supportsDesktopNotifications) return;

    final l10n = resolveL10n(settings.language);
    for (final reminder in fired) {
      // Best-effort: a failed popup/notification shouldn't take down the
      // reminder engine, and it's still visible via the sound + history/badge.
      if (settings.notificationChannel == NotificationChannel.system) {
        unawaited(
          LocalNotification(title: reminder.eventTitle, body: reminder.message(l10n))
              .show()
              .catchError((_) {}),
        );
      } else {
        unawaited(
          spawnReminderPopup(
            title: reminder.eventTitle,
            message: reminder.message(l10n),
            corner: settings.popupCorner,
            durationSeconds: settings.popupDurationSeconds,
          ).catchError((_) {}),
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
