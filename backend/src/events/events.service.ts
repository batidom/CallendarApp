import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateEventDto } from './dto/create-event.dto';
import { QueryEventsDto } from './dto/query-events.dto';
import { UpdateEventDto } from './dto/update-event.dto';

const PUBLIC_PROFILE_SELECT = {
  id: true,
  name: true,
  surname: true,
  username: true,
} as const;

@Injectable()
export class EventsService {
  constructor(private readonly prisma: PrismaService) {}

  // Every event response carries its owner's public profile — so an
  // invitee (who can already see this same info via GET /events/:id/invites,
  // see EventInvitesService.assertCanView) can tell at a glance whose event
  // they're looking at, instead of only ever seeing "shared with you".
  private toEventResponse<T extends { user: { id: string; name: string; surname: string | null; username: string } }>(
    event: T,
  ): Omit<T, 'user'> & { owner: T['user'] } {
    const { user, ...rest } = event;
    return { ...rest, owner: user };
  }

  async findInRange(userId: string, query: QueryEventsDto) {
    const start = new Date(query.start);
    const end = new Date(query.end);

    // Recurring events are stored as a single row anchored at their first
    // occurrence, so a plain overlap filter would miss a series that started
    // before this range; recurring masters are always included and the
    // client expands/filters them to the requested range. Loose tasks for a
    // day are matched by assignedDate instead of startTime/endTime. Pure
    // backlog tasks (no day, no time at all) have nothing to match a date
    // range with, so they're always included too, same as recurring masters
    // — the client buckets them into its backlog panel locally.
    const scheduleFilter = [
      { startTime: { lte: end }, endTime: { gte: start } },
      { rrule: { not: null } },
      { assignedDate: { gte: start, lte: end } },
      { assignedDate: null, startTime: null },
    ];

    // Events the user owns, plus events they were invited to — accepted or
    // still pending, so a pending invite shows up on the calendar itself
    // (rendered distinctly by the client, see EventInviteSection) instead of
    // only being discoverable via the separate Invites tab. A declined
    // invite's status is neither, so it naturally drops off here once
    // responded to.
    const events = await this.prisma.event.findMany({
      where: {
        OR: [
          { userId, OR: scheduleFilter },
          {
            invites: { some: { invitedUserId: userId, status: { in: ['accepted', 'pending'] } } },
            OR: scheduleFilter,
          },
        ],
      },
      orderBy: { createdAt: 'asc' },
      include: {
        reminders: true,
        user: { select: PUBLIC_PROFILE_SELECT },
        // At most one row per (eventId, invitedUserId) — see the unique
        // constraint on EventInvite — so this is really "my own invite to
        // this event, if any".
        invites: { where: { invitedUserId: userId }, select: { id: true, status: true } },
      },
    });

    return events.map((event) => {
      const { invites, ...rest } = event;
      return {
        ...this.toEventResponse(rest),
        ...this.myInviteFields(userId, event.userId, invites[0] ?? null),
      };
    });
  }

  // Purely advisory for the client's UI (e.g. showing the owner-only delete
  // button, or rendering a still-pending invite as a distinct "respond to
  // this" tile instead of a normal editable event) — any accepted invitee
  // can edit an event same as the owner now (see findEditableOrThrow), so
  // 'editor' vs 'owner' only ever distinguishes "can also delete the whole
  // event" from "can't". 'invited' means the current user hasn't accepted
  // yet and can't edit at all until they do.
  private myInviteFields(
    userId: string,
    eventOwnerId: string,
    myInvite: { id: string; status: string } | null,
  ): { myRole: 'owner' | 'editor' | 'invited'; inviteId: string | null; inviteStatus: string | null } {
    if (eventOwnerId === userId) {
      return { myRole: 'owner', inviteId: null, inviteStatus: null };
    }
    return {
      myRole: myInvite?.status === 'pending' ? 'invited' : 'editor',
      inviteId: myInvite?.id ?? null,
      inviteStatus: myInvite?.status ?? null,
    };
  }

