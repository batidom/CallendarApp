import { IsDateString } from 'class-validator';

export class QueryEventsDto {
  @IsDateString()
  start: string;

  @IsDateString()
  end: string;
}
