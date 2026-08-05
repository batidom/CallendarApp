import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const PUBLIC_PROFILE_SELECT = {
  id: true,
  name: true,
  surname: true,
  username: true,
} as const;

// "Read" state isn't tracked server-side — same as the client's local
// reminder popups, "seen" is purely a client-side timestamp cutover (see
// calendar_screen.dart's notifications bell), so there's nothing to mark
// here. This just returns what's recent enough to be worth showing.
const MAX_NOTIFICATIONS = 50;

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string) {
    const notifications = await this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: MAX_NOTIFICATIONS,
      include: { actor: { select: PUBLIC_PROFILE_SELECT } },
    });
    return notifications.map(({ actorId, ...notification }) => notification);
  }
}
