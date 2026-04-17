# GitHubMCP

A GitHub project management assistant with an MCP server, REST API backend, and Flutter mobile frontend.

---

## Architecture

```
GitHubMCP/
├── backend/          # Python backend (FastAPI + FastMCP)
│   ├── server.py     # MCP server — port 8090
│   └── api_server.py # BFF REST API — port 8091
└── frontend/         # Flutter mobile app
```

- **MCP Server (8090)** — Used directly by Claude Desktop, Cursor, or any MCP client
- **BFF API (8091)** — REST wrapper for the Flutter app; handles Firebase auth + GitHub OAuth
- **Flutter App** — Mobile frontend (Android/iOS/Web)

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Python | 3.11+ | [python.org](https://python.org) |
| uv | latest | `curl -Lsf https://astral.sh/uv/install.sh \| sh` |
| PostgreSQL | 14+ | [postgresql.org](https://postgresql.org) |
| Flutter | 3.11+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |

---

## Backend Setup

### 1. Install Dependencies

```bash
cd backend
uv venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
uv pip install -e .
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your values:

```env
# GitHub
GITHUB_TOKEN=ghp_your_personal_access_token
GITHUB_OWNER=your-github-username
GITHUB_REPO=your-repo-name
PROJECT_ID=1

# Database
POSTGRES_URL=postgresql://postgres:postgres@localhost:5432/githubmcp
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/githubmcp

# AI / RAG
GROQ_API_KEY=gsk_your_groq_api_key
RAG_VECTOR_DB=pgvector

# Auth (for BFF API)
JWT_SECRET=change-me-to-a-long-random-string
JWT_ALGORITHM=HS256
JWT_EXPIRATION=3600

# Fernet key — generate with:
# python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
TOKEN_ENCRYPTION_KEY=your-fernet-key

# Firebase (for BFF API)
FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/serviceAccount.json

# GitHub OAuth App (for BFF API)
GITHUB_CLIENT_ID=your-github-oauth-app-client-id
GITHUB_CLIENT_SECRET=your-github-oauth-app-client-secret
GITHUB_OAUTH_REDIRECT_URI=http://localhost:3000/oauth/callback

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
```

### 3. Run Database Migrations

```bash
cd backend
alembic upgrade head
```

### 4. (Optional) Index Codebase for RAG

```bash
cd backend
uv run python ingest.py
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

### 1. Install Flutter Dependencies

```bash
cd frontend
flutter pub get
```

### 2. Configure API Base URL

Edit [frontend/lib/config/constants.dart](frontend/lib/config/constants.dart):

```dart
// Android emulator → use 10.0.2.2 to reach localhost on host machine
static const String apiBaseUrl = 'http://10.0.2.2:8091/api/v1';

// iOS simulator / web → use localhost
// static const String apiBaseUrl = 'http://localhost:8091/api/v1';

static const String githubOAuthClientId = 'YOUR_GITHUB_OAUTH_CLIENT_ID';
static const String githubOAuthRedirectUri = 'githubmcp://oauth/callback';
```

### 3. Firebase Setup

Firebase is required for authentication. See [frontend/config.md](frontend/config.md) for the full setup guide. Quick steps:

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Google** and **Email/Password** sign-in methods (GitHub is not a login provider)
3. Register your Android app and download `google-services.json` → place at `frontend/android/app/google-services.json`
4. Register your iOS app and download `GoogleService-Info.plist` → add via Xcode to `ios/Runner/`

---

## Running the Frontend

```bash
cd frontend

# Android emulator
flutter run -d android

# iOS simulator
flutter run -d ios

# Web (Chrome)
flutter run -d chrome

# Check for issues
flutter analyze
```

> Make sure the backend is running before starting the frontend.

---

## Connecting Claude Desktop to the MCP Server

Add this to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json` on Mac):

```json
{
  "mcpServers": {
    "githubmcp": {
      "url": "http://localhost:8090/sse"
    }
  }
}
```

---

## Quick Reference

| Service | URL | Notes |
|---------|-----|-------|
| MCP Server | `http://localhost:8090/sse` | SSE endpoint for MCP clients |
| BFF API | `http://localhost:8091` | REST API for Flutter app |
| API Docs (Swagger) | `http://localhost:8091/docs` | Interactive API documentation |
| Health check | `http://localhost:8091/health` | Liveness probe |
| Readiness check | `http://localhost:8091/ready` | DB connectivity check |

---

## Key API Endpoints

**Auth**

| Method   | Path                          | Description                                        |
|----------|-------------------------------|----------------------------------------------------|
| POST     | `/api/v1/auth/firebase-login` | Firebase token → JWT (Google or email/password)    |
| POST     | `/api/v1/auth/connect-github` | GitHub OAuth code exchange                         |
| GET/POST | `/api/v1/auth/context`        | Get or set active repo context                     |

**Tools** (all under `/api/v1/tools/`)

| Endpoint | Description |
|----------|-------------|
| `list-files` | Browse repository files |
| `create-branch` | Create a new branch |
| `create-file` | Create a file in the repo |
| `create-pull-request` | Open a pull request |
| `create-task` | Create a GitHub Projects task |
| `list-tasks` | List project tasks |
| `assign-task` | Assign a task to a user |
| `update-task-status` | Update task status |
| `ask-codebase` | RAG Q&A over the codebase |
| `explore-codebase` | Browse codebase structure |

---

## Running Everything: Full Stack Checklist

```bash
# 1. Start PostgreSQL (if not already running)
sudo systemctl start postgresql   # Linux
brew services start postgresql    # Mac

# 2. Run DB migrations
cd backend && alembic upgrade head

# 3. Start MCP server
uv run python server.py --port 8090 &

# 4. Start BFF API
uv run python api_server.py --port 8091 &

# 5. Start Flutter app
cd ../frontend && flutter run -d android
```
