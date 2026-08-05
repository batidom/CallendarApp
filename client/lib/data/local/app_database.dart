import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Mirrors the `events` table in PostgreSQL (see backend/prisma/schema.prisma)
/// so the client can work offline against an identical local structure.
///
/// A row can be a pure backlog idea (no [assignedDate], no [startTime]), a
/// loose item for a specific day ([assignedDate] set, [startTime] still
/// null), or a fully timed event ([startTime]/[endTime] set — the day is
/// implied by [startTime], so [assignedDate] only matters when it's null).
/// Repeat/reminders only apply once a specific time is set.
///
/// [pendingOperation] tracks offline-first writes that haven't reached the
/// server yet: null means synced, 'create' means the row only exists
/// locally, 'update' means it exists server-side but has local edits
/// pending. This is enough information for the sync worker to pick the
/// right HTTP verb without a separate dirty/clean flag.
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  // Free-text venue/address, e.g. "123 Main St" or "Conference Room B".
  TextColumn get location => text().nullable()();
  DateTimeColumn get assignedDate => dateTime().named('assigned_date').nullable()();
  DateTimeColumn get startTime => dateTime().named('start_time').nullable()();
  DateTimeColumn get endTime => dateTime().named('end_time').nullable()();
  BoolColumn get isAllDay =>
      boolean().named('is_all_day').withDefault(const Constant(false))();
  TextColumn get rrule => text().nullable()();
  // Comma-separated "minutes before start" values, e.g. "0,10,1440". See
  // utils/reminders.dart for the encode/decode helpers.
  TextColumn get reminderMinutes => text().named('reminder_minutes').nullable()();
  TextColumn get googleEventId => text().named('google_event_id').nullable()();
  // Recurrence exceptions: a "this event only" edit is a standalone row
  // (recurrenceOverrideOf/originalOccurrenceStart point back at the series
  // and slot it replaces); a "this event only" delete just adds its
  // original start instant to the master's excludedOccurrences instead. See
  // utils/recurrence.dart for the encode/decode helpers.
  TextColumn get recurrenceOverrideOf => text().named('recurrence_override_of').nullable()();
  DateTimeColumn get originalOccurrenceStart =>
      dateTime().named('original_occurrence_start').nullable()();
  TextColumn get excludedOccurrences => text().named('excluded_occurrences').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  TextColumn get pendingOperation =>
      text().named('pending_operation').nullable()();
  // 'owner' | 'editor' | 'invited' — the current user's relationship to this
  // event, as told by the server (see EventsService.myInviteFields on the
  // backend). 'invited' means a still-pending invite the user hasn't
  // accepted/declined yet, rendered as a distinct read-only tile rather than
  // a normal editable event. Drives whether the UI allows drag-to-
  // reschedule/delete; the backend is the actual enforcement point
  // regardless of what's cached here.
  TextColumn get myRole =>
      text().named('my_role').withDefault(const Constant('owner'))();
  // Deprecated/unused — the schedule-approval feature this backed was
  // replaced by letting any accepted invitee edit directly (with a
  // notification instead of an approval step). Left in place rather than
  // migrated away since SQLite's ALTER TABLE DROP COLUMN support depends on
  // the bundled SQLite version, and an always-null nullable column is
  // harmless. Never populated or read anymore.
  TextColumn get pendingScheduleProposal =>
      text().named('pending_schedule_proposal').nullable()();
  // User-chosen position within the "Someday" backlog panel (drag-to-reorder)
  // — only meaningful for backlog items; null means "never manually
  // ordered", falling back to createdAt for display order. See
  // backend/prisma/schema.prisma's Event.backlogOrder.
  IntColumn get backlogOrder => integer().named('backlog_order').nullable()();
  // Display name ("First Last" or just "First") of this event's owner, as
  // told by the server (see EventsService.toEventResponse) — null until the
  // first successful sync, and never populated for an event the current
  // user owns themself (myRole == 'owner'), since the UI only ever shows
  // this for events shared with the user by someone else.
  TextColumn get ownerDisplayName => text().named('owner_display_name').nullable()();
  // Set only while myRole == 'invited' — the EventInvite id needed to
  // accept/decline via ApiClient.respondToInvite. Null once accepted/owned,
  // since there's nothing left to respond to.
  TextColumn get inviteId => text().named('invite_id').nullable()();
  // 'pending' | 'accepted' | null (owner, or an event with no invite of the
  // current user's own at all) — see EventsService.myInviteFields. Combined
  // with myRole == 'invited', this is what makes the calendar render a
  // still-pending invite as a distinct "respond to this" tile instead of a
  // normal editable event.
  TextColumn get inviteStatus => text().named('invite_status').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ids queued for deletion on the server once connectivity returns.
