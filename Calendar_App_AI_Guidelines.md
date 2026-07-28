# System Architecture Project: Multi-platform Calendar Application (Outlook/Google Calendar Clone)
*Purpose: Initial Guidelines (Prompt Context) for an AI code generator.*

## 1. System Architecture (High Level)
*   **Client (App):** Flutter (Dart). Windows, Linux, Android support. Maintains a local SQLite database for offline mode.
*   **Backend (API):** Node.js with NestJS framework (TypeScript). Manages business logic, authorization, and communication with external APIs.
*   **Database (Server):** PostgreSQL.
*   **Task Queue (Background Jobs):** Redis + BullMQ (to handle delayed push notifications and Google synchronization).
*   **Communication:** REST API (asynchronous operations) and WebSockets (Socket.IO - real-time updates).

## 2. Database Schema (PostgreSQL)
Required main tables with relations:

**Table `users`**
*   `id` (UUID, PK)
*   `email` (VARCHAR, UNIQUE)
*   `password_hash` (VARCHAR)
*   `timezone` (VARCHAR) - default user timezone
*   `created_at` (TIMESTAMPTZ)

**Table `oauth_integrations`** (Google Calendar support)
*   `id` (UUID, PK)
*   `user_id` (UUID, FK -> users.id)
*   `provider` (VARCHAR) - e.g., 'GOOGLE'
*   `access_token` (VARCHAR)
*   `refresh_token` (VARCHAR)
*   `sync_token` (VARCHAR) - to track delta changes in Google API
*   `updated_at` (TIMESTAMPTZ)

**Table `events`**
*   `id` (UUID, PK)
*   `user_id` (UUID, FK -> users.id)
*   `title` (VARCHAR)
*   `description` (TEXT)
*   `start_time` (TIMESTAMPTZ)
*   `end_time` (TIMESTAMPTZ)
*   `is_all_day` (BOOLEAN)
*   `rrule` (VARCHAR) - recurrence rule (e.g., "FREQ=WEEKLY;BYDAY=MO,WE,FR") compliant with RFC 5545
*   `google_event_id` (VARCHAR, NULLABLE) - linkage to Google event ID
*   `created_at` (TIMESTAMPTZ)
*   `updated_at` (TIMESTAMPTZ)

**Table `event_reminders`** (Notifications)
*   `id` (UUID, PK)
*   `event_id` (UUID, FK -> events.id)
*   `minutes_before` (INTEGER) - minutes before the start time to send a notification
*   `type` (VARCHAR) - e.g., 'PUSH', 'EMAIL'

## 3. API & WebSockets Specification

### REST API (Main Endpoints)
*   **Auth:**
    *   `POST /auth/register` - local registration.
    *   `POST /auth/login` - returns JWT (JSON Web Token).
    *   `GET /auth/google` - initiates OAuth2 process.
*   **Events:**
    *   `GET /events?start={date}&end={date}` - fetch events.
    *   `POST /events` - create event.
    *   `PUT /events/:id` - update event.
    *   `DELETE /events/:id` - delete event.

### WebSockets (Socket.IO)
*   **Events received by the client (Listen):** `event:created`, `event:updated`, `event:deleted`
*   App reaction: The client updates the local SQLite database and refreshes the UI without querying the server again.

## 4. Client Application Architecture (Flutter)
*   **State Management:** Bloc or Riverpod for UI/logic separation.
*   **Local Database:** Drift (SQLite). Implement an identical table structure to PostgreSQL for the `events` table.
*   **System Tray (Windows/Linux):**
    *   Packages: `tray_manager`, `window_manager`.
    *   Logic: Hidden main window. Icon added to the system tray. Clicking it renders a fast, floating frameless window.
*   **Offline-First Synchronization:** Save to SQLite with an `is_synced = false` flag. Bulk upload events upon network restore.

## 5. Google Calendar Synchronization
*   **Authorization:** User grants OAuth2 consent for the `https://www.googleapis.com/auth/calendar` scope.
*   **Server -> Google:** Using Redis/BullMQ (asynchronously), the app sends a request to create the event in the Google API.
*   **Google -> Server (Webhooks):** NestJS subscribes to the API (watch). The webhook receives changes, fetches the delta (`sync_token`), saves it in PostgreSQL, and pushes it via WebSockets.

## 6. AI Voice Assistant Module
1.  **Listening (Offline):** `porcupine_flutter` package listens for a wake word (e.g., "Save event").
2.  **Recording:** Speech recording for the next 5-10 seconds.
3.  **Transcription (Backend):** `POST /ai/parse-audio` endpoint -> Whisper API -> LLM (GPT-4o/Llama).
4.  **Execution:** LLM returns a JSON object: `{"title": "Meeting", "start": "...", "duration": 120}`, which is then saved to the database.

## 7. Step-by-Step Implementation Plan
**Phase 1: Foundation (Backend & Database)**
1. Configure Docker (PostgreSQL). Initialize NestJS and migrations (Prisma/TypeORM). JWT auth and CRUD REST API for events.

**Phase 2: Base Client (Flutter)**
1. Calendar View, Drift (SQLite), connected to the REST API.

**Phase 3: Real-time, System Tray & Offline**
1. Socket.IO (NestJS + Flutter).
2. `tray_manager` for Windows.
3. Synchronization mechanism (Offline->Online).

**Phase 4: Google Calendar Integration**
1. Google Cloud Console, OAuth2 setup.
2. Redis sync (NestJS), Webhooks integration.

**Phase 5: AI Assistant**
1. Offline wake word detection (Flutter). Audio parsing endpoint (NestJS). Whisper & LLM integration.
