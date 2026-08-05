/**
 * One-time setup script: exchanges a Google OAuth consent for a refresh
 * token that lets the backend send verification emails via Gmail's API
 * without storing your account password or an App Password.
 *
 * Prerequisites (done once, in Google Cloud Console):
 *   1. Create/select a project, enable the "Gmail API".
 *   2. Credentials > Create Credentials > OAuth client ID > "Desktop app".
 *      (Desktop app type auto-allows the http://localhost loopback redirect
 *      this script uses — no redirect URI to register.)
 *   3. Put the resulting Client ID / Client Secret into backend/.env as
 *      GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET.
 *   4. Under "Audience" (OAuth consent screen), add GMAIL_USER's address as
 *      a test user if the app is in "Testing" publishing status.
 *
 * Run with: npm run gmail:auth
 * On success, paste the printed refresh token into .env as
 * GOOGLE_GMAIL_REFRESH_TOKEN.
 */
import { createServer } from 'http';
import { config } from 'dotenv';
import { OAuth2Client } from 'google-auth-library';

config();

const PORT = 53682;
const REDIRECT_URI = `http://localhost:${PORT}/oauth2callback`;
const SCOPE = 'https://www.googleapis.com/auth/gmail.send';

async function main() {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    console.error('Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in backend/.env first.');
    process.exit(1);
  }

  const oauth2Client = new OAuth2Client(clientId, clientSecret, REDIRECT_URI);
  const authUrl = oauth2Client.generateAuthUrl({
    access_type: 'offline',
    // Forces Google to hand back a refresh token even if this account
    // already granted this app access before (Google only issues one on
    // the *first* consent otherwise).
    prompt: 'consent',
    scope: [SCOPE],
  });

  console.log('\nOpen this URL, sign in as the Gmail account you want to send from, and approve:\n');
  console.log(authUrl + '\n');
  console.log(`Waiting for the redirect back to ${REDIRECT_URI} ...`);

  const code = await new Promise<string>((resolve, reject) => {
    const server = createServer((req, res) => {
      const url = new URL(req.url ?? '', REDIRECT_URI);
      const code = url.searchParams.get('code');
      const error = url.searchParams.get('error');
      res.end(error ? `Error: ${error}. You can close this tab.` : 'Success — you can close this tab.');
      server.close();
      if (error) reject(new Error(error));
      else if (code) resolve(code);
      else reject(new Error('No code in redirect'));
    });
    server.listen(PORT);
  });

  const { tokens } = await oauth2Client.getToken(code);
  if (!tokens.refresh_token) {
    console.error(
      '\nNo refresh token returned. This usually means the account already has a token issued — ' +
        'revoke access at https://myaccount.google.com/permissions and run this script again.',
    );
    process.exit(1);
  }

  console.log('\nSuccess. Add this line to backend/.env:\n');
  console.log(`GOOGLE_GMAIL_REFRESH_TOKEN=${tokens.refresh_token}\n`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
