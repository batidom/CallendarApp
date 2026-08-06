import { ConfigService } from '@nestjs/config';
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12; // recommended GCM nonce size
const KEY_BYTES = 32; // AES-256
const FORMAT_VERSION = 'v1';

/// Reads and validates TOTP_ENCRYPTION_KEY once at startup — fails fast
/// with a clear error rather than letting a misconfigured key surface later
/// as a confusing decrypt failure mid-login.
export function loadTotpEncryptionKey(config: ConfigService): Buffer {
  const raw = config.get<string>('TOTP_ENCRYPTION_KEY');
  if (!raw) {
    throw new Error(
      'TOTP_ENCRYPTION_KEY is not set. Generate one with: ' +
        `node -e "console.log(require('crypto').randomBytes(${KEY_BYTES}).toString('base64'))"`,
    );
  }
  const key = Buffer.from(raw, 'base64');
  if (key.length !== KEY_BYTES) {
    throw new Error(
      `TOTP_ENCRYPTION_KEY must decode to exactly ${KEY_BYTES} bytes (got ${key.length})`,
    );
  }
  return key;
}

/// Encrypts a TOTP secret for storage in User.twoFactorSecret. Unlike a
/// password, a TOTP secret must be recovered in its original form to
/// compute a code for comparison, so a one-way hash isn't an option —
/// encrypting it means a raw DB dump alone can't be replayed against the
/// user's authenticator app, only a DB dump PLUS this separate key can.
/// AES-256-GCM is authenticated (tampering is detected via the auth tag),
/// unlike AES-CBC. Returns "v1:<iv>:<authTag>:<ciphertext>" (all base64) as
/// a single delimited string so it fits the existing nullable text column;
/// the version prefix leaves room to change the algorithm later without
/// breaking rows encrypted under the old one.
export function encryptTotpSecret(plaintext: string, key: Buffer): string {
  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv(ALGORITHM, key, iv);
  const ciphertext = Buffer.concat([
    cipher.update(plaintext, 'utf8'),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();
  return [
    FORMAT_VERSION,
    iv.toString('base64'),
    authTag.toString('base64'),
    ciphertext.toString('base64'),
  ].join(':');
}

/// Inverse of encryptTotpSecret. Throws if the version tag is unrecognized
/// or GCM auth-tag verification fails (tampered/corrupted ciphertext, or
/// wrong key).
export function decryptTotpSecret(stored: string, key: Buffer): string {
  const parts = stored.split(':');
  if (parts.length !== 4 || parts[0] !== FORMAT_VERSION) {
    throw new Error('Unrecognized TOTP secret format');
  }
  const [, ivB64, authTagB64, ciphertextB64] = parts;
  const decipher = createDecipheriv(
    ALGORITHM,
    key,
    Buffer.from(ivB64, 'base64'),
  );
  decipher.setAuthTag(Buffer.from(authTagB64, 'base64'));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(ciphertextB64, 'base64')),
    decipher.final(),
  ]);
  return plaintext.toString('utf8');
}
