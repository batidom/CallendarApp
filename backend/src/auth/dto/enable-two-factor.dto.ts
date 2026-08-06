import { IsString, Length } from 'class-validator';

export class EnableTwoFactorDto {
  // TOTP-only, since a backup code doesn't exist until setup is confirmed.
  @IsString()
  @Length(6, 6)
  code: string;
}
