import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OAuth2Client } from 'google-auth-library';
// nodemailer's MIME builder, used standalone (no SMTP) — it turns a
// {from, to, subject, text, html} object into a well-formed RFC822 message
// (headers, multipart/alternative boundary, encoding) without us having to
// hand-roll that. See sendVerificationCode() for why this bypasses SMTP.
import MailComposer = require('nodemailer/lib/mail-composer');

// Sends real mail through the sender's own Gmail account via OAuth2, but
// through the Gmail REST API rather than SMTP.
//
// Confirmed by direct testing: an access token minted from our refresh token
// — same client, same scope (gmail.send), same account — is accepted by the
// Gmail REST API's messages.send (200, real delivery) but rejected by
// Gmail's SMTP XOAUTH2 login with "535 Username and Password not accepted".
// That's a known quirk, not a config mistake on our end: Gmail's SMTP AUTH
// path expects the broad https://mail.google.com/ scope, while the
// gmail.send scope (the correct, least-privilege one for the REST API) isn't
// honored there. Sending over the REST API instead sidesteps the whole SMTP
// layer and its scope quirk.
@Injectable()
export class MailerService {
  private readonly logger = new Logger(MailerService.name);
  private oauth2Client: OAuth2Client | null = null;

  constructor(private readonly config: ConfigService) {}

  private getOAuth2Client(): OAuth2Client {
    if (this.oauth2Client) return this.oauth2Client;

    const clientId = this.config.get<string>('GOOGLE_CLIENT_ID');
    const clientSecret = this.config.get<string>('GOOGLE_CLIENT_SECRET');
    const refreshToken = this.config.get<string>('GOOGLE_GMAIL_REFRESH_TOKEN');
    if (!clientId || !clientSecret || !refreshToken) {
      throw new Error(
        'GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET / GOOGLE_GMAIL_REFRESH_TOKEN are not fully set ' +
          'in .env — cannot send verification emails. Run `npm run gmail:auth`.',
      );
    }

    this.oauth2Client = new OAuth2Client(clientId, clientSecret);
    this.oauth2Client.setCredentials({ refresh_token: refreshToken });
    return this.oauth2Client;
  }

  async sendVerificationCode(to: string, code: string): Promise<void> {
    await this.send({
      to,
      subject: `${code} is your verification code`,
      text: `Your Calendar App verification code is ${code}. It expires in 15 minutes.`,
      html: `<p>Your Calendar App verification code is:</p><p style="font-size:28px;font-weight:bold;letter-spacing:4px">${code}</p><p>It expires in 15 minutes.</p>`,
    });
    this.logger.log(`Verification email sent to ${to}`);
  }

  async sendPasswordResetCode(to: string, code: string): Promise<void> {
    await this.send({
      to,
      subject: `${code} is your password reset code`,
      text: `Your Calendar App password reset code is ${code}. It expires in 15 minutes. If you didn't request this, you can ignore this email.`,
      html: `<p>Your Calendar App password reset code is:</p><p style="font-size:28px;font-weight:bold;letter-spacing:4px">${code}</p><p>It expires in 15 minutes. If you didn't request this, you can ignore this email.</p>`,
    });
    this.logger.log(`Password reset email sent to ${to}`);
  }

  private async send(mail: { to: string; subject: string; text: string; html: string }): Promise<void> {
    const user = this.config.get<string>('GMAIL_USER');
    if (!user) {
      throw new Error('GMAIL_USER is not set in .env — cannot send emails.');
    }

    const raw = await this.buildRawMessage({ ...mail, from: `"Calendar App" <${user}>` });

    const { token } = await this.getOAuth2Client().getAccessToken();
    const response = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ raw }),
    });
    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error(`Gmail API send failed (${response.status}): ${body}`);
    }
  }

  // Gmail API's messages.send expects the full RFC822 message,
  // base64url-encoded (- and _ instead of the standard base64 + and /, no
  // padding), as its "raw" field.
  private buildRawMessage(mail: {
    from: string;
    to: string;
    subject: string;
    text: string;
    html: string;
  }): Promise<string> {
    return new Promise((resolve, reject) => {
      new MailComposer(mail).compile().build((error: Error | null, message: Buffer) => {
        if (error) {
          reject(error);
          return;
        }
        resolve(message.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''));
      });
    });
  }
}
