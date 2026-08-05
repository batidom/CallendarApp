# Backend

NestJS + PostgreSQL (Prisma) API for the Calendar App. See the [repo
root README](../README.md) for the full setup walkthrough (Docker,
`.env`, Gmail OAuth, running the client). This file covers day-to-day
backend development.

## Scripts

| Command                | Does what it says                                  |
| ----------------------- | --------------------------------------------------- |
| `npm run start:dev`     | Start the API in watch mode (`localhost:3000`)      |
| `npm run build`         | Compile to `dist/`                                  |
| `npm test`              | Run unit tests (Jest)                                |
| `npm run test:watch`    | Run tests in watch mode                              |
| `npm run test:cov`      | Run tests with coverage                              |
| `npm run lint`          | ESLint, autofixing what it can                       |
| `npm run format`        | Prettier, writing in place                           |
| `npm run prisma:migrate`| Create/apply a Prisma migration in dev               |
| `npm run prisma:studio` | Open Prisma Studio against the local database        |
| `npm run gmail:auth`    | One-time OAuth flow for the Gmail send credentials    |

## Project layout

```
backend/
  docker-compose.yml   # Postgres for local dev
  prisma/
    schema.prisma       # DB schema
    migrations/          # Applied migrations, in order
  src/
    auth/                # Register/login/JWT, email verification, password reset, account management
    events/               # Events CRUD, invites, attachments
    friends/               # Friend requests
    groups/                 # Groups + membership
    notifications/           # In-app notification records
    assistant/                # AI chat assistant (Ollama) + voice transcription (Whisper)
    prisma/                    # PrismaService (global module)
    common/decorators/          # @CurrentUser()
    app.module.ts
    main.ts
  scripts/
    get-gmail-oauth-token.ts    # One-time OAuth setup for Gmail sending
```

## Notes

- Real-time sync uses client-side polling, not WebSockets — there's no
  Socket.IO layer in this backend.
- Recurrence expansion (RRULE) happens entirely client-side; the
  backend only stores/round-trips the rule string.
