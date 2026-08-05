-- CreateTable
CREATE TABLE "event_schedule_proposals" (
    "id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "proposed_by_id" UUID NOT NULL,
    "assigned_date" DATE,
    "start_time" TIMESTAMPTZ,
    "end_time" TIMESTAMPTZ,
    "is_all_day" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_schedule_proposals_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "event_schedule_proposals_event_id_key" ON "event_schedule_proposals"("event_id");

-- AddForeignKey
ALTER TABLE "event_schedule_proposals" ADD CONSTRAINT "event_schedule_proposals_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_schedule_proposals" ADD CONSTRAINT "event_schedule_proposals_proposed_by_id_fkey" FOREIGN KEY ("proposed_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
