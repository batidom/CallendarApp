import { ConfigService } from '@nestjs/config';

/// Reads and validates JWT_SECRET — fails fast at startup rather than
/// silently falling back to a public, guessable default ('dev-secret'),
/// which would let anyone forge a valid access token for any user. Same
/// fail-fast reasoning as totp-crypto.util.ts's loadTotpEncryptionKey.
export function loadJwtSecret(config: ConfigService): string {
  const secret = config.get<string>('JWT_SECRET');
  if (!secret) {
    throw new Error(
      'JWT_SECRET is not set. Generate one with: ' +
        `node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"`,
    );
  }
  return secret;
}
