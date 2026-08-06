import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { EnableTwoFactorDto } from './enable-two-factor.dto';

async function errorsFor(payload: Record<string, unknown>) {
  const dto = plainToInstance(EnableTwoFactorDto, payload);
  return validate(dto);
}

describe('EnableTwoFactorDto', () => {
  it('accepts a valid 6-digit code', async () => {
    const errors = await errorsFor({ code: '123456' });
    expect(errors).toHaveLength(0);
  });

  it('rejects a missing code', async () => {
    const errors = await errorsFor({});
    expect(errors.some((e) => e.property === 'code')).toBe(true);
  });

  it('rejects a code that is not exactly 6 characters', async () => {
    expect(
      (await errorsFor({ code: '12345' })).some((e) => e.property === 'code'),
    ).toBe(true);
    expect(
      (await errorsFor({ code: '1234567' })).some((e) => e.property === 'code'),
    ).toBe(true);
  });
});
