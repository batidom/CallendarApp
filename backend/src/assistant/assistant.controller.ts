import {
  BadRequestException,
  Body,
  Controller,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthenticatedUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AssistantService } from './assistant.service';
import { AssistantChatDto } from './dto/assistant-chat.dto';
import { AssistantConfirmDeleteDto } from './dto/assistant-confirm-delete.dto';
import { WhisperClient } from './whisper-client';

const MAX_AUDIO_SIZE_BYTES = 25 * 1024 * 1024;

@UseGuards(JwtAuthGuard)
@Controller('assistant')
export class AssistantController {
  constructor(
    private readonly assistantService: AssistantService,
    private readonly whisperClient: WhisperClient,
  ) {}

  @Post('chat')
  chat(@CurrentUser() user: AuthenticatedUser, @Body() dto: AssistantChatDto) {
    return this.assistantService.chat(user.id, dto);
  }

  @Post('confirm-delete')
  confirmDelete(@CurrentUser() user: AuthenticatedUser, @Body() dto: AssistantConfirmDeleteDto) {
    return this.assistantService.confirmDelete(user.id, dto.eventId);
  }

  @Post('transcribe')
  @UseInterceptors(
    FileInterceptor('audio', {
      limits: { fileSize: MAX_AUDIO_SIZE_BYTES },
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.startsWith('audio/')) {
          cb(new BadRequestException('Unsupported file type'), false);
          return;
        }
        cb(null, true);
      },
    }),
  )
  async transcribe(
    @UploadedFile() file: Express.Multer.File,
    @Body('language') language?: string,
  ) {
    if (!file) {
      throw new BadRequestException('No audio uploaded');
    }
    const resolvedLanguage = language === 'pl' ? 'pl' : 'en';
    const rawText = await this.whisperClient.transcribe(
      file.buffer,
      file.originalname || 'audio.wav',
      resolvedLanguage,
    );
    const text = await this.assistantService.cleanTranscript(rawText, resolvedLanguage);
    return { text };
  }
}
