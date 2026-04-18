# GitHub MCP — v2

A two-server stack for AI-driven GitHub automation:

| Server | Port | Purpose |
|--------|------|---------|
| **MCP server** (`server.py`) | 8090 | FastMCP SSE — 12 tools consumed directly by Claude / Cursor |
| **BFF API** (`api_server.py`) | 8091 | FastAPI — Firebase auth, GitHub OAuth, REST wrappers for the same tools |

---

## Table of Contents

- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Environment Variables](#environment-variables)
- [Setup & Installation](#setup--installation)
- [Running the Servers](#running-the-servers)
- [Auth Flow (BFF)](#auth-flow-bff)
- [BFF API Reference](#bff-api-reference)
- [Running Tests](#running-tests)
- [Database Migrations](#database-migrations)
- [RAG Pipeline](#rag-pipeline)
- [MCP Tool Reference](#mcp-tool-reference)
- [Project Structure](#project-structure)
- [Development Guide](#development-guide)
- [License](#license)

---

## Architecture

```
┌─────────────┐     Firebase ID token     ┌──────────────────────────┐
│  Frontend   │ ──────────────────────── ▶│  BFF  (port 8091)        │
│  (Flutter)  │ ◀─────────── JWT ──────── │  FastAPI + slowapi       │
└─────────────┘                           │  Firebase Auth           │
                                          │  (Google + email/pass)   │
                                          │  GitHub OAuth (Fernet)   │
                                          │  SQLAlchemy + Alembic    │
                                          └──────────────────────────┘

┌──────────────────┐
│  Claude / Cursor │ ──── MCP/SSE ────▶  MCP server (port 8090)
└──────────────────┘                     FastMCP — 12 tools
```

---

## Quick Start

```bash
git clone <your-repo-url>
cd GitHubMCP/backend

# Install uv (skip if already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create venv and install all dependencies
uv venv && source .venv/bin/activate
uv pip install -e .

# Configure environment
cp .env.example .env   # fill in the values described below

# Run DB migrations (creates users, oauth_connections, etc.)
alembic upgrade head

# Index the repo for RAG (once)
uv run python ingest.py

# Terminal 1 — MCP server
uv run python server.py --port 8090

# Terminal 2 — BFF API
uv run python api_server.py --port 8091
```

---

## Environment Variables

Create `.env` in the `backend/` directory.

### GitHub (MCP server + BFF)

```env
GITHUB_TOKEN=ghp_...          # PAT used by the MCP server (repo + project + read:org)
GITHUB_OWNER=your-username    # Default owner for MCP tools
GITHUB_REPO=your-repo         # Default repo for MCP tools
PROJECT_ID=2                  # GitHub Projects v2 board number
```

### BFF — Auth

```env
# Firebase (one of these two is required)
FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/serviceAccount.json
FIREBASE_PROJECT_ID=your-firebase-project-id   # uses Application Default Credentials

# JWT signed by the BFF after Firebase login
JWT_SECRET=change-me-to-a-long-random-string
JWT_ALGORITHM=HS256           # optional, default HS256
JWT_EXPIRATION=3600           # optional, default 3600 (seconds)

# Fernet key for encrypting stored GitHub OAuth tokens
# Generate: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
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
API_PORT=8091                 # optional, default 8091
API_HOST=0.0.0.0              # optional, default 0.0.0.0
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
LOG_LEVEL=INFO                # DEBUG | INFO | WARNING | ERROR
```

### Database (shared — BFF + optional RAG PGVector)

```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5434/githubmcp
# PGVector RAG (can be the same DB or a separate one)
POSTGRES_URL=postgresql://postgres:postgres@localhost:5434/ai_db
```

### RAG / AI

```env
GROQ_API_KEY=gsk_...
RAG_VECTOR_DB=pgvector        # chroma | pgvector | both  (default: pgvector)
RAG_SKIP_LOCAL_DOCS=true
RAG_CHROMA_DIR=./chroma_store
```

### GitHub Token Scopes Required

| Scope | Purpose |
|-------|---------|
| `repo` | Read/write files, branches, PRs |
| `project` | GitHub Projects v2 |
| `read:org` | Org-owned projects |

---

## Setup & Installation

### Prerequisites

- Python 3.12+
- [uv](https://github.com/astral-sh/uv)
- Docker (for PostgreSQL) or an existing Postgres 15+ instance

### Step 1 — Clone and install

```bash
git clone <your-repo-url>
cd GitHubMCP/backend
uv venv && source .venv/bin/activate
uv pip install -e .
```

### Step 2 — Start PostgreSQL

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

> **SQLite for local dev (no Docker):** Set `DATABASE_URL=sqlite:///./dev.db` in `.env`.  
> SQLite is also used automatically by the test suite (in-memory).

### Step 3 — Configure `.env`

```bash
cp .env.example .env
# Edit .env — fill in all required variables
```

Minimum required to start both servers:

```env
GITHUB_TOKEN=ghp_...
GITHUB_OWNER=your-username
GITHUB_REPO=your-repo
PROJECT_ID=2
GROQ_API_KEY=gsk_...
JWT_SECRET=replace-with-random-secret
TOKEN_ENCRYPTION_KEY=<output of Fernet.generate_key()>
FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/serviceAccount.json
GITHUB_CLIENT_ID=...
GITHUB_CLIENT_SECRET=...
GITHUB_OAUTH_REDIRECT_URI=http://localhost:3000/oauth/callback
DATABASE_URL=postgresql://postgres:postgres@localhost:5434/githubmcp
POSTGRES_URL=postgresql://postgres:postgres@localhost:5434/ai_db
```

### Step 4 — Run database migrations

```bash
alembic upgrade head
```

This creates four tables: `users`, `user_context`, `oauth_connections`, `audit_logs`.

### Step 5 — Index the repository (RAG, run once)

```bash
uv run python ingest.py
# Re-index after repo changes:
uv run python ingest.py --reingest
```

---

## Running the Servers

### MCP server (port 8090)

Used directly by Claude Desktop, Cursor, or any MCP client.

```bash
uv run python server.py --port 8090
# or with uvicorn
uvicorn server:app --host 0.0.0.0 --port 8090
```

SSE endpoint: `http://localhost:8090/sse`

Inspect tools interactively:
```bash
npx @modelcontextprotocol/inspector
```

### BFF API (port 8091)

Used by the frontend / external clients.

```bash
uv run python api_server.py --port 8091
# or
uvicorn api_server:app --host 0.0.0.0 --port 8091 --reload
```

Interactive docs: `http://localhost:8091/docs`  
OpenAPI schema: `http://localhost:8091/openapi.json`

---

## Auth Flow (BFF)

Google and email/password sign-in go through Firebase — the app gets a Firebase ID token and the BFF verifies it the same way for both. GitHub is **not** a sign-in method; it is only used post-login via the Connect GitHub flow to grant `repo`, `read:org`, and `project` scopes for tool access.

```text
1. User signs in via Firebase (Google or email/password) → Firebase returns ID token
2. POST /api/v1/auth/firebase-login  { id_token }
   → BFF verifies with Firebase Admin SDK, upserts user, returns a signed JWT
3. Frontend stores the JWT and sends it as: Authorization: Bearer <jwt>
4. User clicks "Connect GitHub" → GitHub OAuth redirect
5. POST /api/v1/auth/connect-github  { code }
   → BFF exchanges code for GitHub access token, encrypts it (Fernet), stores in DB
6. All /api/v1/tools/* calls now use the stored GitHub token automatically
```

---

## BFF API Reference

All tool routes require `Authorization: Bearer <jwt>` and a connected GitHub account.  
Base URL: `http://localhost:8091`

### Health

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | None | Liveness probe — `{"status":"ok"}` |
| GET | `/ready` | None | Readiness probe — checks DB connectivity |

### Auth

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/auth/firebase-login` | None | Verify Firebase token (Google or email/password), return JWT |
| POST | `/api/v1/auth/connect-github` | JWT | Exchange GitHub OAuth code, store encrypted token |
| GET | `/api/v1/auth/context` | JWT | Get selected owner/repo/project |
| POST | `/api/v1/auth/context` | JWT | Set default owner/repo/project (used as fallback by all tools) |

**`POST /api/v1/auth/firebase-login`**
```json
// Request
{ "id_token": "eyJhbGci..." }

// Response
{ "access_token": "eyJ...", "token_type": "bearer", "user_id": 1, "firebase_uid": "abc123" }
```

**`POST /api/v1/auth/connect-github`**
```json
// Request
{ "code": "github_oauth_code_here" }

// Response
{ "connected": true, "scopes": ["project", "read:org", "repo"] }
```

**`POST /api/v1/auth/context`**
```json
// Request
{ "selected_owner": "my-org", "selected_repo": "my-repo", "selected_project_number": 3 }

// Response
{ "selected_owner": "my-org", "selected_repo": "my-repo", "selected_project_number": 3 }
```

### Tools

All tool routes: `POST /api/v1/tools/<tool-name>`  
`owner` and `repo` fields are optional — they fall back to the context set via `/api/v1/auth/context`.

| Endpoint | Required scopes | Description |
|----------|----------------|-------------|
| `/api/v1/tools/list-files` | `repo` | Browse repo files |
| `/api/v1/tools/create-branch` | `repo` (write) | Create a branch |
| `/api/v1/tools/create-file` | `repo` (write) | Create or update a file |
| `/api/v1/tools/create-pull-request` | `repo` (write) | Open a PR |
| `/api/v1/tools/create-task` | `project` | Create project task / issue |
| `/api/v1/tools/list-tasks` | `project` | List project board items |
| `/api/v1/tools/assign-task` | `repo` (write) | Assign users & labels to an issue |
| `/api/v1/tools/update-task-status` | `project` | Move item to a new status column |
| `/api/v1/tools/ask-codebase` | JWT only | RAG Q&A over indexed repo |

**Error envelope** (all errors):
```json
{
  "error": {
    "code": "MISSING_CONTEXT",
    "message": "Missing required field(s): owner. Set them via POST /api/v1/auth/context.",
    "details": null
  }
}
```

---

## Running Tests

The test suite uses an in-memory SQLite database (StaticPool) and mocks Firebase + GitHub HTTP calls — no external services needed.

```bash
cd backend

# Run all 34 tests
.venv/bin/pytest tests/ -v

# Run a specific file
.venv/bin/pytest tests/test_auth.py -v

# Run with log output
.venv/bin/pytest tests/ -v -s

# Run with coverage (if pytest-cov installed)
.venv/bin/pytest tests/ --cov=github_mcp/api --cov-report=term-missing
```

Expected output:
```
tests/test_auth.py::test_firebase_login_success PASSED
tests/test_auth.py::test_firebase_login_invalid_token PASSED
tests/test_auth.py::test_connect_github_success PASSED
... (34 total)
============================== 34 passed in 0.63s ==============================
```

### Test files

| File | What it tests |
|------|---------------|
| `tests/test_health.py` | `/health`, `/ready`, DB failure path |
| `tests/test_auth.py` | Firebase login, GitHub OAuth, context CRUD, JWT rejection |
| `tests/test_core.py` | Fernet crypto, JWT sign/verify, `_headers()`, `_raise_for_status()` |
| `tests/test_tools.py` | Auth gates, scope enforcement, `list_files` happy path, RAG config check |

### Test configuration

`pyproject.toml` sets `asyncio_mode = "strict"` and the `testpaths`. The `conftest.py` fixture:

- Creates an in-memory SQLite DB with `StaticPool` (all connections share one DB)
- Overrides `get_db_dep` and `get_current_user` so tests don't need real credentials
- Uses `uuid.uuid4()` per test to avoid `UNIQUE` constraint collisions on `firebase_uid`

---

## Database Migrations

Migrations live in `alembic/versions/`. Alembic is configured in `alembic.ini` and reads `DATABASE_URL` from the environment.

```bash
# Apply all pending migrations
alembic upgrade head

# Roll back one migration
alembic downgrade -1

# Check current revision
alembic current

# Generate a new migration after model changes
alembic revision --autogenerate -m "add_column_xyz"
```

Migrations in `alembic/versions/`:

| Migration                          | Purpose                                                             |
|------------------------------------|---------------------------------------------------------------------|
| `001_initial_schema.py`            | Creates `users`, `user_context`, `oauth_connections`, `audit_logs`  |
| `003_revert_username_password.py`  | Removes unused `username`/`password_hash` columns (if 002 ran)      |

| Table | Purpose |
|-------|---------|
| `users` | Firebase UID or username → internal user ID |
| `user_context` | Per-user default owner/repo/project |
| `oauth_connections` | Encrypted GitHub access tokens |
| `audit_logs` | Action history (login, register, connect, etc.) |

---

## RAG Pipeline

The RAG pipeline indexes the target GitHub repository into a vector store (PGVector by default) and powers the `ask_codebase` tool.

### Index the repository

```bash
uv run python ingest.py                  # full index → PGVector (default)
uv run python ingest.py --reingest       # wipe store, then re-index
uv run python ingest.py --db chroma      # ChromaDB only
uv run python ingest.py --db pgvector    # PGVector only
uv run python ingest.py --db both        # both stores
uv run python ingest.py --docs-only      # local docs only (fast)
```

### Test the RAG chain

```bash
uv run python rag_query.py                          # 3 built-in test questions
uv run python rag_query.py "How does auth work?"    # custom question
```

### Vector store options

| `RAG_VECTOR_DB` | Behaviour |
|-----------------|-----------|
| `pgvector` | PGVector only (default, recommended) |
| `chroma` | ChromaDB only (no Docker needed) |
| `both` | Combined search, deduplicated results |

---

## MCP Tool Reference

All 12 tools are available on the MCP server at `http://localhost:8090/sse` and as HTTP endpoints at `http://localhost:8091/api/v1/tools/`.

### 1. `list_files`
Browse files and directories in a repository.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | `str` | `""` | Path inside the repo (empty = root) |
| `ref` | `str` | default branch | Branch / tag / SHA |
| `owner` | `str` | `GITHUB_OWNER` | Repo owner |
| `repo` | `str` | `GITHUB_REPO` | Repository name |

---

### 2. `create_branch`
Create a new branch from an existing branch.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `branch` | `str` | — | New branch name |
| `source_branch` | `str` | repo default branch | Branch to copy from |
| `owner` | `str` | `GITHUB_OWNER` | Repo owner |
| `repo` | `str` | `GITHUB_REPO` | Repository name |

---

### 3. `create_file`
Create or update a file with an automatic commit.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | `str` | — | File path inside the repo |
| `content` | `str` | — | Plain-text file content |
| `message` | `str` | — | Commit message |
| `branch` | `str` | default branch | Target branch |
| `owner` | `str` | `GITHUB_OWNER` | Repo owner |
| `repo` | `str` | `GITHUB_REPO` | Repository name |

---

### 4. `create_pull_request`
Open a pull request.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `title` | `str` | — | PR title |
| `head` | `str` | — | Source branch |
| `base` | `str` | repo default branch | Target branch |
| `body` | `str` | `""` | PR description |
| `draft` | `bool` | `false` | Open as draft |
| `owner` | `str` | `GITHUB_OWNER` | Repo owner |
| `repo` | `str` | `GITHUB_REPO` | Repository name |

---

### 5. `create_project_task`
Create a task on a GitHub Projects v2 board. Creates a real Issue (if `repo` set) or a draft card.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `title` | `str` | — | Task title |
| `body` | `str` | `""` | Description |
| `status` | `str` | `None` | Status column, e.g. `"Todo"`, `"In Progress"` |
| `project_number` | `int` | `PROJECT_ID` | Board number from URL |
| `repo` | `str` | `GITHUB_REPO` | Creates a real Issue if set |
| `owner` | `str` | `GITHUB_OWNER` | Owner |
| `assignee` | `str` | `None` | GitHub username |
| `label` | `str` | `None` | Label (auto-created if missing) |

---

### 6. `list_project_tasks`
List items on a Projects v2 board with offset pagination.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `project_number` | `int` | `PROJECT_ID` | Board number |
| `owner` | `str` | `GITHUB_OWNER` | Owner (user or org — auto-detected) |
| `offset` | `int` | `0` | 0-based first item |
| `limit` | `int` | `50` | Items to return |

---

### 7. `assign_task`
Assign users and labels to a GitHub Issue. Missing labels are auto-created.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `issue_number` | `int` | — | Issue number from URL |
| `assignees` | `list[str]` | — | GitHub usernames |
| `labels` | `list[str]` | `None` | Labels to apply |
| `owner` | `str` | `GITHUB_OWNER` | Repo owner |
| `repo` | `str` | `GITHUB_REPO` | Repository name |

---

### 8. `update_task_status`
Move a project item to a different status column.

> `item_id` must come from `list_project_tasks` — starts with `PVTI_`.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `item_id` | `str` | — | From `list_project_tasks` |
| `status` | `str` | — | New status name |
| `project_number` | `int` | `PROJECT_ID` | Board number |
| `owner` | `str` | `GITHUB_OWNER` | Owner |

---

### 9. `create_project_field`
Add a custom field to a Projects v2 board. Idempotent.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `field_name` | `str` | — | Display name, e.g. `"Story Points"` |
| `field_type` | `str` | — | `"text"`, `"number"`, or `"date"` |
| `project_number` | `int` | `PROJECT_ID` | Board number |
| `owner` | `str` | `GITHUB_OWNER` | Owner |

---

### 10. `set_task_fields`
Set one or more custom field values on a project item in one call.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `item_id` | `str` | — | From `list_project_tasks` |
| `fields` | `dict` | — | `{ field_name: value }` |
| `project_number` | `int` | `PROJECT_ID` | Board number |
| `owner` | `str` | `GITHUB_OWNER` | Owner |

---

### 11. `ask_codebase`
Natural-language Q&A over the indexed repository (RAG).

| Parameter | Type | Description |
|-----------|------|-------------|
| `question` | `str` | Any question about the codebase |

Requires `ingest.py` to have been run first.

---

### 12. `explore_codebase`
Explore repository structure — find files, list images, count by type.

| Parameter | Type | Description |
|-----------|------|-------------|
| `query` | `str` | Structural or file-level question |

---

## Project Structure

```
backend/
├── api_server.py              # FastAPI BFF entry point (port 8091)
├── server.py                  # FastMCP MCP server entry point (port 8090)
├── ingest.py                  # RAG ingestion script
├── rag_query.py               # Standalone RAG chain tester
├── pyproject.toml             # All dependencies (uv)
├── alembic.ini                # Alembic config
├── bug.md                     # Bug audit from v2 upgrade
│
├── alembic/
│   └── versions/
│       └── 001_initial_schema.py   # Creates all 4 BFF tables
│
├── tests/
│   ├── conftest.py            # In-memory SQLite fixtures, mock auth
│   ├── test_health.py         # Health + readiness probes
│   ├── test_auth.py           # Firebase login, OAuth connect, context, JWT
│   ├── test_core.py           # Crypto, JWT, GitHub API helpers
│   └── test_tools.py          # Tool route auth gates + happy paths
│
└── github_mcp/
    ├── config.py              # Env var loading + validate_config()
    ├── constants.py           # API URLs, GraphQL strings
    ├── core/
    │   └── github_api.py      # _headers(), _gql_headers(), get_default_branch()
    ├── utils/
    │   └── project_helpers.py # _resolve_project(), _find_field()
    ├── tools/                 # One file per MCP tool (12 total)
    └── api/                   # BFF package
        ├── auth.py            # JWT create/decode (python-jose)
        ├── crypto.py          # Fernet encrypt/decrypt for OAuth tokens
        ├── db.py              # SQLAlchemy engine + get_db_dep
        ├── dependencies.py    # get_current_user, require_repo_read/write/project
        ├── exceptions.py      # AppError, AuthError, ForbiddenError + handlers
        ├── firebase_auth.py   # Lazy Firebase Admin init + verify_firebase_token()
        ├── models.py          # ORM: User, UserContext, OAuthConnection, AuditLog
        └── routes/
            ├── auth_routes.py # /auth/* endpoints
            ├── health.py      # /health, /ready
            └── tool_routes.py # /tools/* endpoints
```

---

## Development Guide

### Adding a new MCP tool

1. Create `github_mcp/tools/your_tool.py`:

```python
from typing import Optional
from fastmcp import FastMCP
from ..core.github_api import _headers

def register_your_tool(mcp: FastMCP) -> None:
    @mcp.tool()
    async def your_tool(param: str, owner: Optional[str] = None) -> dict:
        """Short description shown to the LLM agent."""
        return {"result": "success"}
```

2. Register in `github_mcp/tools/__init__.py`:

```python
from .your_tool import register_your_tool

def register_all_tools(mcp):
    # ...existing...
    register_your_tool(mcp)
```

### Adding a new BFF route

1. Add the route to `github_mcp/api/routes/tool_routes.py` following the existing pattern.
2. Use `_require_owner_repo()` if your route needs `owner`/`repo`.
3. Use the appropriate dependency: `require_repo_read`, `require_repo_write`, or `require_project_scope`.

### CI

`.github/workflows/backend-ci.yml` runs on every push:
- Starts a Postgres 15 service
- `uv sync`
- `pytest tests/ -v`

---

## License

MIT License — see [LICENSE](LICENSE) for details.

### Credits

- [FastMCP](https://github.com/jlowin/fastmcp) — MCP server framework
- [FastAPI](https://fastapi.tiangolo.com/) — BFF framework
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup) — ID token verification
- [python-jose](https://github.com/mpdavis/python-jose) — JWT
- [cryptography](https://cryptography.io/) — Fernet token encryption
- [slowapi](https://github.com/laurentS/slowapi) — rate limiting
- [Alembic](https://alembic.sqlalchemy.org/) — DB migrations
- [LangChain](https://python.langchain.com/) + [Groq](https://groq.com/) — RAG pipeline
- [uv](https://github.com/astral-sh/uv) — Python package manager
