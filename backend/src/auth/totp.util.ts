import { randomBytes } from 'crypto';
import * as OTPAuth from 'otpauth';

const TOTP_ISSUER = 'CallendarApp';
const BACKUP_CODE_COUNT = 10;
const BACKUP_CODE_BYTES = 5; // -> 10 hex chars per code

function totpFor(base32Secret: string): OTPAuth.TOTP {
  return new OTPAuth.TOTP({
    issuer: TOTP_ISSUER,
    secret: OTPAuth.Secret.fromBase32(base32Secret),
  });
}

/// A fresh base32 secret for a new setup attempt (20 random bytes / 160 bits).
export function generateTotpSecretBase32(): string {
  return new OTPAuth.Secret({ size: 20 }).base32;
}

/// otpauth://totp/CallendarApp:<email>?secret=...&issuer=CallendarApp&...
/// — what the client renders as a QR code (via qr_flutter) for the user's
/// authenticator app to scan.
export function buildOtpauthUrl(email: string, base32Secret: string): string {
  const totp = totpFor(base32Secret);
  totp.label = email;
  return totp.toString();
}

/// True if `code` is valid for `base32Secret` within the default ±1 step
/// (30s) window, i.e. tolerates ordinary clock drift between the server and
/// the user's device.
export function verifyTotpCode(base32Secret: string, code: string): boolean {
  return totpFor(base32Secret).validate({ token: code }) !== null;
}

/// 10 single-use recovery codes, each 10 uppercase hex chars — plain crypto,
/// no extra dependency, matching this codebase's existing preference for
/// crypto.randomBytes-derived tokens.
export function generateBackupCodes(): string[] {
  return Array.from({ length: BACKUP_CODE_COUNT }, () =>
    randomBytes(BACKUP_CODE_BYTES).toString('hex').toUpperCase(),
  );
}