class PendingDeletions extends Table {
  TextColumn get id => text()();
  TextColumn get entityType =>
      text().named('entity_type').withDefault(const Constant('event'))();
  DateTimeColumn get queuedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Events, PendingDeletions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(events, events.pendingOperation);
            await m.createTable(pendingDeletions);
          }
          if (from < 3) {
            await m.addColumn(pendingDeletions, pendingDeletions.entityType);
          }
          if (from < 4) {
            await m.addColumn(events, events.reminderMinutes);
          }
          if (from < 5) {
            // SQLite can't relax a NOT NULL constraint via ALTER TABLE, so the
            // table is recreated under the new (nullable start/end + new
            // assigned_date column) shape and the old rows copied over.
            await m.database.customStatement('ALTER TABLE events RENAME TO events_old');
            await m.createTable(events);
            await m.database.customStatement('''
              INSERT INTO events (
                id, user_id, title, description, start_time, end_time, is_all_day,
                rrule, reminder_minutes, assigned_date, google_event_id,
                created_at, updated_at, pending_operation
              )
              SELECT
                id, user_id, title, description, start_time, end_time, is_all_day,
                rrule, reminder_minutes, NULL, google_event_id,
                created_at, updated_at, pending_operation
              FROM events_old
            ''');
            await m.database.customStatement('DROP TABLE events_old');

            // Sidequests are folded into events too (as rows with no
            // description/rrule/reminders), then the table is dropped.
            await m.database.customStatement('''
              INSERT INTO events (
                id, user_id, title, description, start_time, end_time, is_all_day,
                rrule, reminder_minutes, assigned_date, google_event_id,
                created_at, updated_at, pending_operation
              )
              SELECT
                id, user_id, title, NULL, scheduled_start_time, scheduled_end_time, 0,
                NULL, NULL, assigned_date, NULL,
                created_at, updated_at, pending_operation
              FROM sidequests
            ''');
            await m.deleteTable('sidequests');
          }
          if (from < 6) {
            await m.addColumn(events, events.location);
          }
          if (from < 7) {
            await m.addColumn(events, events.recurrenceOverrideOf);
            await m.addColumn(events, events.originalOccurrenceStart);
            await m.addColumn(events, events.excludedOccurrences);
          }
          if (from < 8) {
            await m.addColumn(events, events.myRole);
          }
          if (from < 9) {
            await m.addColumn(events, events.pendingScheduleProposal);
          }
          if (from < 10) {
            await m.addColumn(events, events.backlogOrder);
          }
          if (from < 11) {
            await m.addColumn(events, events.ownerDisplayName);
          }
          if (from < 12) {
            await m.addColumn(events, events.inviteId);
            await m.addColumn(events, events.inviteStatus);
          }
        },
      );

  // Recurring events (non-null rrule) are always included regardless of
  // their stored start/end, since those only anchor the first occurrence.
  // Loose tasks for a day are matched by assignedDate instead of
  // start/end. Pure backlog tasks (no day, no time at all) have nothing to
  // match a date range with, so they're always included too — the caller
  // (calendar_screen.dart) buckets everything (backlog/loose/timed/
  // recurring) locally.
  Expression<bool> _inRangeOrUnscheduled(
    $EventsTable tbl,
    DateTime start,
    DateTime end,
  ) =>
      (tbl.startTime.isSmallerOrEqualValue(end) & tbl.endTime.isBiggerOrEqualValue(start)) |
      tbl.rrule.isNotNull() |
      (tbl.assignedDate.isBiggerOrEqualValue(start) & tbl.assignedDate.isSmallerOrEqualValue(end)) |
      (tbl.assignedDate.isNull() & tbl.startTime.isNull());

  Stream<List<Event>> watchEventsInRange(DateTime start, DateTime end) {
    return (select(events)
          ..where((tbl) => _inRangeOrUnscheduled(tbl, start, end))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
        .watch();
  }

  /// All events with at least one reminder, regardless of date — a recurring
  /// or far-future event can have a due reminder even when its start is well
  /// outside whatever range the calendar currently has visible.
  Stream<List<Event>> watchAllEvents() {
    return (select(events)
          ..where((tbl) => tbl.reminderMinutes.isNotNull()))
        .watch();
  }

  Future<List<Event>> pendingEvents() =>
      (select(events)..where((tbl) => tbl.pendingOperation.isNotNull())).get();

  Future<Event?> findEventById(String id) =>
      (select(events)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  /// Standalone "this event only" overrides that replace one occurrence of
  /// [masterId]'s recurring series — used to clean them up locally when the
  /// whole series is deleted (the server cascades this too).
  Future<List<Event>> findOverridesOf(String masterId) =>
      (select(events)..where((tbl) => tbl.recurrenceOverrideOf.equals(masterId))).get();

  Future<void> upsertLocalEvent(EventsCompanion row) =>
      into(events).insertOnConflictUpdate(row);

  /// Marks [id] as synced and stores the server's version of the row.
  Future<void> markEventSynced(String id, EventsCompanion serverData) async {
    await (update(events)..where((tbl) => tbl.id.equals(id)))
        .write(serverData.copyWith(pendingOperation: const Value(null)));
  }

  Future<void> hardDeleteEvent(String id) =>
      (delete(events)..where((tbl) => tbl.id.equals(id))).go();

  Future<void> queuePendingDeletion(String id, String entityType) => into(pendingDeletions)
      .insertOnConflictUpdate(PendingDeletionsCompanion.insert(id: id, entityType: Value(entityType)));

  Future<List<PendingDeletion>> pendingDeletionsOfType(String entityType) =>
      (select(pendingDeletions)..where((tbl) => tbl.entityType.equals(entityType))).get();

  Future<void> clearPendingDeletion(String id) =>
      (delete(pendingDeletions)..where((tbl) => tbl.id.equals(id))).go();

  /// Replaces synced events matching [start]..[end] (the same predicate
  /// [watchEventsInRange] uses) with the server's version. Rows with a
  /// pending local operation are left untouched so an in-flight offline
  /// create/edit is never clobbered by a concurrent background refresh.
  Future<void> replaceRangeWithServerEvents(
    DateTime start,
    DateTime end,
    List<EventsCompanion> rows,
  ) async {
    await transaction(() async {
      final pendingIds = (await pendingEvents()).map((e) => e.id).toSet();

      await (delete(events)
            ..where((tbl) => _inRangeOrUnscheduled(tbl, start, end) & tbl.pendingOperation.isNull()))
          .go();

      final rowsToInsert =
          rows.where((row) => !pendingIds.contains(row.id.value)).toList();
      await batch((b) => b.insertAllOnConflictUpdate(events, rowsToInsert));
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'calendar_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
