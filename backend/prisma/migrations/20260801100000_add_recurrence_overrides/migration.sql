-- AlterTable
ALTER TABLE "events" ADD COLUMN     "excluded_occurrences" TEXT,
ADD COLUMN     "original_occurrence_start" TIMESTAMPTZ,
ADD COLUMN     "recurrence_override_of" UUID;

-- CreateIndex
CREATE INDEX "events_recurrence_override_of_idx" ON "events"("recurrence_override_of");

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_recurrence_override_of_fkey" FOREIGN KEY ("recurrence_override_of") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
