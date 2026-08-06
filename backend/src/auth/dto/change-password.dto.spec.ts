import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ChangePasswordDto } from './change-password.dto';

async function errorsFor(payload: Record<string, unknown>) {
  const dto = plainToInstance(ChangePasswordDto, payload);
  return validate(dto);
}

describe('ChangePasswordDto — password policy', () => {
  it('accepts a strong new password', async () => {
    const errors = await errorsFor({
      currentPassword: 'x',
      newPassword: 'Str0ng!Pass',
    });
    expect(errors).toHaveLength(0);
  });

  it('rejects a new password with no symbol', async () => {
    const errors = await errorsFor({
      currentPassword: 'x',
      newPassword: 'Str0ngPass',
    });
    expect(errors.some((e) => e.property === 'newPassword')).toBe(true);
  });

  it('rejects a new password shorter than 8 characters', async () => {
    const errors = await errorsFor({
      currentPassword: 'x',
      newPassword: 'Sh0rt!',
    });
    expect(errors.some((e) => e.property === 'newPassword')).toBe(true);
  });
});
