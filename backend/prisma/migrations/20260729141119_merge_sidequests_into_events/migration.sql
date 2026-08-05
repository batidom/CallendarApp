-- Merge Sidequest into Event: a task can now be a pure backlog idea (no
-- assigned_date, no start_time), a loose item for a specific day
-- (assigned_date set, start_time still null), or a fully timed event
-- (start_time/end_time set).

-- 1. Add assigned_date and relax start_time/end_time to nullable.
ALTER TABLE "events" ADD COLUMN "assigned_date" DATE;
ALTER TABLE "events" ALTER COLUMN "start_time" DROP NOT NULL;
ALTER TABLE "events" ALTER COLUMN "end_time" DROP NOT NULL;

CREATE INDEX "events_user_id_assigned_date_idx" ON "events"("user_id", "assigned_date");

-- 2. Migrate existing sidequests into events (description/rrule/reminders
-- don't apply to sidequests, so they're left null/absent).
INSERT INTO "events" (
  "id", "user_id", "title", "description", "assigned_date",
  "start_time", "end_time", "is_all_day", "rrule", "google_event_id",
  "created_at", "updated_at"
)
SELECT
  "id", "user_id", "title", NULL, "assigned_date",
  "scheduled_start_time", "scheduled_end_time", false, NULL, NULL,
  "created_at", "updated_at"
FROM "sidequests";

-- 3. Drop the now-empty sidequests table.
DROP TABLE "sidequests";
