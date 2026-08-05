import { IsUUID } from 'class-validator';

export class AssistantConfirmDeleteDto {
  @IsUUID()
  eventId: string;
}
