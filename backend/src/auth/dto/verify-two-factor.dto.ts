import { IsString, MaxLength, MinLength } from 'class-validator';

export class VerifyTwoFactorDto {
  @IsString()
  twoFactorToken: string;

  // Either a 6-digit TOTP code or a 10-character backup code — see
  // AuthService.verifyTotpOrBackupCode.
  @IsString()
  @MinLength(6)
  @MaxLength(10)
  code: string;
}
