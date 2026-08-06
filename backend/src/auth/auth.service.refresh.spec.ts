import { UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';

interface MockPrisma {
  refreshToken: {
    findUnique: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
    deleteMany: jest.Mock;
    create: jest.Mock;
  };
}

function buildUser(overrides: Record<string, unknown> = {}) {
  return {
    id: 'user-1',
    email: 'user@example.com',
    name: 'Test',
    surname: null,
    username: 'testuser',
    timezone: null,
    ...overrides,
  };
}

describe('AuthService — refresh token rotation', () => {
  let prisma: MockPrisma;
  let jwtService: { sign: jest.Mock };
  let config: { get: jest.Mock };
  let service: AuthService;

  beforeEach(() => {
    prisma = {
      refreshToken: {
        findUnique: jest.fn(),
        update: jest.fn().mockResolvedValue({}),
        delete: jest.fn().mockResolvedValue({}),
        deleteMany: jest.fn().mockResolvedValue({}),
        create: jest.fn().mockResolvedValue({}),
      },
    };
    jwtService = { sign: jest.fn().mockReturnValue('signed-jwt') };
    config = {
      get: jest.fn((key: string) =>
        key === 'TOTP_ENCRYPTION_KEY'
          ? Buffer.alloc(32).toString('base64')
          : undefined,
      ),
    };
    service = new AuthService(
      prisma as never,
      jwtService as never,
      config as never,
      {} as never,
    );
  });

  it('rotates a valid, unrevoked token: marks it revoked and mints a fresh pair', async () => {
    prisma.refreshToken.findUnique.mockResolvedValue({
      id: 'row-1',
      userId: 'user-1',
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      user: buildUser(),
    });

    const result = await service.refresh('raw-token');

    expect(result.accessToken).toBe('signed-jwt');
    expect(prisma.refreshToken.update).toHaveBeenCalledWith({
      where: { id: 'row-1' },
      data: { revokedAt: expect.any(Date) },
    });
    expect(prisma.refreshToken.deleteMany).not.toHaveBeenCalledWith({
      where: { userId: 'user-1' },
    });
  });

  it('rejects an unknown token without revoking anything (nothing to revoke)', async () => {
    prisma.refreshToken.findUnique.mockResolvedValue(null);

    await expect(service.refresh('raw-token')).rejects.toThrow(
      UnauthorizedException,
    );
    expect(prisma.refreshToken.deleteMany).not.toHaveBeenCalled();
  });

  it('rejects an expired-but-never-used token, deleting only that row', async () => {
    prisma.refreshToken.findUnique.mockResolvedValue({
      id: 'row-1',
      userId: 'user-1',
      revokedAt: null,
      expiresAt: new Date(Date.now() - 1000),
      user: buildUser(),
    });

    await expect(service.refresh('raw-token')).rejects.toThrow(
      UnauthorizedException,
    );
    expect(prisma.refreshToken.delete).toHaveBeenCalledWith({
      where: { id: 'row-1' },
    });
    expect(prisma.refreshToken.deleteMany).not.toHaveBeenCalled();
  });

  it('treats reuse of an already-revoked token as theft: revokes every session for that user', async () => {
    prisma.refreshToken.findUnique.mockResolvedValue({
      id: 'row-1',
      userId: 'user-1',
      revokedAt: new Date(Date.now() - 1000),
      expiresAt: new Date(Date.now() + 60_000),
      user: buildUser(),
    });

    await expect(service.refresh('raw-token')).rejects.toThrow(
      UnauthorizedException,
    );
    expect(prisma.refreshToken.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'user-1' },
    });
    // Never reaches the mint-fresh-tokens step.
    expect(jwtService.sign).not.toHaveBeenCalled();
  });
});
