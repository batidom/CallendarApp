import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/local/app_database.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/auth_token_storage.dart';
import '../utils/recurrence.dart';
import '../utils/reminders.dart';

const _uuid = Uuid();

/// A single unified "task": a pure backlog idea (no [Event.assignedDate], no
/// [Event.startTime]), a loose item for a specific day ([Event.assignedDate]
/// set, [Event.startTime] still null), or a fully timed event
/// ([Event.startTime]/[Event.endTime] set). See app_database.dart for the
/// full state-machine explanation.
class EventsRepository {
  EventsRepository(this._apiClient, this._database, this._tokenStorage);

  final ApiClient _apiClient;
  final AppDatabase _database;
  final AuthTokenStorage _tokenStorage;

  Stream<List<Event>> watchRange(DateTime start, DateTime end) =>
      _database.watchEventsInRange(start, end);

  /// All events with at least one reminder, regardless of date — used by the
  /// reminder engine, which needs to scan far beyond whatever range the
  /// calendar UI currently has visible.
  Stream<List<Event>> watchEventsWithReminders() => _database.watchAllEvents();

  Future<void> refreshRange(DateTime start, DateTime end) async {
    final serverEvents = await _apiClient.fetchEvents(start: start, end: end);
    final rows = serverEvents.map(_toCompanion).toList();
    await _database.replaceRangeWithServerEvents(start, end, rows);
  }

  /// Writes the new event to the local database immediately (so the UI
  /// updates instantly regardless of connectivity), then best-effort syncs
  /// it to the server in the background. Everything but [title] is
  /// optional — a bare `createEvent(title: ...)` creates a backlog idea.
  Future<void> createEvent({
    required String title,
    String? description,
    String? location,
    DateTime? assignedDate,
    DateTime? startTime,
    DateTime? endTime,
    bool isAllDay = false,
    String? rrule,
    List<int> reminderMinutes = const [],
    // Set together to create a standalone "this event only" override of one
    // occurrence of a recurring series — see EventsRepository.excludeOccurrence.
    String? recurrenceOverrideOf,
    DateTime? originalOccurrenceStart,
    // Callers that need to know the id before this returns (e.g. the event
    // form, which stages invites against it before the event is even saved)
    // can supply it themselves instead of letting one be generated here.
    String? id,
  }) async {
    final userId = await _tokenStorage.readUserId();
    final now = DateTime.now();
    final eventId = id ?? _uuid.v4();

    await _database.upsertLocalEvent(EventsCompanion.insert(
      id: eventId,
      userId: userId ?? '',
      title: title,
      description: Value(description),
      location: Value(location),
      assignedDate: Value(assignedDate),
      startTime: Value(startTime),
      endTime: Value(endTime),
      isAllDay: Value(isAllDay),
      rrule: Value(rrule),
      reminderMinutes: Value(encodeReminderMinutes(reminderMinutes)),
      recurrenceOverrideOf: Value(recurrenceOverrideOf),
      originalOccurrenceStart: Value(originalOccurrenceStart),
      createdAt: now,
      updatedAt: now,
      pendingOperation: const Value('create'),
    ));

    unawaited(_syncEvent(eventId));
  }

  /// Adds a new backlog idea with no day or time attached — the quick-add
  /// box doesn't force the user to fill in anything beyond a title.
  Future<void> createQuickTask(String title) => createEvent(title: title);

