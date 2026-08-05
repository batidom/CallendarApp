import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const PUBLIC_PROFILE_SELECT = {
  id: true,
  name: true,
  surname: true,
  username: true,
} as const;

@Injectable()
export class FriendsService {
  constructor(private readonly prisma: PrismaService) {}

  async search(userId: string, query: string) {
    const users = await this.prisma.user.findMany({
      where: {
        id: { not: userId },
        username: { contains: query, mode: 'insensitive' },
        deletedAt: null,
      },
      select: PUBLIC_PROFILE_SELECT,
      take: 20,
    });

    const relations = await this.prisma.friendship.findMany({
      where: {
        OR: [
          { requesterId: userId, addresseeId: { in: users.map((u) => u.id) } },
          { addresseeId: userId, requesterId: { in: users.map((u) => u.id) } },
        ],
      },
    });

    return users.map((user) => ({
      ...user,
      relationshipStatus: this.describeRelationship(userId, user.id, relations),
    }));
  }

  async sendRequest(userId: string, username: string) {
    const target = await this.prisma.user.findUnique({ where: { username } });
    if (!target) {
      throw new NotFoundException('No user with that username');
    }
    if (target.id === userId) {
      throw new BadRequestException('You cannot friend yourself');
    }

    const existing = await this.prisma.friendship.findFirst({
      where: {
        OR: [
          { requesterId: userId, addresseeId: target.id },
          { requesterId: target.id, addresseeId: userId },
        ],
      },
    });

    if (existing?.status === 'accepted') {
      throw new ConflictException('You are already friends');
    }

    // If they already sent us a request, accept it instead of creating a
    // second row that would collide with the (requesterId, addresseeId)
    // unique constraint in the other direction.
    if (existing?.requesterId === target.id) {
      const [friendship] = await this.prisma.$transaction([
        this.prisma.friendship.update({
          where: { id: existing.id },
          data: { status: 'accepted', respondedAt: new Date() },
        }),
        this.prisma.notification.create({
          data: {
            userId: target.id,
            type: 'friend_request_accepted',
            actorId: userId,
          },
        }),
      ]);
      return friendship;
    }

    if (existing) {
      throw new ConflictException('Friend request already sent');
    }

    const [friendship] = await this.prisma.$transaction([
      this.prisma.friendship.create({
        data: { requesterId: userId, addresseeId: target.id },
      }),
      this.prisma.notification.create({
        data: {
          userId: target.id,
          type: 'friend_request_received',
          actorId: userId,
        },
      }),
    ]);
    return friendship;
  }

  async listIncomingRequests(userId: string) {
    const requests = await this.prisma.friendship.findMany({
      where: { addresseeId: userId, status: 'pending' },
      include: { requester: { select: PUBLIC_PROFILE_SELECT } },
      orderBy: { createdAt: 'desc' },
    });
    return requests.map(({ id, createdAt, requester }) => ({
      id,
      createdAt,
      user: requester,
    }));
  }

  async listOutgoingRequests(userId: string) {
    const requests = await this.prisma.friendship.findMany({
      where: { requesterId: userId, status: 'pending' },
      include: { addressee: { select: PUBLIC_PROFILE_SELECT } },
      orderBy: { createdAt: 'desc' },
    });
    return requests.map(({ id, createdAt, addressee }) => ({
      id,
      createdAt,
      user: addressee,
    }));
  }

  async acceptRequest(userId: string, requestId: string) {
    const request = await this.findPendingIncoming(userId, requestId);
    const [friendship] = await this.prisma.$transaction([
      this.prisma.friendship.update({
        where: { id: request.id },
        data: { status: 'accepted', respondedAt: new Date() },
      }),
      this.prisma.notification.create({
        data: {
          userId: request.requesterId,
          type: 'friend_request_accepted',
          actorId: userId,
        },
      }),
    ]);
    return friendship;
  }

  async declineRequest(userId: string, requestId: string) {
    const request = await this.findPendingIncoming(userId, requestId);
    await this.prisma.friendship.delete({ where: { id: request.id } });
  }

  async cancelRequest(userId: string, requestId: string) {
    const request = await this.prisma.friendship.findUnique({
      where: { id: requestId },
    });
    if (!request || request.status !== 'pending') {
      throw new NotFoundException('Friend request not found');
    }
    if (request.requesterId !== userId) {
      throw new ForbiddenException('You do not have access to this request');
    }
    await this.prisma.friendship.delete({ where: { id: request.id } });
  }

  // Sorted by how often this user has invited each friend to an event
  // (most-used first), falling back to alphabetical — drives the "Add
  // people" picker's ordering. inviteCount is derived from existing invite
  // history rather than a separate counter, since it's already exactly
  // that: every event this friend has ever been invited to by this user.
  async listFriends(userId: string) {
    const friendships = await this.prisma.friendship.findMany({
      where: {
        status: 'accepted',
        OR: [{ requesterId: userId }, { addresseeId: userId }],
      },
      include: {
        requester: { select: PUBLIC_PROFILE_SELECT },
        addressee: { select: PUBLIC_PROFILE_SELECT },
      },
    });
    const friends = friendships.map((f) =>
      f.requesterId === userId ? f.addressee : f.requester,
    );
    if (friends.length === 0)
      return friends.map((friend) => ({ ...friend, inviteCount: 0 }));

    const inviteCounts = await this.prisma.eventInvite.groupBy({
      by: ['invitedUserId'],
      where: {
        invitedById: userId,
        invitedUserId: { in: friends.map((f) => f.id) },
      },
      _count: { invitedUserId: true },
    });
    const countByUserId = new Map(
      inviteCounts.map((c) => [c.invitedUserId, c._count.invitedUserId]),
    );

    return friends
      .map((friend) => ({
        ...friend,
        inviteCount: countByUserId.get(friend.id) ?? 0,
      }))
      .sort(
        (a, b) => b.inviteCount - a.inviteCount || a.name.localeCompare(b.name),
      );
  }

  async areFriends(userId: string, otherUserId: string) {
    const friendship = await this.prisma.friendship.findFirst({
      where: {
        status: 'accepted',
        OR: [
          { requesterId: userId, addresseeId: otherUserId },
          { requesterId: otherUserId, addresseeId: userId },
        ],
      },
    });
    return !!friendship;
  }

  async removeFriend(userId: string, otherUserId: string) {
    await this.prisma.friendship.deleteMany({
      where: {
        status: 'accepted',
        OR: [
          { requesterId: userId, addresseeId: otherUserId },
          { requesterId: otherUserId, addresseeId: userId },
        ],
      },
    });
  }

  private async findPendingIncoming(userId: string, requestId: string) {
    const request = await this.prisma.friendship.findUnique({
      where: { id: requestId },
    });
    if (!request || request.status !== 'pending') {
      throw new NotFoundException('Friend request not found');
    }
    if (request.addresseeId !== userId) {
      throw new ForbiddenException('You do not have access to this request');
    }
    return request;
  }

  private describeRelationship(
    userId: string,
    otherUserId: string,
    relations: { requesterId: string; addresseeId: string; status: string }[],
  ) {
    const relation = relations.find(
      (r) =>
        (r.requesterId === userId && r.addresseeId === otherUserId) ||
        (r.requesterId === otherUserId && r.addresseeId === userId),
    );
    if (!relation) return 'none';
    if (relation.status === 'accepted') return 'friends';
    return relation.requesterId === userId
      ? 'pending_outgoing'
      : 'pending_incoming';
  }
}
