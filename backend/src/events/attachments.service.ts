import { existsSync, unlinkSync } from 'fs';
import { join } from 'path';
import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export const ATTACHMENTS_ROOT = join(process.cwd(), 'uploads', 'events');
export const MAX_ATTACHMENT_SIZE_BYTES = 10 * 1024 * 1024;
export const ALLOWED_ATTACHMENT_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/heic',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/plain',
]);

const PUBLIC_PROFILE_SELECT = {
  id: true,
  name: true,
  surname: true,
  username: true,
} as const;

@Injectable()
export class AttachmentsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, eventId: string) {
    await this.assertCanView(userId, eventId);
    return this.prisma.attachment.findMany({
      where: { eventId },
      include: { uploadedBy: { select: PUBLIC_PROFILE_SELECT } },
      orderBy: { createdAt: 'asc' },
    });
  }

  // The file is already written to disk by the time this runs (multer wrote
  // it before the route handler was invoked) — if the caller turns out not
  // to have permission, clean it up rather than leaving an orphaned file.
  async save(userId: string, eventId: string, file: Express.Multer.File) {
    try {
      await this.assertCanManage(userId, eventId);
    } catch (error) {
      unlinkSync(file.path);
      throw error;
    }

    return this.prisma.attachment.create({
      data: {
        eventId,
        uploadedById: userId,
        filename: file.originalname,
        mimeType: file.mimetype,
        sizeBytes: file.size,
        storagePath: file.path,
      },
      include: { uploadedBy: { select: PUBLIC_PROFILE_SELECT } },
    });
  }

  async getForDownload(userId: string, eventId: string, attachmentId: string) {
    await this.assertCanView(userId, eventId);
    return this.findOrThrow(eventId, attachmentId);
  }

  async delete(userId: string, eventId: string, attachmentId: string) {
    await this.assertCanManage(userId, eventId);
    const attachment = await this.findOrThrow(eventId, attachmentId);
    await this.prisma.attachment.delete({ where: { id: attachmentId } });
    if (existsSync(attachment.storagePath)) {
      unlinkSync(attachment.storagePath);
    }
  }

  private async findOrThrow(eventId: string, attachmentId: string) {
    const attachment = await this.prisma.attachment.findUnique({ where: { id: attachmentId } });
    if (!attachment || attachment.eventId !== eventId) {
      throw new NotFoundException('Attachment not found');
    }
    return attachment;
  }

  // Owner, or any invitee whose invite has been accepted — attachments are
  // just more event content.
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

  // Owner, or any accepted invitee — uploading/deleting files currently
  // follows the same "any participant can edit" rule as the event itself
  // (see EventsService.findEditableOrThrow). Kept as its own method rather
  // than collapsed into assertCanView: deletion specifically is likely to
  // get tightened to uploader-or-owner-only once attachments become more of
  // a shared photo/video album, where an accidental or malicious delete by
  // an unrelated participant is a real concern.
  private async assertCanManage(userId: string, eventId: string) {
    const event = await this.prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      throw new NotFoundException('Event not found');
    }
    if (event.userId === userId) return;

    const invite = await this.prisma.eventInvite.findUnique({
      where: { eventId_invitedUserId: { eventId, invitedUserId: userId } },
    });
    if (invite?.status !== 'accepted') {
      throw new ForbiddenException('You do not have permission to manage attachments for this event');
    }
  }
}
