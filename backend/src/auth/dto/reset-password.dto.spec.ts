import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ResetPasswordDto } from './reset-password.dto';

const BASE = { email: 'user@example.com', code: '123456' };

async function errorsFor(payload: Record<string, unknown>) {
  const dto = plainToInstance(ResetPasswordDto, { ...BASE, ...payload });
  return validate(dto);
}

describe('ResetPasswordDto — password policy', () => {
  it('accepts a strong new password', async () => {
    const errors = await errorsFor({ newPassword: 'Str0ng!Pass' });
    expect(errors).toHaveLength(0);
  });

  it('rejects a new password with no digit', async () => {
    const errors = await errorsFor({ newPassword: 'Strong!Pass' });
    expect(errors.some((e) => e.property === 'newPassword')).toBe(true);
  });
});
