import {
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomBytes, randomInt, createHash } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { ChangePasswordDto } from './dto/change-password.dto';
import { DeleteAccountDto } from './dto/delete-account.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { LoginDto } from './dto/login.dto';
import { MailerService } from './mailer.service';
import { RegisterDto } from './dto/register.dto';
import { ResendVerificationDto } from './dto/resend-verification.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { UpdateEmailDto } from './dto/update-email.dto';
import { UpdateUsernameDto } from './dto/update-username.dto';
import { VerifyEmailDto } from './dto/verify-email.dto';

const SALT_ROUNDS = 10;
const REFRESH_TOKEN_BYTES = 48;
const VERIFICATION_CODE_TTL_MINUTES = 15;
const VERIFICATION_RESEND_COOLDOWN_SECONDS = 60;
const MAX_VERIFICATION_ATTEMPTS = 5;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly mailer: MailerService,
  ) {}

  // No tokens are returned here — the account exists but is unusable (see
  // login()) until the emailed code is redeemed via verifyEmail(), so there's
  // nothing to log the caller into yet.
  async register(dto: RegisterDto): Promise<{ email: string }> {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (existing) {
      throw new ConflictException('Email is already registered');
    }

    const usernameTaken = await this.prisma.user.findUnique({
      where: { username: dto.username },
    });
    if (usernameTaken) {
      throw new ConflictException('Username is already taken');
    }

    const passwordHash = await bcrypt.hash(dto.password, SALT_ROUNDS);
    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        name: dto.name,
        surname: dto.surname,
        username: dto.username,
        timezone: dto.timezone,
      },
    });

    await this.issueVerificationCode(user.id, user.email);
    return { email: user.email };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const passwordMatches = await bcrypt.compare(
      dto.password,
      user.passwordHash,
    );
    if (!passwordMatches) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.emailVerified) {
      throw new ForbiddenException({
        code: 'EMAIL_NOT_VERIFIED',
        message: 'Please verify your email before signing in',
        email: user.email,
      });
    }

    return this.buildAuthResponse(user);
  }

  // Success logs the user in immediately (same shape as login()/register()
  // would have) since redeeming the code IS the missing piece of proving
  // they own the address.
  async verifyEmail(dto: VerifyEmailDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid code');
    }
    if (user.emailVerified) {
      return this.buildAuthResponse(user);
    }

    const pending = await this.prisma.emailVerificationCode.findUnique({
      where: { userId: user.id },
    });
    if (!pending || pending.expiresAt.getTime() <= Date.now()) {
      throw new UnauthorizedException(
        'Code is invalid or expired — request a new one',
      );
    }
    if (pending.attempts >= MAX_VERIFICATION_ATTEMPTS) {
      throw new UnauthorizedException('Too many attempts — request a new code');
    }

    const codeMatches = pending.codeHash === this.hashToken(dto.code);
    if (!codeMatches) {
      await this.prisma.emailVerificationCode.update({
        where: { userId: user.id },
        data: { attempts: { increment: 1 } },
      });
      throw new UnauthorizedException('Incorrect code');
    }

    const [verifiedUser] = await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: user.id },
        data: { emailVerified: true },
      }),
      this.prisma.emailVerificationCode.delete({ where: { userId: user.id } }),
    ]);

    return this.buildAuthResponse(verifiedUser);
  }

  async resendVerification(
    dto: ResendVerificationDto,
  ): Promise<{ email: string }> {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    // Same response whether or not the account exists / is already verified,
    // so this endpoint can't be used to probe which emails are registered.
    if (!user || user.emailVerified) {
      return { email: dto.email };
    }

    const existing = await this.prisma.emailVerificationCode.findUnique({
      where: { userId: user.id },
    });
    const cooldownRemainingMs =
      existing != null
        ? existing.createdAt.getTime() +
          VERIFICATION_RESEND_COOLDOWN_SECONDS * 1000 -
          Date.now()
        : 0;
    if (cooldownRemainingMs > 0) {
      return { email: user.email };
    }

    await this.issueVerificationCode(user.id, user.email);
    return { email: user.email };
  }

  private async issueVerificationCode(
    userId: string,
    email: string,
  ): Promise<void> {
    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const expiresAt = new Date(
      Date.now() + VERIFICATION_CODE_TTL_MINUTES * 60 * 1000,
    );
    await this.prisma.emailVerificationCode.upsert({
      where: { userId },
      create: { userId, codeHash: this.hashToken(code), expiresAt },
      update: { codeHash: this.hashToken(code), expiresAt, attempts: 0 },
    });
    await this.mailer.sendVerificationCode(email, code);
  }

  async forgotPassword(dto: ForgotPasswordDto): Promise<{ email: string }> {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    // Same response whether or not the account exists, so this endpoint
    // can't be used to probe which emails are registered.
    if (!user) {
      return { email: dto.email };
    }

    const existing = await this.prisma.passwordResetCode.findUnique({
      where: { userId: user.id },
    });
    const cooldownRemainingMs =
      existing != null
        ? existing.createdAt.getTime() +
          VERIFICATION_RESEND_COOLDOWN_SECONDS * 1000 -
          Date.now()
        : 0;
    if (cooldownRemainingMs > 0) {
      return { email: user.email };
    }

    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const expiresAt = new Date(
      Date.now() + VERIFICATION_CODE_TTL_MINUTES * 60 * 1000,
    );
    await this.prisma.passwordResetCode.upsert({
      where: { userId: user.id },
      create: { userId: user.id, codeHash: this.hashToken(code), expiresAt },
      update: { codeHash: this.hashToken(code), expiresAt, attempts: 0 },
    });
    await this.mailer.sendPasswordResetCode(user.email, code);
    return { email: user.email };
  }

  // Redeeming a valid code sets the new password AND marks the email
  // verified — this doubles as the recovery path for an account that
  // registered but never finished the original verification, since proving
  // you received this code is the same proof of address ownership.
  // Every existing refresh token is revoked too: if the old password had
  // leaked, a session minted with it shouldn't survive the reset.
  async resetPassword(dto: ResetPasswordDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid code');
    }

    const pending = await this.prisma.passwordResetCode.findUnique({
      where: { userId: user.id },
    });
    if (!pending || pending.expiresAt.getTime() <= Date.now()) {
      throw new UnauthorizedException(
        'Code is invalid or expired — request a new one',
      );
    }
    if (pending.attempts >= MAX_VERIFICATION_ATTEMPTS) {
      throw new UnauthorizedException('Too many attempts — request a new code');
    }

    const codeMatches = pending.codeHash === this.hashToken(dto.code);
    if (!codeMatches) {
      await this.prisma.passwordResetCode.update({
        where: { userId: user.id },
        data: { attempts: { increment: 1 } },
      });
      throw new UnauthorizedException('Incorrect code');
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, SALT_ROUNDS);
    const [updatedUser] = await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: user.id },
        data: { passwordHash, emailVerified: true },
      }),
      this.prisma.passwordResetCode.delete({ where: { userId: user.id } }),
      this.prisma.refreshToken.deleteMany({ where: { userId: user.id } }),
    ]);

    return this.buildAuthResponse(updatedUser);
  }

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      surname: user.surname,
      username: user.username,
      timezone: user.timezone,
      emailVerified: user.emailVerified,
    };
  }

  // The public handle other users search for when adding a friend — lower
  // stakes than email/password, but still asks for the current password
  // (like every other identity-changing action here) rather than trusting
  // whoever's holding a still-valid access token.
  async updateUsername(userId: string, dto: UpdateUsernameDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const passwordMatches = await bcrypt.compare(
      dto.password,
      user.passwordHash,
    );
    if (!passwordMatches) {
      throw new UnauthorizedException('Incorrect password');
    }

    if (dto.newUsername !== user.username) {
      const taken = await this.prisma.user.findUnique({
        where: { username: dto.newUsername },
      });
      if (taken) {
        throw new ConflictException('Username is already taken');
      }
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { username: dto.newUsername },
    });
    return { username: updated.username };
  }

  // Re-verifies the NEW address the same way a fresh registration would —
  // the row is switched over immediately (not staged separately) so a typo
  // is caught the same way a typo'd registration email would be: nothing
  // else changes and the old address stays gone either way, but the account
  // just sits unverified until resend-verification/a correct code fixes it.
  // The caller's own already-issued access token keeps working regardless
  // (it's checked by user id, not by matching the embedded email) — only a
  // fresh /auth/login is blocked by the EMAIL_NOT_VERIFIED check until the
  // new address is confirmed.
  async updateEmail(userId: string, dto: UpdateEmailDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const passwordMatches = await bcrypt.compare(
      dto.password,
      user.passwordHash,
    );
    if (!passwordMatches) {
      throw new UnauthorizedException('Incorrect password');
    }
    if (dto.newEmail === user.email) {
      throw new ConflictException('That is already your email address');
    }

    const taken = await this.prisma.user.findUnique({
      where: { email: dto.newEmail },
    });
    if (taken) {
      throw new ConflictException('Email is already registered');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { email: dto.newEmail, emailVerified: false },
    });
    await this.issueVerificationCode(userId, dto.newEmail);
    return { email: dto.newEmail };
  }

  // Every other session is revoked on a successful change, same reasoning
  // as resetPassword: if the old password had leaked, a session minted with
  // it shouldn't survive. The caller's own session keeps working off its
  // still-valid access token; only a later silent refresh (or a fresh
  // login) elsewhere needs the new password.
  async changePassword(userId: string, dto: ChangePasswordDto): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const passwordMatches = await bcrypt.compare(
      dto.currentPassword,
      user.passwordHash,
    );
    if (!passwordMatches) {
      throw new UnauthorizedException('Incorrect current password');
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, SALT_ROUNDS);
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { passwordHash },
      }),
      this.prisma.refreshToken.deleteMany({ where: { userId } }),
    ]);
  }

  // Right-to-erasure account deletion. The User row is never hard-deleted —
  // it's anonymized in place and kept as a tombstone (see the deletedAt
  // comment on the schema) so foreign keys from OTHER users' data don't
  // break. What actually happens:
  //  - Data that's solely this user's (tokens, pending codes, OAuth
  //    integration, friendships, groups they own, their membership in
  //    others' groups, events nobody else was ever invited to, and their own
  //    invites onto other people's events) is hard-deleted.
  //  - Events they own that someone else was invited to are left alone
  //    entirely — deleting those would silently remove something an invitee
  //    already accepted off their calendar, which isn't required to erase
  //    this user's personal data (the organizer field just resolves to the
  //    anonymized tombstone from here on) and would be needlessly
  //    destructive to a third party.
  //  - Likewise, attachments this user uploaded onto someone ELSE's event
  //    are left alone — the file isn't this user's personal data once it's
  //    part of another person's shared event.
  async deleteAccount(userId: string, dto: DeleteAccountDto): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const passwordMatches = await bcrypt.compare(
      dto.password,
      user.passwordHash,
    );
    if (!passwordMatches) {
      throw new UnauthorizedException('Incorrect password');
    }

    const soleEvents = await this.prisma.event.findMany({
      where: { userId, invites: { none: {} } },
      select: { id: true },
    });

    await this.prisma.$transaction([
      this.prisma.refreshToken.deleteMany({ where: { userId } }),
      this.prisma.emailVerificationCode.deleteMany({ where: { userId } }),
      this.prisma.passwordResetCode.deleteMany({ where: { userId } }),
      this.prisma.oAuthIntegration.deleteMany({ where: { userId } }),
      this.prisma.friendship.deleteMany({
        where: { OR: [{ requesterId: userId }, { addresseeId: userId }] },
      }),
      this.prisma.eventInvite.deleteMany({ where: { invitedUserId: userId } }),
      this.prisma.notification.deleteMany({ where: { userId } }),
      // Groups are the owner's private contact-grouping tool, not a shared
      // entity (see the Group model comment) — deleting one just removes
      // its members' rows, it doesn't erase any of THEIR data.
      this.prisma.group.deleteMany({ where: { ownerId: userId } }),
      this.prisma.groupMember.deleteMany({ where: { userId } }),
      this.prisma.event.deleteMany({
        where: { id: { in: soleEvents.map((e) => e.id) } },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: {
          email: `deleted-${userId}@deleted.invalid`,
          name: 'Deleted User',
          surname: null,
          username: `deleted_${userId.replace(/-/g, '')}`,
          // Unreachable through any real login (the email above matches no
          // real address), but overwritten anyway so the real hash doesn't
          // linger in the row.
          passwordHash: randomBytes(32).toString('hex'),
          emailVerified: false,
          timezone: null,
          deletedAt: new Date(),
        },
      }),
    ]);
  }

  // Mints a fresh access+refresh pair for a still-valid refresh token and
  // rotates it (the old row is deleted, not just extended) — a client that
  // touches the backend at least once within REFRESH_TOKEN_EXPIRES_IN_DAYS
  // never has to show the login screen again, but a stolen token can only
  // ever be replayed once before this invalidates it.
  async refresh(refreshToken: string) {
    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });

    if (!stored || stored.expiresAt.getTime() <= Date.now()) {
      if (stored)
        await this.prisma.refreshToken
          .delete({ where: { id: stored.id } })
          .catch(() => undefined);
      throw new UnauthorizedException('Refresh token is invalid or expired');
    }

    await this.prisma.refreshToken.delete({ where: { id: stored.id } });
    return this.buildAuthResponse(stored.user);
  }

  // Best-effort: revoking the token server-side is what actually matters
  // for security, but a missing/already-expired one shouldn't stop the
  // client from clearing its own local session.
  async logout(refreshToken?: string): Promise<void> {
    if (!refreshToken) return;
    await this.prisma.refreshToken
      .delete({ where: { tokenHash: this.hashToken(refreshToken) } })
      .catch(() => undefined);
  }

  private async buildAuthResponse(user: {
    id: string;
    email: string;
    name: string;
    surname: string | null;
    username: string;
    timezone: string | null;
  }) {
    const accessToken = this.jwtService.sign({
      sub: user.id,
      email: user.email,
    });
    const refreshToken = await this.issueRefreshToken(user.id);
    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        surname: user.surname,
        username: user.username,
        timezone: user.timezone,
      },
    };
  }

  private async issueRefreshToken(userId: string): Promise<string> {
    const raw = randomBytes(REFRESH_TOKEN_BYTES).toString('hex');
    const days = Number(
      this.config.get<string>('REFRESH_TOKEN_EXPIRES_IN_DAYS', '30'),
    );
    const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
    await this.prisma.refreshToken.create({
      data: { userId, tokenHash: this.hashToken(raw), expiresAt },
    });
    return raw;
  }

  // Refresh tokens are high-entropy random strings, not user-chosen
  // secrets, so a plain fast hash (vs. bcrypt's deliberately slow one) is
  // enough to keep a DB dump from being directly replayable, while still
  // allowing an indexed exact-match lookup by hash.
  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}
