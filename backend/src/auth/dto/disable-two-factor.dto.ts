import { IsString, MaxLength, MinLength } from 'class-validator';

export class DisableTwoFactorDto {
  @IsString()
  password: string;

  // TOTP code or backup code, same as VerifyTwoFactorDto.
  @IsString()
  @MinLength(6)
  @MaxLength(10)
  code: string;
}
