import { ArrayMaxSize, IsArray, IsOptional, IsUUID } from 'class-validator';

export class InviteToEventDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsUUID('4', { each: true })
  userIds?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID('4', { each: true })
  groupIds?: string[];
}
