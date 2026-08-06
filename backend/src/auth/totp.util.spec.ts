import * as OTPAuth from 'otpauth';
import {
  buildOtpauthUrl,
  generateBackupCodes,
  generateTotpSecretBase32,
  verifyTotpCode,
} from './totp.util';

function codeAt(secret: string, timestamp: number): string {
  return OTPAuth.TOTP.generate({
    secret: OTPAuth.Secret.fromBase32(secret),
    timestamp,
  });
}

describe('generateTotpSecretBase32', () => {
  it('returns a non-empty base32 string', () => {
    expect(generateTotpSecretBase32().length).toBeGreaterThan(0);
  });

  it('returns a different secret on each call', () => {
    expect(generateTotpSecretBase32()).not.toBe(generateTotpSecretBase32());
  });
});

describe('buildOtpauthUrl', () => {
  it('includes the issuer, email label, and secret', () => {
    const secret = generateTotpSecretBase32();
    const url = buildOtpauthUrl('user@example.com', secret);
    expect(url).toContain('issuer=CallendarApp');
    expect(url).toContain(encodeURIComponent('user@example.com'));
    expect(url).toContain(`secret=${secret}`);
  });
});

describe('verifyTotpCode', () => {
  const secret = generateTotpSecretBase32();

  it('accepts a code generated for the current time', () => {
    expect(verifyTotpCode(secret, codeAt(secret, Date.now()))).toBe(true);
  });

  it('accepts a code from the previous 30s step (clock drift tolerance)', () => {
    expect(verifyTotpCode(secret, codeAt(secret, Date.now() - 30_000))).toBe(
      true,
    );
  });

  it('rejects a code from more than one step away', () => {
    expect(verifyTotpCode(secret, codeAt(secret, Date.now() - 90_000))).toBe(
      false,
    );
  });

  it('rejects an arbitrary wrong code', () => {
    expect(verifyTotpCode(secret, '000000')).toBe(false);
  });
});

describe('generateBackupCodes', () => {
  it('returns 10 unique 10-character hex codes', () => {
    const codes = generateBackupCodes();
    expect(codes).toHaveLength(10);
    expect(new Set(codes).size).toBe(10);
    for (const code of codes) {
      expect(code).toMatch(/^[0-9A-F]{10}$/);
    }
  });
});
