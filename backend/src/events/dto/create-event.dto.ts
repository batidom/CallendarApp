import {
  ArrayMaxSize,
  IsBoolean,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateEventDto {
  // Allows offline-created events to keep the same id after syncing, so a
  // retried create is idempotent instead of producing a duplicate.
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsString()
  @MaxLength(255)
  title: string;

  @IsOptional()
  @IsString()
  description?: string;

  // Free-text venue/address, e.g. "123 Main St" or "Conference Room B".
  @IsOptional()
  @IsString()
  @MaxLength(500)
  location?: string;

  // The day a task is placed on when it has no specific time yet (a loose
  // item for that day, or absent entirely for a pure backlog idea). Only
  // meaningful when startTime is null — once a specific time is set, the day
  // is implied by startTime instead.
  @IsOptional()
  @IsDateString()
  assignedDate?: string;

  @IsOptional()
  @IsDateString()
  startTime?: string;

  @IsOptional()
  @IsDateString()
  endTime?: string;

  @IsOptional()
  @IsBoolean()
  isAllDay?: boolean;

  @IsOptional()
  @IsString()
  rrule?: string;

  // How many minutes before the event's start each reminder should fire, e.g.
  // [0, 10, 1440] for "at start time", "10 minutes before", and "1 day before".
  @IsOptional()
  @ArrayMaxSize(20)
  @IsInt({ each: true })
  @Min(0, { each: true })
  reminders?: number[];

  // Set together when this event is a standalone "this occurrence only"
  // override of one instance of a recurring series (see schema.prisma).
  @IsOptional()
  @IsUUID()
  recurrenceOverrideOf?: string;

  @IsOptional()
  @IsDateString()
  originalOccurrenceStart?: string;

  // Opaque comma-separated list of excluded occurrence instants, only
  // meaningful on a recurring master — the client owns the encoding.
  @IsOptional()
  @IsString()
  excludedOccurrences?: string;

  // Drag-to-reorder position within the "Someday" backlog panel — only
  // meaningful for backlog items, see schema.prisma.
  @IsOptional()
  @IsInt()
  @Min(0)
  backlogOrder?: number;
}
