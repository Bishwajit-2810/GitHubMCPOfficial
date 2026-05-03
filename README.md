# GitHubMCP

A full-stack GitHub automation suite with an MCP server for Claude Desktop/Cursor, a REST API backend for Flutter, and an interactive mobile app — all powered by GitHub API and AI.

**12 MCP tools** for AI-assisted GitHub automation:

- Repository management (files, branches, PRs)
- GitHub Projects v2 (tasks, fields, status)
- RAG-powered codebase Q&A

---

## Table of Contents

- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Environment Variables](#environment-variables)
- [Backend Setup](#backend-setup)
- [Frontend Setup](#frontend-setup)
- [Running Everything](#running-everything)
- [Auth Flow (BFF)](#auth-flow-bff)
- [API Quick Reference](#api-quick-reference)
- [MCP Tools](#mcp-tools)
- [Database & RAG](#database--rag)
- [Development & Testing](#development--testing)
- [Troubleshooting](#troubleshooting)

---

## Architecture

```
┌─────────────┐     Firebase ID token     ┌────────────────────────────┐
│  Frontend   │ ──────────────────────── ▶│  BFF API (port 8091)       │
│  (Flutter)  │ ◀─────────── JWT ──────── │  FastAPI + Alembic         │
└─────────────┘                           │  Firebase Auth (Google++)  │
                                          │  GitHub OAuth + Fernet     │
                                          │  SQLAlchemy + PostgreSQL   │
                                          └────────────────────────────┘

┌──────────────────────┐
│  Claude / Cursor     │ ──── MCP/SSE ────▶  MCP Server (port 8090)
└──────────────────────┘                     FastMCP — 12 Tools
```

**Three layers:**

- **MCP Server (8090)** — FastMCP with SSE transport; 12 tools used directly by Claude Desktop, Cursor, or any MCP client
- **BFF API (8091)** — FastAPI backend-for-frontend; handles Firebase auth, GitHub OAuth, REST wrappers for Flutter app
- **Flutter App** — Mobile/web frontend with Android, iOS, and web support

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/Bishwajit-2810/GitHubMCPOfficial.git
cd GitHubMCP

# 2. Install uv (skip if already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 3. Install backend dependencies
cd backend
uv venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
uv pip install -e .

# 4. Start PostgreSQL (Docker recommended)
docker run -d \
  --name githubmcp-pg \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=githubmcp \
  -p 5434:5432 \
  pgvector/pgvector:pg16

# 5. Configure environment
cp .env.example .env
# Edit .env with your values (see Environment Variables below)

# 6. Run database migrations
alembic upgrade head

# 7. Index codebase for RAG (optional, one-time)
uv run python ingest.py

# 8. Start MCP server (Terminal 1)
uv run python server.py --port 8090

# 9. Start BFF API (Terminal 2)
uv run python api_server.py --port 8091

# 10. Start Flutter frontend (Terminal 3)
cd ../frontend
flutter pub get
flutter run -d android   # or: ios, chrome, windows, macos, linux
```

**Interactive API docs:** http://localhost:8091/docs  
**MCP tools inspector:** `npx @modelcontextprotocol/inspector`

---

## Environment Variables

Create `backend/.env` with the following:

### GitHub (MCP + BFF)

```env
# MCP server uses this PAT to call GitHub API
GITHUB_TOKEN=ghp_...           # PAT with repo, project, read:org scopes
GITHUB_OWNER=your-username     # Default owner for MCP tools
GITHUB_REPO=your-repo          # Default repo for MCP tools
PROJECT_ID=2                   # GitHub Projects v2 board number
```

### BFF — Authentication

```env
# Firebase (choose one)
FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/serviceAccount.json
# OR
FIREBASE_PROJECT_ID=your-firebase-project-id   # uses Application Default Credentials

# JWT settings (BFF signs JWTs after Firebase login)
JWT_SECRET=change-me-to-a-long-random-string
JWT_ALGORITHM=HS256            # optional, default HS256
JWT_EXPIRATION=3600            # optional, seconds (default 3600)

# Fernet key for encrypting GitHub OAuth tokens at rest
# Generate with: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
TOKEN_ENCRYPTION_KEY=your-fernet-key
```

### BFF — GitHub OAuth App

```env
GITHUB_CLIENT_ID=Ov23li...
GITHUB_CLIENT_SECRET=...
GITHUB_OAUTH_REDIRECT_URI=http://localhost:3000/oauth/callback
```

### BFF — Server

```env
API_PORT=8091                  # optional, default 8091
API_HOST=0.0.0.0               # optional, default 0.0.0.0
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
LOG_LEVEL=INFO                 # DEBUG | INFO | WARNING | ERROR
```

### Database

```env
# PostgreSQL for BFF (users, tokens, context, audit logs)
DATABASE_URL=postgresql://postgres:postgres@localhost:5434/githubmcp

# PostgreSQL for RAG vector store (can be same DB or separate)
POSTGRES_URL=postgresql://postgres:postgres@localhost:5434/ai_db

# Alternative: SQLite for local dev (no Docker needed)
# DATABASE_URL=sqlite:///./dev.db
```

### RAG / AI

```env
GROQ_API_KEY=gsk_...
RAG_VECTOR_DB=pgvector         # pgvector | chroma | both  (default: pgvector)
RAG_SKIP_LOCAL_DOCS=true
RAG_CHROMA_DIR=./chroma_store
```

---

## Backend Setup

### Prerequisites

| Tool              | Version | Install                                                                  |
| ----------------- | ------- | ------------------------------------------------------------------------ |
| Python            | 3.11+   | [python.org](https://python.org)                                         |
| uv                | latest  | `curl -LsSf https://astral.sh/uv/install.sh \| sh`                       |
| PostgreSQL        | 14+     | [Docker](https://docker.com) or [postgresql.org](https://postgresql.org) |
| Docker (optional) | latest  | [docker.com](https://docker.com)                                         |

### Step 1 — Install Dependencies

```bash
cd backend
uv venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
uv pip install -e .
```

### Step 2 — Start PostgreSQL

**Option A: Docker (recommended)**

```bash
docker run -d \
  --name githubmcp-pg \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=githubmcp \
  -p 5434:5432 \
  pgvector/pgvector:pg16

# Verify
docker ps | grep githubmcp-pg
```

**Option B: Local PostgreSQL**

```bash
# macOS
brew install postgresql && brew services start postgresql

# Ubuntu/Debian
sudo apt-get install postgresql postgresql-contrib && sudo systemctl start postgresql

# Then create the database
createdb -U postgres githubmcp
```

**Option C: SQLite (local dev, no Docker)**

Set `DATABASE_URL=sqlite:///./dev.db` in `.env` (auto-used by tests)

### Step 3 — Configure `.env`

```bash
cp .env.example .env
# Edit .env with all values from Environment Variables section above
```

### Step 4 — Run Database Migrations

```bash
cd backend
alembic upgrade head
```

Creates four tables:

- `users` — Firebase UID, email, display name
- `oauth_connections` — encrypted GitHub tokens per user
- `user_context` — selected owner/repo/project per user
- `audit_logs` — API call history

### Step 5 — Index Codebase for RAG (Optional)

```bash
cd backend
uv run python ingest.py

# Re-index after repo changes
uv run python ingest.py --reingest
```

---

## Running the Backend

Open two separate terminals:

**Terminal 1 — MCP Server (port 8090)**

```bash
cd backend
source .venv/bin/activate
uv run python server.py --port 8090
```

**Terminal 2 — BFF REST API (port 8091)**

```bash
cd backend
source .venv/bin/activate
uv run python api_server.py --port 8091
```

API docs available at: `http://localhost:8091/docs`

### Alternative: uvicorn with hot-reload

```bash
uv run uvicorn server:app --host 0.0.0.0 --port 8090
uv run uvicorn api_server:app --host 0.0.0.0 --port 8091 --reload
```

---

## Running Backend Tests

```bash
cd backend
pytest tests/ -v
```

Optional flags:

```bash
pytest tests/ -v -s                                              # with print output
pytest tests/test_auth.py -v                                    # single file
pytest tests/ --cov=github_mcp/api --cov-report=term-missing   # with coverage
```

---

## Frontend Setup

### Prerequisites

| Tool           | Version  | Install                                                     |
| -------------- | -------- | ----------------------------------------------------------- |
| Flutter        | 3.11+    | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart           | 3.0+     | (included with Flutter)                                     |
| iOS Xcode      | 14+      | macOS only; `xcode-select --install`                        |
| Android Studio | Giraffe+ | [android.dev](https://developer.android.com/studio)         |

### Step 1 — Install Flutter Dependencies

```bash
cd frontend
flutter pub get
flutter analyze   # check for issues
```

### Step 2 — Configure API Base URL

Edit [frontend/lib/config/constants.dart](frontend/lib/config/constants.dart):

```dart
class Constants {
  // Android emulator → use 10.0.2.2 to reach localhost on host
  static const String apiBaseUrl = 'http://10.0.2.2:8091/api/v1';

  // iOS simulator / web → use localhost
  // static const String apiBaseUrl = 'http://localhost:8091/api/v1';

  static const String githubOAuthClientId = 'YOUR_GITHUB_OAUTH_CLIENT_ID';
  static const String githubOAuthRedirectUri = 'githubmcp://oauth/callback';
}
```

### Step 3 — Firebase Setup

Firebase is **required** for authentication (Google Sign-In and Email/Password). See [frontend/config.md](frontend/config.md) for full setup.

**Quick steps:**

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Google** and **Email/Password** sign-in methods
3. Download `google-services.json` → place at `frontend/android/app/google-services.json`
4. Download `GoogleService-Info.plist` → add via Xcode to `ios/Runner/`

### Step 4 — Run the Frontend

```bash
cd frontend

# Android emulator
flutter run -d android

# iOS simulator
flutter run -d ios

# Web (Chrome)
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

> Make sure both MCP and BFF servers are running before starting the frontend.

---

## Running Everything

**Full-stack checklist — all in separate terminals:**

```bash
# Terminal 0 — Start PostgreSQL (if not already running)
docker run -d \
  --name githubmcp-pg \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=githubmcp \
  -p 5434:5432 \
  pgvector/pgvector:pg16

# Terminal 1 — Backend database
cd backend && alembic upgrade head

# Terminal 2 — MCP Server (port 8090)
cd backend && source .venv/bin/activate && uv run python server.py --port 8090

# Terminal 3 — BFF API (port 8091)
cd backend && source .venv/bin/activate && uv run python api_server.py --port 8091

# Terminal 4 — Frontend app
cd frontend && flutter run -d android
```

---

## Auth Flow (BFF)

Google and email/password sign-in go through **Firebase**. GitHub is **not** a sign-in provider; it's only for granting tool access post-login.

```
1. User signs in via Firebase (Google or email/password)
   → Firebase returns ID token

2. POST /api/v1/auth/firebase-login  { id_token }
   → BFF verifies with Firebase Admin SDK
   → Upserts user in DB
   → Returns signed JWT

3. Frontend stores JWT, sends: Authorization: Bearer <jwt>

4. User clicks "Connect GitHub" → GitHub OAuth redirect

5. POST /api/v1/auth/connect-github  { code }
   → BFF exchanges code for GitHub access token
   → Encrypts token with Fernet
   → Stores in oauth_connections table

6. All /api/v1/tools/* calls now use stored GitHub token automatically
```

---

## API Quick Reference

All tool routes require `Authorization: Bearer <jwt>` and a connected GitHub account.  
**Base URL:** `http://localhost:8091`

### Health & Status

| Method | Path      | Auth | Description                              |
| ------ | --------- | ---- | ---------------------------------------- |
| GET    | `/health` | None | Liveness probe — `{"status":"ok"}`       |
| GET    | `/ready`  | None | Readiness probe — checks DB connectivity |

### Auth

| Method   | Path                          | Auth | Description                       |
| -------- | ----------------------------- | ---- | --------------------------------- |
| POST     | `/api/v1/auth/firebase-login` | None | Verify Firebase token, return JWT |
| POST     | `/api/v1/auth/connect-github` | JWT  | Exchange GitHub OAuth code        |
| GET/POST | `/api/v1/auth/context`        | JWT  | Get/set active repo context       |

### Tools

| Endpoint                            | Description                   |
| ----------------------------------- | ----------------------------- |
| `/api/v1/tools/list-files`          | Browse repository files       |
| `/api/v1/tools/create-branch`       | Create a new branch           |
| `/api/v1/tools/create-file`         | Create a file in the repo     |
| `/api/v1/tools/create-pull-request` | Open a pull request           |
| `/api/v1/tools/create-task`         | Create a GitHub Projects task |
| `/api/v1/tools/list-tasks`          | List project tasks            |
| `/api/v1/tools/assign-task`         | Assign a task to a user       |
| `/api/v1/tools/update-task-status`  | Update task status            |
| `/api/v1/tools/ask-codebase`        | RAG Q&A over the codebase     |
| `/api/v1/tools/explore-codebase`    | Browse codebase structure     |

**Interactive docs:** `http://localhost:8091/docs`

---

## MCP Tools

All 12 tools are available via the MCP server and can be used directly in Claude Desktop or Cursor.

### Repository Tools

| Tool                  | Purpose                                |
| --------------------- | -------------------------------------- |
| `list_files`          | Browse files and directories in a repo |
| `create_branch`       | Create a new branch from a base        |
| `create_file`         | Create a new file with content         |
| `create_pull_request` | Open a pull request                    |

### GitHub Projects v2 Tools

| Tool                   | Purpose                                      |
| ---------------------- | -------------------------------------------- |
| `create_project_task`  | Create a new task in a project               |
| `list_project_tasks`   | List all tasks with filters                  |
| `assign_task`          | Assign a task to a user                      |
| `update_task_status`   | Update task status (e.g., In Progress, Done) |
| `create_project_field` | Create a custom field on a project           |
| `set_task_fields`      | Set field values on a task                   |

### RAG Tools

| Tool               | Purpose                                |
| ------------------ | -------------------------------------- |
| `ask_codebase`     | Ask questions about the codebase (RAG) |
| `explore_codebase` | Browse codebase structure and docs     |

---

## Database & RAG

### Database Schema

```sql
-- Users from Firebase
CREATE TABLE users (
  id UUID PRIMARY KEY,
  firebase_uid VARCHAR UNIQUE NOT NULL,
  email VARCHAR UNIQUE NOT NULL,
  display_name VARCHAR
);

-- Encrypted GitHub OAuth tokens
CREATE TABLE oauth_connections (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  encrypted_token TEXT NOT NULL,
  scope VARCHAR,
  created_at TIMESTAMP,
  expires_at TIMESTAMP
);

-- User's active GitHub context
CREATE TABLE user_context (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  github_owner VARCHAR,
  github_repo VARCHAR,
  project_id INTEGER
);

-- Audit log for all API calls
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  action VARCHAR,
  resource VARCHAR,
  timestamp TIMESTAMP
);
```

### RAG Pipeline

The `ingest.py` script chunks and embeds your target GitHub repo into a vector store:

```bash
cd backend
uv run python ingest.py                 # Initial indexing
uv run python ingest.py --reingest     # Re-index after changes
```

**Supported backends:**
--reingest # Re-index after changes

````

**Supported backends:**

- **PGVector** (default) — PostgreSQL with pgvector extension; fast, no separate database
- **ChromaDB** — Lightweight, embedded; good for local dev
- **Both** — Run both backends in parallel

Configure via `RAG_VECTOR_DB` env var: `pgvector`, `chroma`, or `both`

---

## Development & Testing

### Backend Tests

```bash
cd backend
pytest tests/ -v
````

Optional flags:

```bash
pytest tests/ -v -s                                              # with output
pytest tests/test_auth.py -v                                    # single file
pytest tests/ --cov=github_mcp/api --cov-report=term-missing   # coverage report
```

### Code Quality

```bash
cd backend

# Format code
uv run black github_mcp/ api_server.py tests/

# Check formatting (no changes)
uv run black --check github_mcp/ api_server.py tests/
```

### Frontend Testing

```bash
cd frontend
flutter test
flutter test test/unit/                 # unit tests only
flutter test --coverage                 # with coverage
```

---

## Project Structure

```
GitHubMCP/
├── backend/
│   ├── server.py                 # MCP server entry point
│   ├── api_server.py             # BFF API entry point
│   ├── ingest.py                 # RAG indexing script
│   ├── pyproject.toml            # Backend dependencies
│   ├── github_mcp/
│   │   ├── config.py             # Env var loading
│   │   ├── tools/                # 12 MCP tool implementations
│   │   ├── core/github_api.py    # GitHub REST/GraphQL helpers
│   │   ├── utils/                # Shared utilities
│   │   └── api/                  # BFF layer
│   │       ├── auth.py           # JWT + Firebase verification
│   │       ├── crypto.py         # Fernet encryption/decryption
│   │       ├── models.py         # SQLAlchemy ORM models
│   │       ├── dependencies.py   # FastAPI deps (get_current_user, etc.)
│   │       └── routes/           # API endpoints
│   ├── alembic/                  # Database migrations
│   └── tests/
│       ├── test_auth.py          # Auth flow tests
│       ├── test_tools.py         # Tool tests
│       └── conftest.py           # pytest fixtures
│
├── frontend/
│   ├── lib/
│   │   ├── main.dart             # App entry point
│   │   ├── router.dart           # Go Router navigation
│   │   ├── config/               # Constants, API config
│   │   ├── services/             # API client, auth service
│   │   ├── providers/            # Riverpod state management
│   │   ├── screens/              # UI pages
│   │   ├── widgets/              # Reusable UI components
│   │   ├── models/               # Data models
│   │   └── utils/                # Helpers
│   ├── pubspec.yaml              # Frontend dependencies
│   ├── android/, ios/            # Platform-specific code
│   └── test/                      # Flutter tests
│
└── README.md                      # This file
```

---

## Troubleshooting

### PostgreSQL connection errors

```
ERROR: could not connect to database "githubmcp"
```

**Solution:** Ensure PostgreSQL is running

```bash
# Docker
docker ps | grep githubmcp-pg

# Local Postgres
psql -U postgres -d githubmcp -c "SELECT 1"

# Create DB if missing
createdb -U postgres githubmcp
```

### "No such table" errors after alembic upgrade

**Solution:** Clear any stale `.db` file (if using SQLite)

```bash
rm -f ./dev.db
alembic upgrade head
```

### Flutter app can't reach backend

**Android:** Use `10.0.2.2` instead of `localhost`  
**iOS/Web:** Use `localhost`

Edit [frontend/lib/config/constants.dart](frontend/lib/config/constants.dart) and check `apiBaseUrl`.

### Firebase auth failures

1. Verify `FIREBASE_SERVICE_ACCOUNT_PATH` points to valid JSON
2. Ensure Firebase project is enabled for Google Sign-In
3. Check that your app is registered in Firebase Console
4. Confirm your device/emulator has Google Play Services (Android) or valid provisioning (iOS)

### MCP server not connecting in Claude Desktop

1. Check MCP server is running: `http://localhost:8090/sse`
2. Verify `claude_desktop_config.json` has correct URL
3. Restart Claude Desktop
4. Check logs: `tail -f ~/.claude_mcp_logs.txt` (if available)

---

## License

[See LICENSE file](LICENSE)