  /// Merges [changes] into the local row immediately, then best-effort
  /// syncs it to the server in the background.
  Future<void> updateEvent(
    String id, {
    String? title,
    String? description,
    // description can't distinguish "leave unchanged" from "cleared it out"
    // since both are null; this flag disambiguates the latter for callers
    // (the event form) that always know the full field state.
    bool clearDescription = false,
    String? location,
    // Same reasoning as clearDescription above.
    bool clearLocation = false,
    DateTime? assignedDate,
    DateTime? startTime,
    DateTime? endTime,
    // Clears assignedDate/startTime/endTime together, moving the task back
    // to the unscheduled backlog. Takes priority over the individual
    // date/time params above.
    bool clearSchedule = false,
    // Clears startTime/endTime only (assignedDate is left as given/unchanged)
    // — used when a task keeps its day but drops its specific time, going
    // from "timed" to "loose for that day".
    bool clearTime = false,
    bool? isAllDay,
    String? rrule,
    // rrule can't distinguish "leave unchanged" from "no longer repeats"
    // since both are represented as null; this flag disambiguates the
    // latter for callers (the event form) that always know the full
    // recurrence state, vs. partial updates (e.g. drag-to-reschedule) that
    // only touch a date and want everything else left alone.
    bool clearRrule = false,
    // Unlike rrule, a reminder set can naturally represent "leave unchanged"
    // (null) vs. "replace with this list, possibly empty" (non-null) without
    // an extra flag, since List<int> has room for both states.
    List<int>? reminderMinutes,
    // Full replacement encoded string — callers (currently only
    // excludeOccurrence) always compute the complete new list themselves.
    String? excludedOccurrences,
    // Drag-to-reorder position within the "Someday" backlog panel — 0 is a
    // legit position, so unlike title/rrule there's no clear-flag needed:
    // omitting this param just leaves the existing order untouched.
    int? backlogOrder,
  }) async {
    final existing = await _database.findEventById(id);
    if (existing == null) return;

    // A row that was never synced is still a pending *create*: syncing it
    // should still POST the latest values, not PUT to a resource the
    // server has never seen.
    final nextOperation = existing.pendingOperation == 'create' ? 'create' : 'update';

    final nextAssignedDate = clearSchedule ? null : (assignedDate ?? existing.assignedDate);
    final nextStartTime = (clearSchedule || clearTime) ? null : (startTime ?? existing.startTime);
    final nextEndTime = (clearSchedule || clearTime) ? null : (endTime ?? existing.endTime);

    await _database.upsertLocalEvent(EventsCompanion(
      id: Value(id),
      userId: Value(existing.userId),
      title: Value(title ?? existing.title),
      description: Value(clearDescription ? null : (description ?? existing.description)),
      location: Value(clearLocation ? null : (location ?? existing.location)),
      assignedDate: Value(nextAssignedDate),
      startTime: Value(nextStartTime),
      endTime: Value(nextEndTime),
      isAllDay: Value(isAllDay ?? existing.isAllDay),
      rrule: Value(clearRrule ? null : (rrule ?? existing.rrule)),
      reminderMinutes: Value(
        reminderMinutes != null ? encodeReminderMinutes(reminderMinutes) : existing.reminderMinutes,
      ),
      googleEventId: Value(existing.googleEventId),
      myRole: Value(existing.myRole),
      ownerDisplayName: Value(existing.ownerDisplayName),
      inviteId: Value(existing.inviteId),
      inviteStatus: Value(existing.inviteStatus),
      recurrenceOverrideOf: Value(existing.recurrenceOverrideOf),
      originalOccurrenceStart: Value(existing.originalOccurrenceStart),
      excludedOccurrences: Value(excludedOccurrences ?? existing.excludedOccurrences),
      backlogOrder: Value(backlogOrder ?? existing.backlogOrder),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(DateTime.now()),
      pendingOperation: Value(nextOperation),
    ));

    unawaited(_syncEvent(id));
  }

  /// Removes one occurrence of a recurring series (the "this event only"
  /// scope on delete, or on edit right before creating its override row) by
  /// adding its original start instant to the master's excluded list.
  Future<void> excludeOccurrence(String masterEventId, DateTime occurrenceStart) async {
    final existing = await _database.findEventById(masterEventId);
    if (existing == null) return;

    final excluded = decodeExcludedOccurrences(existing.excludedOccurrences)..add(occurrenceStart);
    await updateEvent(masterEventId, excludedOccurrences: encodeExcludedOccurrences(excluded));
  }

