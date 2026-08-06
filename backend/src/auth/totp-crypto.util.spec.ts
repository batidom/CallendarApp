import { randomBytes } from 'crypto';
import {
  decryptTotpSecret,
  encryptTotpSecret,
  loadTotpEncryptionKey,
} from './totp-crypto.util';

const KEY = randomBytes(32);
const OTHER_KEY = randomBytes(32);

describe('encryptTotpSecret / decryptTotpSecret', () => {
  it('round-trips a secret', () => {
    const secret = 'JBSWY3DPEHPK3PXP';
    const encrypted = encryptTotpSecret(secret, KEY);
    expect(decryptTotpSecret(encrypted, KEY)).toBe(secret);
  });

  it('produces different ciphertext for the same plaintext each time (random IV)', () => {
    const a = encryptTotpSecret('JBSWY3DPEHPK3PXP', KEY);
    const b = encryptTotpSecret('JBSWY3DPEHPK3PXP', KEY);
    expect(a).not.toBe(b);
  });

  it('throws when decrypting with the wrong key', () => {
    const encrypted = encryptTotpSecret('JBSWY3DPEHPK3PXP', KEY);
    expect(() => decryptTotpSecret(encrypted, OTHER_KEY)).toThrow();
  });

  it('throws when the ciphertext has been tampered with', () => {
    const encrypted = encryptTotpSecret('JBSWY3DPEHPK3PXP', KEY);
    const [version, iv, authTag, ciphertext] = encrypted.split(':');
    const tamperedByte = Buffer.from(ciphertext, 'base64');
    tamperedByte[0] = tamperedByte[0] ^ 0xff;
    const tampered = [
      version,
      iv,
      authTag,
      tamperedByte.toString('base64'),
    ].join(':');
    expect(() => decryptTotpSecret(tampered, KEY)).toThrow();
  });

  it('throws for an unrecognized version prefix or malformed shape', () => {
    expect(() => decryptTotpSecret('v2:a:b:c', KEY)).toThrow();
    expect(() => decryptTotpSecret('not-even-close', KEY)).toThrow();
  });
});

describe('loadTotpEncryptionKey', () => {
  const configGet = (value: string | undefined) =>
    ({ get: () => value }) as any;

  it('throws when TOTP_ENCRYPTION_KEY is unset', () => {
    expect(() => loadTotpEncryptionKey(configGet(undefined))).toThrow();
  });

  it('throws when the key does not decode to exactly 32 bytes', () => {
    expect(() =>
      loadTotpEncryptionKey(
        configGet(Buffer.from('too short').toString('base64')),
      ),
    ).toThrow();
  });

  it('returns a 32-byte buffer for a valid key', () => {
    const key = loadTotpEncryptionKey(configGet(KEY.toString('base64')));
    expect(key).toEqual(KEY);
  });
});
