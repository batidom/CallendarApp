import { IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { PASSWORD_REGEX, PASSWORD_POLICY_MESSAGE } from '../password-policy';

export class ChangePasswordDto {
  @IsString()
  currentPassword: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  @Matches(PASSWORD_REGEX, { message: PASSWORD_POLICY_MESSAGE })
  newPassword: string;
}
