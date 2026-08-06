import {
  Body,
  Controller,
  Delete,
  Get,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  AuthenticatedUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AuthService } from './auth.service';
import { ChangePasswordDto } from './dto/change-password.dto';
import { DeleteAccountDto } from './dto/delete-account.dto';
import { DisableTwoFactorDto } from './dto/disable-two-factor.dto';
import { EnableTwoFactorDto } from './dto/enable-two-factor.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { LoginDto } from './dto/login.dto';
import { LogoutDto } from './dto/logout.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';
import { ResendTwoFactorDto } from './dto/resend-two-factor.dto';
import { ResendVerificationDto } from './dto/resend-verification.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { UpdateEmailDto } from './dto/update-email.dto';
import { UpdateUsernameDto } from './dto/update-username.dto';
import { VerifyEmailDto } from './dto/verify-email.dto';
import { VerifyTwoFactorDto } from './dto/verify-two-factor.dto';

// Applied to every unauthenticated endpoint that either checks a password or
// a short numeric/code guess (login, the various email codes, 2FA) — the
// app-wide default in app.module.ts is far too loose to stop a brute-force
// attempt on any of these specifically. 5 attempts/minute per IP is well
// above anything a real user hits (typos, a slow authenticator app, etc.)
// but cuts an automated guesser down to a few hundred attempts/day.
const AUTH_THROTTLE = { default: { limit: 5, ttl: 60_000 } };

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Throttle(AUTH_THROTTLE)
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Throttle(AUTH_THROTTLE)
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Throttle(AUTH_THROTTLE)
  @Post('verify-email')
  verifyEmail(@Body() dto: VerifyEmailDto) {
    return this.authService.verifyEmail(dto);
  }

  @Throttle(AUTH_THROTTLE)
  @Post('resend-verification')
  resendVerification(@Body() dto: ResendVerificationDto) {
    return this.authService.resendVerification(dto);
  }

  @Throttle(AUTH_THROTTLE)
  @Post('forgot-password')
  forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto);
  }

  @Throttle(AUTH_THROTTLE)
  @Post('reset-password')
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto);
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto.refreshToken);
  }

  // Completes a login that was paused by a TWO_FACTOR_REQUIRED response
  // from POST /login — no guard, since the caller doesn't have a JWT yet.
  @Throttle(AUTH_THROTTLE)
  @Post('2fa/verify')
  verifyTwoFactor(@Body() dto: VerifyTwoFactorDto) {
    return this.authService.verifyTwoFactorLogin(dto);
  }

  // Re-sends the emailed code for a pending email-OTP login (a no-op for a
  // pending TOTP login) — same no-guard reasoning as 2fa/verify above.
  @Throttle(AUTH_THROTTLE)
  @Post('2fa/resend')
  resendTwoFactor(@Body() dto: ResendTwoFactorDto) {
    return this.authService.resendTwoFactorLoginCode(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('2fa/totp/setup')
  setupTotp(@CurrentUser() user: AuthenticatedUser) {
    return this.authService.setupTotp(user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Post('2fa/totp/enable')
  enableTotp(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: EnableTwoFactorDto,
  ) {
    return this.authService.enableTotp(user.id, dto);
  }

  // Sends a fresh one-time code to the caller's own email — used both to
  // confirm enabling the email-OTP method and to get a live code before
  // disabling it (see AuthService.requestEmailTwoFactorCode).
  @Throttle(AUTH_THROTTLE)
  @UseGuards(JwtAuthGuard)
  @Post('2fa/email/request-code')
  requestEmailTwoFactorCode(@CurrentUser() user: AuthenticatedUser) {
    return this.authService.requestEmailTwoFactorCode(user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Post('2fa/email/enable')
  enableEmailTwoFactor(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: EnableTwoFactorDto,
  ) {
    return this.authService.enableEmailTwoFactor(user.id, dto);
  }

  // Method-agnostic: works for whichever method (totp/email_otp) is
  // currently active, or a backup code either way.
  @UseGuards(JwtAuthGuard)
  @Post('2fa/disable')
  async disableTwoFactor(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: DisableTwoFactorDto,
  ) {
    await this.authService.disableTwoFactor(user.id, dto);
    return {};
  }

  @Post('logout')
  async logout(@Body() dto: LogoutDto) {
    await this.authService.logout(dto.refreshToken);
    return {};
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  getMe(@CurrentUser() user: AuthenticatedUser) {
    return this.authService.getProfile(user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('username')
  updateUsername(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdateUsernameDto,
  ) {
    return this.authService.updateUsername(user.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('email')
  updateEmail(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdateEmailDto,
  ) {
    return this.authService.updateEmail(user.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('password')
  async changePassword(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ChangePasswordDto,
  ) {
    await this.authService.changePassword(user.id, dto);
    return {};
  }

  @UseGuards(JwtAuthGuard)
  @Delete('account')
  async deleteAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: DeleteAccountDto,
  ) {
    await this.authService.deleteAccount(user.id, dto);
    return {};
  }
}
