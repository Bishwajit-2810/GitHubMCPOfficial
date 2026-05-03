# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

GitHubMCP is a full-stack application with three main layers:

1. **MCP Server** (`backend/server.py`, port 8090) — FastMCP server exposing 12 tools for Claude Desktop/Cursor direct access via SSE transport
2. **BFF REST API** (`backend/api_server.py`, port 8091) — FastAPI server acting as a Backend-for-Frontend for the Flutter mobile app
3. **Flutter App** (`frontend/`) — Mobile/web app using Firebase auth + GitHub OAuth + the BFF API

**Authentication chain:** Firebase (user identity) → backend JWT (session) → GitHub OAuth tokens (stored encrypted with Fernet in `oauth_connections` table)

**Data flow for tool calls:** Flutter → BFF API (JWT auth + GitHub token decryption) → MCP tool functions → GitHub REST/GraphQL API

## Backend Commands

All commands run from `backend/` with the venv activated:

```bash
# Setup
uv venv && source .venv/bin/activate
uv pip install -e .
alembic upgrade head          # Run DB migrations
uv run python ingest.py       # Index codebase for RAG (one-time)

# Run servers (two terminals)
uv run python server.py --port 8090     # MCP server
uv run python api_server.py --port 8091 # BFF API (or: uv run uvicorn api_server:app --reload)

# Test
pytest tests/ -v
pytest tests/test_auth.py -v            # Single file
pytest tests/ --cov=github_mcp/api --cov-report=term-missing

# Lint
uv run black --check github_mcp/ api_server.py tests/
uv run black github_mcp/ api_server.py tests/   # Auto-format
```

## Frontend Commands

```bash
cd frontend
flutter pub get
flutter run -d android    # Android emulator (uses 10.0.2.2 for host)
flutter run -d chrome     # Web
flutter analyze
```

## Key Configuration

All env vars live in `backend/.env`. Minimum required:

| Variable | Purpose |
|---|---|
| `GITHUB_TOKEN` | PAT with `repo`, `read:org`, `project` scopes (for MCP server) |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | GitHub OAuth App (for BFF Flutter flow) |
| `GITHUB_OWNER` / `GITHUB_REPO` / `PROJECT_ID` | Default GitHub context |
| `DATABASE_URL` | PostgreSQL for BFF (users, tokens, context) |
| `POSTGRES_URL` | PostgreSQL for RAG vector store (pgvector) |
| `JWT_SECRET` | Signs backend JWTs |
| `TOKEN_ENCRYPTION_KEY` | Fernet key for encrypting GitHub tokens at rest |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Firebase Admin SDK credential |
| `GROQ_API_KEY` | LLM for `ask_codebase` RAG responses |

Generate a Fernet key: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`

Frontend constants are hardcoded in `frontend/lib/config/constants.dart` (API base URL, OAuth client ID, redirect URI).

## Backend Package Layout

```
github_mcp/
├── config.py            # All env var loading and validation
├── core/github_api.py   # httpx helpers for GitHub REST + GraphQL calls
├── utils/               # Shared helpers (project board field lookups, etc.)
├── tools/               # One file per MCP tool; registered via __init__.register_all_tools()
└── api/                 # BFF layer
    ├── auth.py          # JWT creation/verification
    ├── crypto.py        # Fernet encrypt/decrypt for GitHub tokens
    ├── db.py            # SQLAlchemy engine + session factory
    ├── firebase_auth.py # Firebase Admin SDK token verification
    ├── models.py        # User, OAuthConnection, UserContext, AuditLog
    ├── dependencies.py  # FastAPI deps: get_current_user, require_repo_read, require_project_scope
    └── routes/          # auth_routes.py, tool_routes.py, health.py
```

## MCP Tools

12 tools registered at MCP server startup by `github_mcp/tools/__init__.register_all_tools()`:

- **Repo**: `list_files`, `create_branch`, `create_file`, `create_pull_request`
- **GitHub Projects v2**: `create_project_task`, `list_project_tasks`, `assign_task`, `update_task_status`, `create_project_field`, `set_task_fields`
- **RAG**: `ask_codebase`, `explore_codebase` (uses PGVector + Groq)

Each tool is in its own file under `github_mcp/tools/`. When adding a new tool, create its file there and register it in `__init__.py`.

## Database

Uses Alembic for migrations. Schema lives in `alembic/versions/`. Tables:
- `users` — Firebase UID, email, display name
- `oauth_connections` — encrypted GitHub access tokens per user
- `user_context` — selected owner/repo/project per user
- `audit_logs` — API call history

Local dev: run PostgreSQL via Docker with the pgvector extension (`pgvector/pgvector:pg16` image).

## RAG Pipeline

`ingest.py` chunks and embeds a target GitHub repo into PGVector (or ChromaDB fallback). The MCP tools `ask_codebase` and `explore_codebase` query this vector store using sentence-transformers embeddings and generate answers via Groq.

`RAG_VECTOR_DB` env var controls the backend: `pgvector` (default), `chroma`, or `both`.

## CI

`.github/workflows/backend-ci.yml` runs on push/PR to `main` and `working-v2` for changes under `backend/`. It spins up a PostgreSQL+pgvector service, installs deps via `uv`, runs Black lint check, then the full pytest suite.
