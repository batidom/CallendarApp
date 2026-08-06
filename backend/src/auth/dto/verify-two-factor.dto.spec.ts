import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { VerifyTwoFactorDto } from './verify-two-factor.dto';

async function errorsFor(payload: Record<string, unknown>) {
  const dto = plainToInstance(VerifyTwoFactorDto, payload);
  return validate(dto);
}

describe('VerifyTwoFactorDto', () => {
  it('accepts a valid 6-digit TOTP code', async () => {
    const errors = await errorsFor({
      twoFactorToken: 'abc123',
      code: '123456',
    });
    expect(errors).toHaveLength(0);
  });

  it('accepts a valid 10-character backup code', async () => {
    const errors = await errorsFor({
      twoFactorToken: 'abc123',
      code: 'A1B2C3D4E5',
    });
    expect(errors).toHaveLength(0);
  });

  it('rejects a missing twoFactorToken', async () => {
    const errors = await errorsFor({ code: '123456' });
    expect(errors.some((e) => e.property === 'twoFactorToken')).toBe(true);
  });

  it('rejects a code shorter than 6 characters', async () => {
    const errors = await errorsFor({ twoFactorToken: 'abc123', code: '123' });
    expect(errors.some((e) => e.property === 'code')).toBe(true);
  });

  it('rejects a code longer than 10 characters', async () => {
    const errors = await errorsFor({
      twoFactorToken: 'abc123',
      code: '12345678901',
    });
    expect(errors.some((e) => e.property === 'code')).toBe(true);
  });
});
