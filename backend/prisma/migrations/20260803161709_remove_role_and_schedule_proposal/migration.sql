/*
  Warnings:

  - You are about to drop the column `role` on the `event_invites` table. All the data in the column will be lost.
  - You are about to drop the `event_schedule_proposals` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "event_schedule_proposals" DROP CONSTRAINT "event_schedule_proposals_event_id_fkey";

-- DropForeignKey
ALTER TABLE "event_schedule_proposals" DROP CONSTRAINT "event_schedule_proposals_proposed_by_id_fkey";

-- AlterTable
ALTER TABLE "event_invites" DROP COLUMN "role";

-- AlterTable
ALTER TABLE "groups" ADD COLUMN     "usage_count" INTEGER NOT NULL DEFAULT 0;

-- DropTable
DROP TABLE "event_schedule_proposals";

-- DropEnum
DROP TYPE "EventInviteRole";
