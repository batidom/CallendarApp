import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { InviteToEventDto } from './dto/invite-to-event.dto';

const PUBLIC_PROFILE_SELECT = {
  id: true,
  name: true,
  surname: true,
  username: true,
} as const;

@Injectable()
export class EventInvitesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groupsService: GroupsService,
  ) {}

  async invite(userId: string, eventId: string, dto: InviteToEventDto) {
    const event = await this.prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      throw new NotFoundException('Event not found');
    }
    if (event.userId !== userId) {
      throw new ForbiddenException('Only the event owner can invite people');
    }

    const invitedUserIds = new Set(dto.userIds ?? []);
    // Tracked separately from invitedUserIds so a group's usageCount goes up
    // once per invite() call it's used in, regardless of how many of its
    // members were already invited/deduped away below.
    const usedGroupIds: string[] = [];
    if (dto.groupIds?.length) {
      const groups = await this.groupsService.listGroups(userId);
      for (const groupId of dto.groupIds) {
        const group = groups.find((g) => g.id === groupId);
        if (!group) {
          throw new NotFoundException(`Group ${groupId} not found`);
        }
        usedGroupIds.push(groupId);
        for (const member of group.members) {
          invitedUserIds.add(member.userId);
        }
      }
    }
    invitedUserIds.delete(userId);

    if (invitedUserIds.size === 0) {
      throw new BadRequestException('No valid people to invite');
    }

    await this.prisma.$transaction([
      ...Array.from(invitedUserIds).map((invitedUserId) =>
        this.prisma.eventInvite.upsert({
          where: { eventId_invitedUserId: { eventId, invitedUserId } },
          create: { eventId, invitedUserId, invitedById: userId },
          update: {},
        }),
      ),
      ...usedGroupIds.map((groupId) =>
        this.prisma.group.update({ where: { id: groupId }, data: { usageCount: { increment: 1 } } }),
      ),
    ]);

    return this.list(userId, eventId);
  }

  async list(userId: string, eventId: string) {
    await this.assertCanView(userId, eventId);
    const invites = await this.prisma.eventInvite.findMany({
      where: { eventId },
      include: { invitedUser: { select: PUBLIC_PROFILE_SELECT } },
      orderBy: { createdAt: 'asc' },
    });
    return invites.map(({ id, status, createdAt, invitedUser }) => ({
      id,
      status,
      createdAt,
      user: invitedUser,
    }));
  }

  async listMyPendingInvites(userId: string) {
    const invites = await this.prisma.eventInvite.findMany({
      where: { invitedUserId: userId, status: 'pending' },
      include: {
        event: true,
        invitedBy: { select: PUBLIC_PROFILE_SELECT },
      },
      orderBy: { createdAt: 'desc' },
    });
    return invites.map(({ id, createdAt, event, invitedBy }) => ({
      id,
      createdAt,
      event,
      invitedBy,
    }));
  }

  // Only the owner is notified here (not the whole group, unlike
  // leave()/notifyGroupOfChange on the events side) — an RSVP is
  // information the person who sent the invite cares about, not something
  // that affects how everyone else already on the event should act.
  async respond(userId: string, inviteId: string, accept: boolean) {
    const invite = await this.prisma.eventInvite.findUnique({ where: { id: inviteId } });
    if (!invite || invite.invitedUserId !== userId) {
      throw new NotFoundException('Invite not found');
    }
    if (invite.status !== 'pending') {
      throw new BadRequestException('This invite has already been responded to');
    }

    const event = await this.prisma.event.findUnique({ where: { id: invite.eventId } });
    if (!event) {
      throw new NotFoundException('Event not found');
    }

    const updated = await this.prisma.eventInvite.update({
      where: { id: inviteId },
      data: { status: accept ? 'accepted' : 'declined', respondedAt: new Date() },
    });

    if (event.userId !== userId) {
      await this.prisma.notification.create({
        data: {
          userId: event.userId,
          type: accept ? 'invite_accepted' : 'invite_declined',
          actorId: userId,
          eventId: event.id,
          eventTitle: event.title,
        },
      });
    }

    return updated;
  }

  async revoke(userId: string, eventId: string, inviteId: string) {
    const invite = await this.prisma.eventInvite.findUnique({ where: { id: inviteId } });
    if (!invite || invite.eventId !== eventId) {
      throw new NotFoundException('Invite not found');
    }

    const event = await this.prisma.event.findUnique({ where: { id: eventId } });
    const isOwner = event?.userId === userId;
    const isSelf = invite.invitedUserId === userId;
    if (!isOwner && !isSelf) {
      throw new ForbiddenException('You do not have access to this invite');
    }

    await this.prisma.eventInvite.delete({ where: { id: inviteId } });
  }

  // A self-service exit for an invitee (as opposed to revoke() above, which
  // is the owner managing someone else's invite, or an invitee's own
  // self-revoke with no side effects) — this is specifically the "leave"
  // action, so unlike revoke() it tells the rest of the event about it: the
  // owner and every other currently-accepted invitee get a notification,
  // same audience that already sees a pending schedule proposal.
  async leave(userId: string, eventId: string): Promise<void> {
    const invite = await this.prisma.eventInvite.findUnique({
      where: { eventId_invitedUserId: { eventId, invitedUserId: userId } },
    });
    if (!invite) {
      throw new NotFoundException('You are not part of this event');
    }

    const event = await this.prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      throw new NotFoundException('Event not found');
    }

    const otherAccepted = await this.prisma.eventInvite.findMany({
      where: { eventId, status: 'accepted', invitedUserId: { not: userId } },
      select: { invitedUserId: true },
    });
    const recipientIds = new Set([event.userId, ...otherAccepted.map((i) => i.invitedUserId)]);
    recipientIds.delete(userId);

    await this.prisma.$transaction([
      this.prisma.eventInvite.delete({ where: { id: invite.id } }),
      this.prisma.notification.createMany({
        data: Array.from(recipientIds).map((recipientId) => ({
          userId: recipientId,
          type: 'left_event',
          actorId: userId,
          eventId,
          eventTitle: event.title,
        })),
      }),
    ]);
  }

  private async assertCanView(userId: string, eventId: string) {
    const event = await this.prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      throw new NotFoundException('Event not found');
    }
    if (event.userId === userId) return;

    const invite = await this.prisma.eventInvite.findUnique({
      where: { eventId_invitedUserId: { eventId, invitedUserId: userId } },
    });
    if (invite?.status !== 'accepted') {
      throw new ForbiddenException('You do not have access to this event');
    }
  }
}