  async create(userId: string, dto: CreateEventDto) {
    this.assertScheduleConsistent(!!dto.startTime, dto.rrule, dto.reminders);

    // A client-supplied id makes retries idempotent: if a previous attempt
    // already reached the server (e.g. the response was lost while the
    // client went offline), return that record instead of erroring.
    if (dto.id) {
      const existing = await this.prisma.event.findUnique({
        where: { id: dto.id },
        include: { user: { select: PUBLIC_PROFILE_SELECT } },
      });
      if (existing) {
        if (existing.userId !== userId) {
          throw new ForbiddenException('You do not have access to this event');
        }
        return {
          ...this.toEventResponse(existing),
          myRole: 'owner' as const,
          inviteId: null,
          inviteStatus: null,
        };
      }
    }

    const event = await this.prisma.event.create({
      data: {
        id: dto.id,
        userId,
        title: dto.title,
        description: dto.description,
        location: dto.location,
        assignedDate: dto.assignedDate ? new Date(dto.assignedDate) : undefined,
        startTime: dto.startTime ? new Date(dto.startTime) : undefined,
        endTime: dto.endTime ? new Date(dto.endTime) : undefined,
        isAllDay: dto.isAllDay ?? false,
        rrule: dto.rrule,
        recurrenceOverrideOf: dto.recurrenceOverrideOf,
        originalOccurrenceStart: dto.originalOccurrenceStart ? new Date(dto.originalOccurrenceStart) : undefined,
        excludedOccurrences: dto.excludedOccurrences,
        reminders: dto.reminders
          ? { create: dto.reminders.map((minutesBefore) => ({ minutesBefore, type: 'in_app' })) }
          : undefined,
      },
      include: { reminders: true, user: { select: PUBLIC_PROFILE_SELECT } },
    });
    // The creator is always the owner.
    return { ...this.toEventResponse(event), myRole: 'owner' as const, inviteId: null, inviteStatus: null };
  }

  async update(userId: string, id: string, dto: UpdateEventDto) {
    const event = await this.findEditableOrThrow(userId, id);
    const isOwner = event.userId === userId;

    const nextAssignedDate =
      dto.assignedDate !== undefined ? this.parseNullableDate(dto.assignedDate) : event.assignedDate;
    const nextStartTime =
      dto.startTime !== undefined ? this.parseNullableDate(dto.startTime) : event.startTime;
    const nextEndTime = dto.endTime !== undefined ? this.parseNullableDate(dto.endTime) : event.endTime;
    const nextIsAllDay = dto.isAllDay !== undefined ? dto.isAllDay : event.isAllDay;

    const scheduleChanged =
      !this.dateEquals(nextAssignedDate, event.assignedDate) ||
      !this.dateEquals(nextStartTime, event.startTime) ||
      !this.dateEquals(nextEndTime, event.endTime) ||
      nextIsAllDay !== event.isAllDay;
    const locationChanged = dto.location !== undefined && dto.location !== event.location;
    const descriptionChanged = dto.description !== undefined && dto.description !== event.description;

    const hasTimeAfterUpdate = !!nextStartTime;
    const rruleAfterUpdate = dto.rrule !== undefined ? dto.rrule : event.rrule;
    this.assertScheduleConsistent(hasTimeAfterUpdate, rruleAfterUpdate ?? undefined, dto.reminders);

    // Reminders are always replaced wholesale rather than diffed, matching how
    // the client always sends its full desired set (same approach as rrule).
    const updated = await this.prisma.$transaction(async (tx) => {
      if (dto.reminders) {
        await tx.eventReminder.deleteMany({ where: { eventId: event.id } });
      }

      return tx.event.update({
        where: { id: event.id },
        data: {
          title: dto.title,
          description: dto.description,
          location: dto.location,
          assignedDate: this.parseNullableDate(dto.assignedDate),
          startTime: this.parseNullableDate(dto.startTime),
          endTime: this.parseNullableDate(dto.endTime),
          isAllDay: dto.isAllDay,
          rrule: dto.rrule,
          excludedOccurrences: dto.excludedOccurrences,
          backlogOrder: dto.backlogOrder,
          reminders: dto.reminders
            ? { create: dto.reminders.map((minutesBefore) => ({ minutesBefore, type: 'in_app' })) }
            : undefined,
        },
        include: { reminders: true, user: { select: PUBLIC_PROFILE_SELECT } },
      });
    });

    if (scheduleChanged || locationChanged || descriptionChanged) {
      const oldMoment = event.startTime ?? event.assignedDate ?? null;
      const newMoment = nextStartTime ?? nextAssignedDate ?? null;
      const dateChanged = this.dateKey(oldMoment) !== this.dateKey(newMoment);
      // Only meaningful when both before and after have an actual time of
      // day — an all-day <-> timed transition is a bigger change than "the
      // hour moved" and is already covered by the date_changed notification.
      const timeChanged =
        !event.isAllDay &&
        !nextIsAllDay &&
        this.timeKey(event.startTime) !== this.timeKey(nextStartTime);

      await this.notifyGroupOfChange(userId, event, [
        ...(dateChanged ? [{ type: 'date_changed', oldValue: oldMoment, newValue: newMoment }] : []),
        ...(timeChanged
          ? [{ type: 'time_changed', oldValue: event.startTime, newValue: nextStartTime ?? null }]
          : []),
        ...(locationChanged
          ? [{ type: 'location_changed', oldValue: event.location, newValue: dto.location ?? null }]
          : []),
        ...(descriptionChanged
          ? [{ type: 'description_changed', oldValue: event.description, newValue: dto.description ?? null }]
          : []),
      ]);
    }

    // Reaching this point at all (see findEditableOrThrow) already proved
    // the caller is either the owner or an accepted invitee — there's no
    // 'invited' (pending) state to account for here.
    return {
      ...this.toEventResponse(updated),
      myRole: isOwner ? ('owner' as const) : ('editor' as const),
      inviteId: null,
      inviteStatus: isOwner ? null : ('accepted' as const),
    };
  }

