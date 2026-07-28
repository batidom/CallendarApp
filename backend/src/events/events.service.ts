import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateEventDto } from './dto/create-event.dto';
import { QueryEventsDto } from './dto/query-events.dto';
import { UpdateEventDto } from './dto/update-event.dto';

@Injectable()
export class EventsService {
  constructor(private readonly prisma: PrismaService) {}

  findInRange(userId: string, query: QueryEventsDto) {
    return this.prisma.event.findMany({
      where: {
        userId,
        startTime: { lte: new Date(query.end) },
        endTime: { gte: new Date(query.start) },
      },
      orderBy: { startTime: 'asc' },
      include: { reminders: true },
    });
  }

  create(userId: string, dto: CreateEventDto) {
    return this.prisma.event.create({
      data: {
        userId,
        title: dto.title,
        description: dto.description,
        startTime: new Date(dto.startTime),
        endTime: new Date(dto.endTime),
        isAllDay: dto.isAllDay ?? false,
        rrule: dto.rrule,
      },
    });
  }

  async update(userId: string, id: string, dto: UpdateEventDto) {
    const event = await this.findOwnedOrThrow(userId, id);

    return this.prisma.event.update({
      where: { id: event.id },
      data: {
        title: dto.title,
        description: dto.description,
        startTime: dto.startTime ? new Date(dto.startTime) : undefined,
        endTime: dto.endTime ? new Date(dto.endTime) : undefined,
        isAllDay: dto.isAllDay,
        rrule: dto.rrule,
      },
    });
  }

  async remove(userId: string, id: string) {
    await this.findOwnedOrThrow(userId, id);
    await this.prisma.event.delete({ where: { id } });
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
}
