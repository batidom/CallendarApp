# Calendar App

A full-stack, offline-first calendar app with event sharing, friends & groups,
reminders, and a local AI assistant. Built as a personal project to explore a
NestJS/Prisma backend paired with a Flutter desktop client that stays usable
without a network connection.

## Features

- **Events** — one-off and recurring events, drag-and-drop scheduling, a
  "someday" backlog for undated tasks.
- **Offline-first sync** — the Flutter client keeps a local SQLite cache
  (Drift) and syncs to the backend in the background, so the calendar stays
  fully usable offline and catches up automatically once reconnected.
- **Sharing** — invite friends to an event, see who owns it and who else is
  on it, and see pending invites directly on the calendar grid before you've
  even responded to them.
- **Friends & groups** — add friends, organize them into groups, and invite
  a whole group to an event at once.
- **Notifications** — in-app notifications for friend requests and invites,
  with an optional sound; separate due-date reminders with a choice of
  in-app popup or native Windows notification and a configurable sound.
- **Account management** — email verification, password reset, and
  self-service email/username/password changes and account deletion.
- **AI assistant** — a chat assistant that can create/update/delete events
  from natural language, with voice input transcribed locally via Whisper.
  Runs entirely against a local Ollama model — no data leaves your machine.
- **Localization** — English and Polish, with more straightforward to add.

## Tech stack

**Backend** — NestJS, Prisma, PostgreSQL, JWT auth (rotating refresh
tokens), Gmail API for transactional email.

**Client** — Flutter (Windows desktop primary target, Android supported),
Riverpod for state management, Drift for the local offline cache,
`table_calendar` for the grid.

**AI assistant (optional)** — [Ollama](https://ollama.com) for the chat
model, a local Whisper server for speech-to-text.

## Project structure

```
backend/    NestJS API (auth, events, friends, groups, notifications, assistant)
  prisma/   Schema + migrations
client/     Flutter app (lib/screens, lib/repositories, lib/data, ...)
```

## Getting started

### Prerequisites

- Node.js 20+
- Docker Desktop (for PostgreSQL)
- Flutter SDK
- Optional, for the AI assistant: [Ollama](https://ollama.com) running
  locally and a Whisper server for voice transcription

### Backend

```bash
cd backend
cp .env.example .env        # fill in JWT_SECRET at minimum
docker compose up -d        # starts PostgreSQL on localhost:5432
npm install
npx prisma migrate deploy
npm run start:dev           # http://localhost:3000
```

Email sending (verification codes, password resets) uses the Gmail API and
is **required** — registration and password reset both fail until
`GMAIL_USER`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and
`GOOGLE_GMAIL_REFRESH_TOKEN` are set. Run `npm run gmail:auth` for a
one-time OAuth flow that prints the refresh token to paste into `.env`.

### Client

```bash
cd client
flutter pub get
dart run build_runner build
flutter run -d windows      # or -d <android-device-id>
```

**Docker Desktop must already be running** before starting the backend,
since the app connects to PostgreSQL eagerly on boot.

## License

MIT — see [LICENSE](LICENSE).