  private dateKey(value: Date | null | undefined): string | null {
    return value ? value.toISOString().slice(0, 10) : null;
  }

  private timeKey(value: Date | null | undefined): string | null {
    return value ? value.toISOString().slice(11, 16) : null;
  }

  // Anyone can now change an event's time/place directly (see
  // findEditableOrThrow) instead of that going through the owner's
  // approval, so the tradeoff is telling everyone else exactly what
  // happened — reuses the same Notification table as "left event", with
  // oldValue/newValue carrying the diff so the client can render it (e.g.
  // "changed the date of X from Aug 3 to Aug 4") instead of just naming the
  // field that changed.
  private async notifyGroupOfChange(
    actorId: string,
    event: { id: string; userId: string; title: string },
    changes: { type: string; oldValue: Date | string | null; newValue: Date | string | null }[],
  ): Promise<void> {
    if (changes.length === 0) return;

    const accepted = await this.prisma.eventInvite.findMany({
      where: { eventId: event.id, status: 'accepted' },
      select: { invitedUserId: true },
    });
    const recipientIds = new Set([event.userId, ...accepted.map((i) => i.invitedUserId)]);
    recipientIds.delete(actorId);
    if (recipientIds.size === 0) return;

    const toValueString = (value: Date | string | null) =>
      value === null ? null : value instanceof Date ? value.toISOString() : value;

    const rows = Array.from(recipientIds).flatMap((userId) =>
      changes.map((change) => ({
        userId,
        type: change.type,
        actorId,
        eventId: event.id,
        eventTitle: event.title,
        oldValue: toValueString(change.oldValue),
        newValue: toValueString(change.newValue),
      })),
    );
    await this.prisma.notification.createMany({ data: rows });
  }

  async remove(userId: string, id: string) {
    await this.findOwnedOrThrow(userId, id);
    await this.prisma.event.delete({ where: { id } });
  }

  // Repeat and reminders are anchored to a specific time, so neither makes
  // sense on a backlog idea or a day-only loose task.
  private assertScheduleConsistent(hasTime: boolean, rrule?: string, reminders?: number[]) {
    if (!hasTime && (rrule || (reminders && reminders.length > 0))) {
      throw new BadRequestException('Repeat and reminders require a specific start time');
    }
  }

  // undefined means "not provided, leave unchanged"; null means "clear this
  // field" (e.g. moving a task back to the backlog).
  private parseNullableDate(value: string | null | undefined) {
    if (value === undefined) return undefined;
    return value === null ? null : new Date(value);
  }

  private dateEquals(a: Date | null | undefined, b: Date | null | undefined): boolean {
    return (a?.getTime() ?? null) === (b?.getTime() ?? null);
  }

  private async findOwnedOrThrow(userId: string, id: string) {
    const event = await this.prisma.event.findUnique({ where: { id } });
    if (!event) {
      throw new NotFoundException('Event not found');
    }
    if (event.userId !== userId) {
      throw new ForbiddenException('You do not have access to this event');
    }
    return event;
  }

  // The owner can always edit; any accepted invitee can too, regardless of
  // role — only actually deleting the whole event stays owner-only (see
  // remove()/findOwnedOrThrow above).
  private async findEditableOrThrow(userId: string, id: string) {
    const event = await this.prisma.event.findUnique({ where: { id } });
    if (!event) {
      throw new NotFoundException('Event not found');
    }
    if (event.userId === userId) {
      return event;
    }

    const invite = await this.prisma.eventInvite.findUnique({
      where: { eventId_invitedUserId: { eventId: id, invitedUserId: userId } },
    });
    if (invite?.status !== 'accepted') {
      throw new ForbiddenException('You do not have access to this event');
    }
    return event;
  }
}
