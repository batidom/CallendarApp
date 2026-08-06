import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { RegisterDto } from './register.dto';

const BASE = { email: 'user@example.com', name: 'Test', username: 'testuser' };

async function errorsFor(payload: Record<string, unknown>) {
  const dto = plainToInstance(RegisterDto, { ...BASE, ...payload });
  return validate(dto);
}

describe('RegisterDto — password policy', () => {
  it('accepts a password with lowercase, uppercase, digit, and symbol', async () => {
    const errors = await errorsFor({ password: 'Str0ng!Pass' });
    expect(errors).toHaveLength(0);
  });

  it('rejects a password missing an uppercase letter', async () => {
    const errors = await errorsFor({ password: 'str0ng!pass' });
    expect(errors.some((e) => e.property === 'password')).toBe(true);
  });

  it('rejects a password missing a lowercase letter', async () => {
    const errors = await errorsFor({ password: 'STR0NG!PASS' });
    expect(errors.some((e) => e.property === 'password')).toBe(true);
  });

  it('rejects a password missing a digit', async () => {
    const errors = await errorsFor({ password: 'Strong!Pass' });
    expect(errors.some((e) => e.property === 'password')).toBe(true);
  });

  it('rejects a password missing a symbol', async () => {
    const errors = await errorsFor({ password: 'Str0ngPass' });
    expect(errors.some((e) => e.property === 'password')).toBe(true);
  });

  it('rejects a password shorter than 8 characters', async () => {
    const errors = await errorsFor({ password: 'Sh0rt!' });
    expect(errors.some((e) => e.property === 'password')).toBe(true);
  });

  it('rejects a password longer than 72 characters', async () => {
    const errors = await errorsFor({ password: `Str0ng!${'a'.repeat(70)}` });
    expect(errors.some((e) => e.property === 'password')).toBe(true);
  });
});
