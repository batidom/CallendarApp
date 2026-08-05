import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FriendsService } from '../friends/friends.service';

const PUBLIC_PROFILE_SELECT = {
  id: true,
  name: true,
  surname: true,
  username: true,
} as const;

@Injectable()
export class GroupsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly friendsService: FriendsService,
  ) {}

  // Sorted by how often this group has been used to invite people to an
  // event (most-used first), falling back to alphabetical — drives the
  // "Add groups" picker's ordering (and, as a side effect, the My Groups
  // tab's too, which is a reasonable bonus rather than a problem).
  listGroups(userId: string) {
    return this.prisma.group.findMany({
      where: { ownerId: userId },
      include: { members: { include: { user: { select: PUBLIC_PROFILE_SELECT } } } },
      orderBy: [{ usageCount: 'desc' }, { name: 'asc' }],
    });
  }

  // Groups don't require the member's acceptance to be added (see the Group
  // model comment — it's the owner's own contact-grouping tool, not a
  // shared/collaborative entity), so this is the only visibility a member
  // gets into where they've been placed. Read-only: only the owner manages
  // membership/name/deletion.
  async listMemberships(userId: string) {
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId },
      include: {
        group: {
          include: {
            owner: { select: PUBLIC_PROFILE_SELECT },
            members: { include: { user: { select: PUBLIC_PROFILE_SELECT } } },
          },
        },
      },
      orderBy: { group: { createdAt: 'asc' } },
    });
    return memberships.map(({ group }) => group);
  }

  createGroup(userId: string, name: string) {
    return this.prisma.group.create({ data: { ownerId: userId, name } });
  }

  async renameGroup(userId: string, groupId: string, name: string) {
    await this.findOwnedOrThrow(userId, groupId);
    return this.prisma.group.update({ where: { id: groupId }, data: { name } });
  }

  async deleteGroup(userId: string, groupId: string) {
    await this.findOwnedOrThrow(userId, groupId);
    await this.prisma.group.delete({ where: { id: groupId } });
  }

  async addMember(userId: string, groupId: string, memberUserId: string) {
    await this.findOwnedOrThrow(userId, groupId);

    if (memberUserId === userId) {
      throw new BadRequestException('You cannot add yourself to your own group');
    }
    const areFriends = await this.friendsService.areFriends(userId, memberUserId);
    if (!areFriends) {
      throw new BadRequestException('You can only add friends to a group');
    }

    return this.prisma.groupMember.upsert({
      where: { groupId_userId: { groupId, userId: memberUserId } },
      create: { groupId, userId: memberUserId },
      update: {},
    });
  }

  async removeMember(userId: string, groupId: string, memberUserId: string) {
    await this.findOwnedOrThrow(userId, groupId);
    await this.prisma.groupMember.deleteMany({ where: { groupId, userId: memberUserId } });
  }

  private async findOwnedOrThrow(userId: string, groupId: string) {
    const group = await this.prisma.group.findUnique({ where: { id: groupId } });
    if (!group) {
      throw new NotFoundException('Group not found');
    }
    if (group.ownerId !== userId) {
      throw new ForbiddenException('You do not have access to this group');
    }
    return group;
  }
}