  /// Drags a task onto [day]. Pass [startTime]/[endTime] if the user also
  /// picked a specific time; otherwise it becomes (or stays) a loose item
  /// for that day, clearing any previous specific time.
  Future<void> assignToDay(
    String id,
    DateTime day, {
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return updateEvent(
      id,
      assignedDate: day,
      startTime: startTime,
      endTime: endTime,
      clearTime: startTime == null,
    );
  }

  /// Sends a task back to the unscheduled backlog.
  Future<void> moveToBacklog(String id) => updateEvent(id, clearSchedule: true);

  /// Responds to a still-pending invite for [eventId] directly from the
  /// calendar (see PendingInviteScreen) — the same action available from the
  /// Invites tab, just reachable from wherever the event is actually showing
  /// up. Online-only, not part of the offline-first queue: throws
  /// [ApiException] for the caller to surface, same as [leaveEvent].
  Future<void> respondToInvite(String eventId, String inviteId, bool accept) async {
    await _apiClient.respondToInvite(inviteId, accept);

    if (!accept) {
      // Declined — not "my" event anymore, and it won't come back on the
      // next refresh since the server excludes declined invites from range
      // fetches (see EventsService.findInRange).
      await _database.hardDeleteEvent(eventId);
      return;
    }

    // Accepted — flip the cached role locally right away instead of waiting
    // for the next periodic refresh, so the tile's "respond to this"
    // styling clears immediately.
    final existing = await _database.findEventById(eventId);
    if (existing == null) return;
    await _database.upsertLocalEvent(existing.toCompanion(true).copyWith(
      myRole: const Value('editor'),
      inviteStatus: const Value('accepted'),
      inviteId: const Value(null),
    ));
  }

  /// Leaves a shared event (removes the caller's own invite server-side,
  /// which also notifies the owner and every other current participant —
  /// see EventInvitesService.leave on the backend). Online-only, not part
  /// of the offline-first queue: throws [ApiException] for the caller to
  /// surface. On success, drops the local cached copy immediately — it's
  /// not "my" event anymore, and it won't come back on the next refresh
  /// since the server no longer includes it for this user.
  Future<void> leaveEvent(String eventId) async {
    await _apiClient.leaveEvent(eventId);
    await _database.hardDeleteEvent(eventId);
  }

  /// Removes the event locally immediately. If it had already reached the
  /// server, queues a deletion to push once connectivity allows; if it was
  /// only ever local (never synced), there's nothing to tell the server.
  Future<void> deleteEvent(String id) async {
    final existing = await _database.findEventById(id);
    final neverSynced = existing?.pendingOperation == 'create';

    // Deleting a recurring series' master also drops any per-occurrence
    // overrides it has locally. The server cascades this too once the
    // master's own deletion syncs, so there's nothing to queue for them.
    final overrides = await _database.findOverridesOf(id);
    for (final override in overrides) {
      await _database.hardDeleteEvent(override.id);
    }

    await _database.hardDeleteEvent(id);

    if (neverSynced) return;

    await _database.queuePendingDeletion(id, 'event');
    unawaited(_syncDeletion(id));
  }

  /// Pushes every queued create/update/delete to the server. Safe to call
  /// repeatedly (e.g. on connectivity restore, app start) — failures are
  /// swallowed and retried on the next call.
  Future<void> syncPendingChanges() async {
    final pending = await _database.pendingEvents();
    for (final event in pending) {
      await _syncEvent(event.id);
    }

    final pendingDeletions = await _database.pendingDeletionsOfType('event');
    for (final deletion in pendingDeletions) {
      await _syncDeletion(deletion.id);
    }
  }

  /// Forces an immediate (best-effort) push of a pending create/update
  /// instead of waiting for the usual fire-and-forget background sync —
  /// used when a caller is about to depend on the event actually existing
  /// server-side (e.g. sending invites right after creating a brand new
  /// event). Safe to call even if a background sync is already in flight;
  /// the server-side create is idempotent by id.
  Future<void> syncEventNow(String id) => _syncEvent(id);

  Future<void> _syncEvent(String id) async {
    try {
      final event = await _database.findEventById(id);
      if (event == null || event.pendingOperation == null) return;

      final body = {
        'title': event.title,
        // Sent unconditionally (including null) so clearing the description
        // actually clears it server-side too, instead of the next sync
        // response overwriting the local clear with the server's stale
        // value (same reasoning as assignedDate/startTime/endTime below).
        'description': event.description,
        'location': event.location,
        'assignedDate': _formatDateOnly(event.assignedDate),
        'startTime': event.startTime?.toUtc().toIso8601String(),
        'endTime': event.endTime?.toUtc().toIso8601String(),
        'isAllDay': event.isAllDay,
        'rrule': event.rrule,
        // Also sent unconditionally (including an empty list) so removing
        // all reminders actually clears them server-side.
        'reminders': decodeReminderMinutes(event.reminderMinutes),
        'excludedOccurrences': event.excludedOccurrences,
        'backlogOrder': event.backlogOrder,
      };

      // recurrenceOverrideOf/originalOccurrenceStart are identity fields set
      // once at creation (which slot this override replaces) — only sent on
      // the initial create, never touched by later updates.
      final json = event.pendingOperation == 'create'
          ? await _apiClient.createEvent({
              'id': event.id,
              'recurrenceOverrideOf': event.recurrenceOverrideOf,
              'originalOccurrenceStart': event.originalOccurrenceStart?.toUtc().toIso8601String(),
              ...body,
            })
          : await _apiClient.updateEvent(event.id, body);

      await _database.markEventSynced(id, _toCompanion(json));
    } catch (error) {
      debugPrint('Failed to sync event $id, will retry later: $error');
    }
  }

  Future<void> _syncDeletion(String id) async {
    try {
      await _apiClient.deleteEvent(id);
      await _database.clearPendingDeletion(id);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        // Already gone server-side; nothing left to do.
        await _database.clearPendingDeletion(id);
      } else {
        debugPrint('Failed to sync deletion of $id, will retry later: $error');
      }
    } catch (error) {
      debugPrint('Failed to sync deletion of $id, will retry later: $error');
    }
  }

