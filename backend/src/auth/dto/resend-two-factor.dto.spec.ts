import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ResendTwoFactorDto } from './resend-two-factor.dto';

async function errorsFor(payload: Record<string, unknown>) {
  const dto = plainToInstance(ResendTwoFactorDto, payload);
  return validate(dto);
}

describe('ResendTwoFactorDto', () => {
  it('accepts a valid payload', async () => {
    const errors = await errorsFor({ twoFactorToken: 'abc123' });
    expect(errors).toHaveLength(0);
  });

  it('rejects a missing twoFactorToken', async () => {
    const errors = await errorsFor({});
    expect(errors.some((e) => e.property === 'twoFactorToken')).toBe(true);
  });
});
