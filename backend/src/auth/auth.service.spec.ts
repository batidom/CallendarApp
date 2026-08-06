import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import * as OTPAuth from 'otpauth';
import { UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { encryptTotpSecret } from './totp-crypto.util';

jest.mock('bcrypt');

const ENCRYPTION_KEY = randomBytes(32);

interface MockPrisma {
  user: { findUnique: jest.Mock; update: jest.Mock };
  pendingTwoFactorLogin: {
    findUnique: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
    create: jest.Mock;
  };
  twoFactorBackupCode: { findMany: jest.Mock };
  refreshToken: { create: jest.Mock };
}

function buildUser(overrides: Record<string, unknown> = {}) {
  return {
    id: 'user-1',
    email: 'user@example.com',
    passwordHash: 'hashed',
    name: 'Test',
    surname: null,
    username: 'testuser',
    timezone: null,
    emailVerified: true,
    twoFactorEnabled: false,
    twoFactorMethod: null,
    twoFactorSecret: null,
    ...overrides,
  };
}

function codeFor(secret: string, offsetMs = 0): string {
  return OTPAuth.TOTP.generate({
    secret: OTPAuth.Secret.fromBase32(secret),
    timestamp: Date.now() + offsetMs,
  });
}

describe('AuthService — two-factor authentication', () => {
  let prisma: MockPrisma;
  let jwtService: { sign: jest.Mock };
  let config: { get: jest.Mock };
  let service: AuthService;

  beforeEach(() => {
    jest.clearAllMocks();
    (bcrypt.compare as jest.Mock).mockResolvedValue(true);
    (bcrypt.hash as jest.Mock).mockImplementation(
      (value: string) => `hashed:${value}`,
    );

    prisma = {
      user: { findUnique: jest.fn(), update: jest.fn() },
      pendingTwoFactorLogin: {
        findUnique: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        create: jest.fn().mockResolvedValue({}),
      },
      twoFactorBackupCode: { findMany: jest.fn().mockResolvedValue([]) },
      refreshToken: { create: jest.fn().mockResolvedValue({}) },
    };
    jwtService = { sign: jest.fn().mockReturnValue('signed-jwt') };
    config = {
      get: jest.fn((key: string) => {
        if (key === 'TOTP_ENCRYPTION_KEY')
          return ENCRYPTION_KEY.toString('base64');
        return undefined;
      }),
    };
    service = new AuthService(
      prisma as never,
      jwtService as never,
      config as never,
      {} as never,
    );
  });

  describe('login()', () => {
    it('throws TOTP_REQUIRED and does not mint tokens when 2FA is enabled', async () => {
      const secret = new OTPAuth.Secret({ size: 20 }).base32;
      prisma.user.findUnique.mockResolvedValue(
        buildUser({
          twoFactorEnabled: true,
          twoFactorMethod: 'totp',
          twoFactorSecret: encryptTotpSecret(secret, ENCRYPTION_KEY),
        }),
      );

      await expect(
        service.login({ email: 'user@example.com', password: 'x' }),
      ).rejects.toMatchObject({
        response: expect.objectContaining({ code: 'TOTP_REQUIRED' }),
      });

      expect(prisma.pendingTwoFactorLogin.create).toHaveBeenCalledTimes(1);
      expect(jwtService.sign).not.toHaveBeenCalled();
      expect(prisma.refreshToken.create).not.toHaveBeenCalled();
    });

    it('logs in normally (no TOTP_REQUIRED) when 2FA is disabled', async () => {
      prisma.user.findUnique.mockResolvedValue(buildUser());

      const result = await service.login({
        email: 'user@example.com',
        password: 'x',
      });

      expect(result.accessToken).toBe('signed-jwt');
      expect(prisma.pendingTwoFactorLogin.create).not.toHaveBeenCalled();
    });
  });

  describe('verifyTwoFactorLogin()', () => {
    const secret = new OTPAuth.Secret({ size: 20 }).base32;
    const user = buildUser({
      twoFactorEnabled: true,
      twoFactorSecret: encryptTotpSecret(secret, ENCRYPTION_KEY),
    });

    it('succeeds and deletes the pending row on a correct code', async () => {
      prisma.pendingTwoFactorLogin.findUnique.mockResolvedValue({
        id: 'pending-1',
        attempts: 0,
        expiresAt: new Date(Date.now() + 60_000),
        user,
      });

      const result = await service.verifyTwoFactorLogin({
        twoFactorToken: 'raw-token',
        code: codeFor(secret),
      });

      expect(result.accessToken).toBe('signed-jwt');
      expect(prisma.pendingTwoFactorLogin.delete).toHaveBeenCalledWith({
        where: { id: 'pending-1' },
      });
    });

    it('increments attempts and rejects on an incorrect code', async () => {
      prisma.pendingTwoFactorLogin.findUnique.mockResolvedValue({
        id: 'pending-1',
        attempts: 0,
        expiresAt: new Date(Date.now() + 60_000),
        user,
      });

      await expect(
        service.verifyTwoFactorLogin({
          twoFactorToken: 'raw-token',
          code: '000000',
        }),
      ).rejects.toThrow(UnauthorizedException);

      expect(prisma.pendingTwoFactorLogin.update).toHaveBeenCalledWith({
        where: { id: 'pending-1' },
        data: { attempts: { increment: 1 } },
      });
      expect(prisma.pendingTwoFactorLogin.delete).not.toHaveBeenCalled();
    });

    it('rejects once the attempts cap is reached, even with a correct code', async () => {
      prisma.pendingTwoFactorLogin.findUnique.mockResolvedValue({
        id: 'pending-1',
        attempts: 5,
        expiresAt: new Date(Date.now() + 60_000),
        user,
      });

      await expect(
        service.verifyTwoFactorLogin({
          twoFactorToken: 'raw-token',
          code: codeFor(secret),
        }),
      ).rejects.toThrow(UnauthorizedException);

      // Never even reached the point of checking the code.
      expect(prisma.pendingTwoFactorLogin.update).not.toHaveBeenCalled();
      expect(prisma.pendingTwoFactorLogin.delete).not.toHaveBeenCalled();
    });

    it('rejects an expired pending row even with a correct code', async () => {
      prisma.pendingTwoFactorLogin.findUnique.mockResolvedValue({
        id: 'pending-1',
        attempts: 0,
        expiresAt: new Date(Date.now() - 1000),
        user,
      });

      await expect(
        service.verifyTwoFactorLogin({
          twoFactorToken: 'raw-token',
          code: codeFor(secret),
        }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('rejects when no pending row is found', async () => {
      prisma.pendingTwoFactorLogin.findUnique.mockResolvedValue(null);

      await expect(
        service.verifyTwoFactorLogin({
          twoFactorToken: 'raw-token',
          code: '123456',
        }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('disableTotp()', () => {
    it('rejects on an incorrect password before ever checking the code', async () => {
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);
      prisma.user.findUnique.mockResolvedValue(
        buildUser({ twoFactorEnabled: true }),
      );

      await expect(
        service.disableTotp('user-1', { password: 'wrong', code: '123456' }),
      ).rejects.toThrow(UnauthorizedException);

      expect(prisma.twoFactorBackupCode.findMany).not.toHaveBeenCalled();
    });

    it('rejects when 2FA is not enabled', async () => {
      prisma.user.findUnique.mockResolvedValue(
        buildUser({ twoFactorEnabled: false }),
      );

      await expect(
        service.disableTotp('user-1', { password: 'x', code: '123456' }),
      ).rejects.toThrow();
    });
  });
});