  EventsCompanion _toCompanion(Map<String, dynamic> json) {
    return EventsCompanion.insert(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: Value(json['description'] as String?),
      location: Value(json['location'] as String?),
      assignedDate: Value(_parseDateOnly(json['assignedDate'])),
      startTime: Value(_parseNullableInstant(json['startTime'])),
      endTime: Value(_parseNullableInstant(json['endTime'])),
      isAllDay: Value(json['isAllDay'] as bool? ?? false),
      rrule: Value(json['rrule'] as String?),
      backlogOrder: Value(json['backlogOrder'] as int?),
      reminderMinutes: Value(encodeReminderMinutes(
        ((json['reminders'] as List<dynamic>?) ?? const [])
            .map((r) => (r as Map<String, dynamic>)['minutesBefore'] as int)
            .toList(),
      )),
      googleEventId: Value(json['googleEventId'] as String?),
      myRole: Value(json['myRole'] as String? ?? 'owner'),
      ownerDisplayName: Value(_formatOwnerName(json['owner'])),
      inviteId: Value(json['inviteId'] as String?),
      inviteStatus: Value(json['inviteStatus'] as String?),
      recurrenceOverrideOf: Value(json['recurrenceOverrideOf'] as String?),
      originalOccurrenceStart: Value(_parseNullableInstant(json['originalOccurrenceStart'])),
      excludedOccurrences: Value(json['excludedOccurrences'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      pendingOperation: const Value(null),
    );
  }

  // assignedDate is a pure calendar date with no time-of-day meaning, so it
  // must never go through UTC/local conversion — that shifts the date by a
  // day depending on the timezone offset. Sent/read as a bare "YYYY-MM-DD"
  // and reconstructed directly from its year/month/day components.
  String? _formatDateOnly(DateTime? date) {
    if (date == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
  }

  DateTime? _parseDateOnly(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.parse(value as String);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  // startTime/endTime are real instants (a specific time-of-day), so
  // converting between UTC and local time is correct here.
  DateTime? _parseNullableInstant(dynamic value) {
    if (value == null) return null;
    return DateTime.parse(value as String).toLocal();
  }

  // Mirrors the name+surname formatting used across the friends/groups/
  // invites screens (see e.g. event_invite_section.dart's _displayName) —
  // duplicated here rather than shared since this one works off a raw JSON
  // map from the server instead of an already-decoded Map<String, dynamic>
  // display model.
  String? _formatOwnerName(dynamic owner) {
    if (owner is! Map<String, dynamic>) return null;
    final name = owner['name'] as String? ?? '';
    final surname = owner['surname'] as String?;
    final fullName = surname != null && surname.isNotEmpty ? '$name $surname' : name;
    return fullName.isEmpty ? null : fullName;
  }
}
