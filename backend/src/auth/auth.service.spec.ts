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
    deleteMany: jest.Mock;
    create: jest.Mock;
  };
  emailTwoFactorCode: {
    findUnique: jest.Mock;
    upsert: jest.Mock;
    delete: jest.Mock;
    deleteMany: jest.Mock;
  };
  twoFactorBackupCode: {
    findMany: jest.Mock;
    update: jest.Mock;
    deleteMany: jest.Mock;
    createMany: jest.Mock;
  };
  refreshToken: { create: jest.Mock };
  $transaction: jest.Mock;
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
  let mailer: { sendTwoFactorCode: jest.Mock };
  let service: AuthService;

  beforeEach(() => {
    jest.clearAllMocks();
    (bcrypt.compare as jest.Mock).mockResolvedValue(true);
    (bcrypt.hash as jest.Mock).mockImplementation(
      (value: string) => `hashed:${value}`,
    );

    prisma = {
      user: { findUnique: jest.fn(), update: jest.fn().mockResolvedValue({}) },
      pendingTwoFactorLogin: {
        findUnique: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
        deleteMany: jest.fn().mockResolvedValue({}),
        create: jest.fn().mockResolvedValue({}),
      },
      emailTwoFactorCode: {
        findUnique: jest.fn(),
        upsert: jest.fn().mockResolvedValue({}),
        delete: jest.fn().mockResolvedValue({}),
        deleteMany: jest.fn().mockResolvedValue({}),
      },
      twoFactorBackupCode: {
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn().mockResolvedValue({}),
        deleteMany: jest.fn().mockResolvedValue({}),
        createMany: jest.fn().mockResolvedValue({}),
      },
      refreshToken: { create: jest.fn().mockResolvedValue({}) },
      $transaction: jest.fn((ops: Promise<unknown>[]) => Promise.all(ops)),
    };
    jwtService = { sign: jest.fn().mockReturnValue('signed-jwt') };
    config = {
      get: jest.fn((key: string) => {
        if (key === 'TOTP_ENCRYPTION_KEY')
          return ENCRYPTION_KEY.toString('base64');
        return undefined;
      }),
    };
    mailer = { sendTwoFactorCode: jest.fn().mockResolvedValue(undefined) };
    service = new AuthService(
      prisma as never,
      jwtService as never,
      config as never,
      mailer as never,
    );
  });

  describe('login()', () => {
    it('throws TWO_FACTOR_REQUIRED (method totp) and does not mint tokens when TOTP 2FA is enabled', async () => {
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
        response: expect.objectContaining({
          code: 'TWO_FACTOR_REQUIRED',
          method: 'totp',
        }),
      });

      expect(prisma.pendingTwoFactorLogin.create).toHaveBeenCalledTimes(1);
      expect(mailer.sendTwoFactorCode).not.toHaveBeenCalled();
      expect(jwtService.sign).not.toHaveBeenCalled();
      expect(prisma.refreshToken.create).not.toHaveBeenCalled();
    });

    it('throws TWO_FACTOR_REQUIRED (method email_otp) and emails a code when email 2FA is enabled', async () => {
      prisma.user.findUnique.mockResolvedValue(
        buildUser({ twoFactorEnabled: true, twoFactorMethod: 'email_otp' }),
      );

      await expect(
        service.login({ email: 'user@example.com', password: 'x' }),
      ).rejects.toMatchObject({
        response: expect.objectContaining({
          code: 'TWO_FACTOR_REQUIRED',
          method: 'email_otp',
        }),
      });

      expect(mailer.sendTwoFactorCode).toHaveBeenCalledWith(
        'user@example.com',
        expect.any(String),
      );
      expect(prisma.pendingTwoFactorLogin.create).toHaveBeenCalledTimes(1);
    });

    it('logs in normally (no TWO_FACTOR_REQUIRED) when 2FA is disabled', async () => {
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

  describe('verifyTwoFactorLogin() — email_otp method', () => {
    const user = buildUser({
      twoFactorEnabled: true,
      twoFactorMethod: 'email_otp',
    });

    it('succeeds against the emailed code and deletes both pending rows', async () => {
      prisma.pendingTwoFactorLogin.findUnique.mockResolvedValue({
        id: 'pending-1',
        method: 'email_otp',
        attempts: 0,
        expiresAt: new Date(Date.now() + 60_000),
        user,
      });
      prisma.emailTwoFactorCode.findUnique.mockResolvedValue({
        codeHash: service['hashToken']('654321'),
        expiresAt: new Date(Date.now() + 60_000),
      });

      const result = await service.verifyTwoFactorLogin({
        twoFactorToken: 'raw-token',
        code: '654321',
      });

      expect(result.accessToken).toBe('signed-jwt');
      expect(prisma.emailTwoFactorCode.delete).toHaveBeenCalledWith({
        where: { userId: 'user-1' },
      });
      expect(prisma.pendingTwoFactorLogin.delete).toHaveBeenCalledWith({
        where: { id: 'pending-1' },
      });
    });

    it('falls back to a backup code when the emailed code is wrong', async () => {
      prisma.pendingTwoFactorLogin.findUnique.mockResolvedValue({
        id: 'pending-1',
        method: 'email_otp',
        attempts: 0,
        expiresAt: new Date(Date.now() + 60_000),
        user,
      });
      prisma.emailTwoFactorCode.findUnique.mockResolvedValue({
        codeHash: service['hashToken']('654321'),
        expiresAt: new Date(Date.now() + 60_000),
      });
      prisma.twoFactorBackupCode.findMany.mockResolvedValue([
        { id: 'backup-1', codeHash: 'hashed:BACKUP123' },
      ]);
      (bcrypt.compare as jest.Mock).mockImplementation(
        (plain: string, hash: string) =>
          Promise.resolve(hash === `hashed:${plain}`),
      );

      const result = await service.verifyTwoFactorLogin({
        twoFactorToken: 'raw-token',
        code: 'BACKUP123',
      });

      expect(result.accessToken).toBe('signed-jwt');
    });
  });

  describe('resendTwoFactorLoginCode()', () => {
    it('re-issues and emails a fresh code for a pending email_otp login', async () => {
      prisma.pendingTwoFactorLogin.findUnique.mockResolvedValue({
        userId: 'user-1',
        method: 'email_otp',
        expiresAt: new Date(Date.now() + 60_000),
        user: buildUser(),
      });
      prisma.emailTwoFactorCode.findUnique.mockResolvedValue(null);

      const result = await service.resendTwoFactorLoginCode({
        twoFactorToken: 'raw-token',
      });

      expect(result.email).toBe('user@example.com');
      expect(mailer.sendTwoFactorCode).toHaveBeenCalledTimes(1);
    });

    it('does nothing for a pending totp login', async () => {
      prisma.pendingTwoFactorLogin.findUnique.mockResolvedValue({
        userId: 'user-1',
        method: 'totp',
        expiresAt: new Date(Date.now() + 60_000),
        user: buildUser(),
      });

      await service.resendTwoFactorLoginCode({ twoFactorToken: 'raw-token' });

      expect(mailer.sendTwoFactorCode).not.toHaveBeenCalled();
    });
  });

  describe('enableEmailTwoFactor()', () => {
    it('enables email_otp and returns backup codes on a correct code', async () => {
      prisma.user.findUnique.mockResolvedValue(buildUser());
      prisma.emailTwoFactorCode.findUnique.mockResolvedValue({
        codeHash: service['hashToken']('111111'),
        expiresAt: new Date(Date.now() + 60_000),
      });

      const result = await service.enableEmailTwoFactor('user-1', {
        code: '111111',
      });

      expect(result.backupCodes).toHaveLength(10);
      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    });

    it('rejects an incorrect code', async () => {
      prisma.user.findUnique.mockResolvedValue(buildUser());
      prisma.emailTwoFactorCode.findUnique.mockResolvedValue({
        codeHash: service['hashToken']('111111'),
        expiresAt: new Date(Date.now() + 60_000),
      });

      await expect(
        service.enableEmailTwoFactor('user-1', { code: '000000' }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('disableTwoFactor()', () => {
    it('rejects on an incorrect password before ever checking the code', async () => {
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);
      prisma.user.findUnique.mockResolvedValue(
        buildUser({ twoFactorEnabled: true }),
      );

      await expect(
        service.disableTwoFactor('user-1', {
          password: 'wrong',
          code: '123456',
        }),
      ).rejects.toThrow(UnauthorizedException);

      expect(prisma.twoFactorBackupCode.findMany).not.toHaveBeenCalled();
    });

    it('rejects when 2FA is not enabled', async () => {
      prisma.user.findUnique.mockResolvedValue(
        buildUser({ twoFactorEnabled: false }),
      );

      await expect(
        service.disableTwoFactor('user-1', { password: 'x', code: '123456' }),
      ).rejects.toThrow();
    });

    it('disables email_otp 2FA against a requested email code', async () => {
      prisma.user.findUnique.mockResolvedValue(
        buildUser({ twoFactorEnabled: true, twoFactorMethod: 'email_otp' }),
      );
      prisma.emailTwoFactorCode.findUnique.mockResolvedValue({
        codeHash: service['hashToken']('222222'),
        expiresAt: new Date(Date.now() + 60_000),
      });

      await service.disableTwoFactor('user-1', {
        password: 'x',
        code: '222222',
      });

      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    });
  });
});
