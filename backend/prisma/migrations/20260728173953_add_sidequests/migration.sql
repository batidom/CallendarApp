-- CreateTable
CREATE TABLE "sidequests" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "assigned_date" DATE,
    "scheduled_start_time" TIMESTAMPTZ,
    "scheduled_end_time" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "sidequests_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "sidequests" ADD CONSTRAINT "sidequests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
