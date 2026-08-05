import { IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class UpdateUsernameDto {
  @IsString()
  password: string;

  // Same rules as RegisterDto.username — this is the public handle other
  // users search for when adding a friend.
  @IsString()
  @MinLength(3)
  @MaxLength(30)
  @Matches(/^[a-zA-Z0-9_]+$/, {
    message: 'username may only contain letters, numbers, and underscores',
  })
  newUsername: string;
}
