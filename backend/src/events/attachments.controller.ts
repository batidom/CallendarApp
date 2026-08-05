import { randomUUID } from 'crypto';
import { mkdirSync } from 'fs';
import { extname, join } from 'path';
import {
  BadRequestException,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { diskStorage } from 'multer';
import { AuthenticatedUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  ALLOWED_ATTACHMENT_MIME_TYPES,
  ATTACHMENTS_ROOT,
  AttachmentsService,
  MAX_ATTACHMENT_SIZE_BYTES,
} from './attachments.service';

@UseGuards(JwtAuthGuard)
@Controller('events/:id/attachments')
export class AttachmentsController {
  constructor(private readonly attachmentsService: AttachmentsService) {}

  @Get()
  list(@CurrentUser() user: AuthenticatedUser, @Param('id') eventId: string) {
    return this.attachmentsService.list(user.id, eventId);
  }

  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (req, _file, cb) => {
          const dir = join(ATTACHMENTS_ROOT, (req.params as { id: string }).id);
          mkdirSync(dir, { recursive: true });
          cb(null, dir);
        },
        filename: (_req, file, cb) => cb(null, `${randomUUID()}${extname(file.originalname)}`),
      }),
      limits: { fileSize: MAX_ATTACHMENT_SIZE_BYTES },
      fileFilter: (_req, file, cb) => {
        if (!ALLOWED_ATTACHMENT_MIME_TYPES.has(file.mimetype)) {
          cb(new BadRequestException('Unsupported file type'), false);
          return;
        }
        cb(null, true);
      },
    }),
  )
  upload(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') eventId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    return this.attachmentsService.save(user.id, eventId, file);
  }

  @Get(':attachmentId')
  async download(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') eventId: string,
    @Param('attachmentId') attachmentId: string,
    @Res() res: Response,
  ) {
    const attachment = await this.attachmentsService.getForDownload(user.id, eventId, attachmentId);
    res.download(attachment.storagePath, attachment.filename);
  }

  @Delete(':attachmentId')
  remove(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') eventId: string,
    @Param('attachmentId') attachmentId: string,
  ) {
    return this.attachmentsService.delete(user.id, eventId, attachmentId);
  }
}
