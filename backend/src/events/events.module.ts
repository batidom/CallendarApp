import { Module } from '@nestjs/common';
import { GroupsModule } from '../groups/groups.module';
import { AttachmentsController } from './attachments.controller';
import { AttachmentsService } from './attachments.service';
import { EventInvitesController } from './event-invites.controller';
import { EventInvitesService } from './event-invites.service';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';

@Module({
  imports: [GroupsModule],
  controllers: [
    EventsController,
    EventInvitesController,
    AttachmentsController,
  ],
  providers: [EventsService, EventInvitesService, AttachmentsService],
  exports: [EventsService],
})
export class EventsModule {}
