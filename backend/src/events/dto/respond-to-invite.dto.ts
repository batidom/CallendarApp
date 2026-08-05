import { IsBoolean } from 'class-validator';

export class RespondToInviteDto {
  @IsBoolean()
  accept: boolean;
}
