import { Module } from '@nestjs/common';
import { EventsModule } from '../events/events.module';
import { AssistantController } from './assistant.controller';
import { AssistantService } from './assistant.service';
import { OllamaClient } from './ollama-client';
import { WhisperClient } from './whisper-client';

@Module({
  imports: [EventsModule],
  controllers: [AssistantController],
  providers: [AssistantService, OllamaClient, WhisperClient],
})
export class AssistantModule {}
