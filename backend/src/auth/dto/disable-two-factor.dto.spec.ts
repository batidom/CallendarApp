import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { DisableTwoFactorDto } from './disable-two-factor.dto';

async function errorsFor(payload: Record<string, unknown>) {
  const dto = plainToInstance(DisableTwoFactorDto, payload);
  return validate(dto);
}

describe('DisableTwoFactorDto', () => {
  it('accepts a valid password + TOTP code', async () => {
    const errors = await errorsFor({ password: 'hunter2', code: '123456' });
    expect(errors).toHaveLength(0);
  });

  it('accepts a valid password + backup code', async () => {
    const errors = await errorsFor({ password: 'hunter2', code: 'A1B2C3D4E5' });
    expect(errors).toHaveLength(0);
  });

  it('rejects a missing password', async () => {
    const errors = await errorsFor({ code: '123456' });
    expect(errors.some((e) => e.property === 'password')).toBe(true);
  });

  it('rejects a code shorter than 6 or longer than 10 characters', async () => {
    expect(
      (await errorsFor({ password: 'hunter2', code: '123' })).some(
        (e) => e.property === 'code',
      ),
    ).toBe(true);
    expect(
      (await errorsFor({ password: 'hunter2', code: '12345678901' })).some(
        (e) => e.property === 'code',
      ),
    ).toBe(true);
  });
});
