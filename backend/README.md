# Calendar App Backend — Phase 1

NestJS + PostgreSQL (Prisma) backend. This phase covers: JWT auth (register/login) and
a per-user Events CRUD REST API. Real-time (Socket.IO), Google Calendar sync, and the
AI voice assistant are implemented in later phases per `Calendar_App_AI_Guidelines.md`.

## 1. Install prerequisites (one-time)

None of these are installed on this machine yet — install them before running anything:

1. **Node.js LTS (20.x)** — https://nodejs.org
2. **Docker Desktop** (for PostgreSQL) — https://www.docker.com/products/docker-desktop
   - On Windows, Docker Desktop requires WSL2. If Docker isn't an option, install
     PostgreSQL 16 directly instead and update `DATABASE_URL` accordingly.

Verify:
```
node -v
npm -v
docker -v
```

## 2. Start PostgreSQL

```
cd backend
docker compose up -d
```

This starts Postgres on `localhost:5432` with user/password/db `calendar`/`calendar`/`calendar_app`
(see `docker-compose.yml`).

## 3. Configure environment

```
copy .env.example .env
```

Edit `.env` and set `JWT_SECRET` to a long random string. Leave the Google/OpenAI
placeholders blank for now — they aren't used until Phase 4/5.

## 4. Install dependencies & run migrations

```
npm install
npx prisma migrate dev --name init
```

This creates the `users`, `oauth_integrations`, `events`, and `event_reminders` tables.

## 5. Run the API

```
npm run start:dev
```

Server listens on `http://localhost:3000` (or `PORT` from `.env`).

## 6. Try it out

```bash
# Register
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"password123","timezone":"Europe/Warsaw"}'

# Login (copy the accessToken from the response)
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"password123"}'

# Create an event (replace TOKEN)
curl -X POST http://localhost:3000/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"title":"Standup","startTime":"2026-07-29T09:00:00Z","endTime":"2026-07-29T09:15:00Z"}'

# List events in a date range
curl "http://localhost:3000/events?start=2026-07-01T00:00:00Z&end=2026-08-01T00:00:00Z" \
  -H "Authorization: Bearer TOKEN"
```

## What's not in Phase 1

- `GET /auth/google` (OAuth2) — Phase 4
- WebSocket events (`event:created`/`updated`/`deleted`) — Phase 3
- Redis/BullMQ background jobs — Phase 3/4
- AI voice assistant endpoint — Phase 5

## Project layout

```
backend/
  docker-compose.yml       # Postgres for local dev
  prisma/schema.prisma      # DB schema (matches guidelines section 2)
  src/
    auth/                   # register/login, JWT strategy & guard
    events/                 # events CRUD, scoped to the authenticated user
    prisma/                 # PrismaService (global module)
    common/decorators/      # @CurrentUser()
    app.module.ts
    main.ts
```
