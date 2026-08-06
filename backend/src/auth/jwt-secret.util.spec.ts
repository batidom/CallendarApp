import { loadJwtSecret } from './jwt-secret.util';

const configGet = (value: string | undefined) => ({ get: () => value }) as any;

describe('loadJwtSecret', () => {
  it('throws when JWT_SECRET is unset', () => {
    expect(() => loadJwtSecret(configGet(undefined))).toThrow();
  });

  it('throws when JWT_SECRET is an empty string', () => {
    expect(() => loadJwtSecret(configGet(''))).toThrow();
  });

  it('returns the configured secret', () => {
    expect(loadJwtSecret(configGet('a-real-secret'))).toBe('a-real-secret');
  });
});
