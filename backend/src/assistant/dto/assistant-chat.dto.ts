import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';

export class AssistantMessageDto {
  @IsIn(['user', 'assistant'])
  role: 'user' | 'assistant';

  @IsString()
  content: string;
}

export class AssistantChatDto {
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => AssistantMessageDto)
  messages: AssistantMessageDto[];

  // A naive "YYYY-MM-DDTHH:mm:ss" in the user's own local time (not UTC) —
  // paired with utcOffsetMinutes so the assistant can resolve relative dates
  // ("tomorrow", "next Thursday") and convert day/time tool args to real
  // instants, without needing an IANA timezone database server-side.
  @IsString()
  clientNowLocal: string;

  @IsInt()
  utcOffsetMinutes: number;

  // The app's current UI language code (e.g. "en", "pl") — used to pin the
  // reply language explicitly rather than inferring it from message text,
  // which is unreliable for short messages or ones with few/no
  // language-distinctive characters.
  @IsOptional()
  @IsString()
  language?: string;
}
