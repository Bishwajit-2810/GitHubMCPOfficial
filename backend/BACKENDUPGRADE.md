# Backend Upgrade Plan - FastAPI + Firebase Auth + GitHub Connect

Target: Build a FastAPI BFF in `backend` that wraps MCP tools, uses Firebase for identity, and uses a backend-managed GitHub OAuth connection for GitHub API scopes.

Duration: 2 days.

## Success Criteria

- [x] FastAPI runs on port 8091, MCP remains on 8090
- [x] Core MCP tools exposed via `/api/v1/*`
- [x] Firebase ID token verification on all protected routes
- [x] Backend JWT/session created after Firebase login
- [x] GitHub OAuth connect flow implemented for `repo`, `read:org`, `project`
- [x] GitHub tokens encrypted at rest and never stored in JWT payload
- [x] Branch fallback uses repository `default_branch` (not hardcoded `main`)
- [x] User context (owner/repo/project) persisted in Postgres
- [x] Health/readiness endpoints available
- [x] Smoke tests + CI pass

---

## Day 1

### Block 1: Core Hardening

- [x] Call `validate_config()` in MCP startup.
- [x] Add repo default branch resolver in GitHub API helper (`get_default_branch()`).
- [x] Update branch-related flows to use default branch fallback (`branches.py`, `pull_requests.py`).
- [x] Standardize API error envelope: `code`, `message`, `details` (`exceptions.py`).
- [x] Add `/health` and `/ready` endpoints.

### Block 2: FastAPI Scaffold

Created:

- [x] `backend/api_server.py`
- [x] `backend/github_mcp/api/auth.py`
- [x] `backend/github_mcp/api/firebase_auth.py`
- [x] `backend/github_mcp/api/routes/health.py`
- [x] `backend/github_mcp/api/routes/auth_routes.py`
- [x] `backend/github_mcp/api/routes/tool_routes.py`
- [x] `backend/github_mcp/api/models.py`
- [x] `backend/github_mcp/api/db.py`
- [x] `backend/github_mcp/api/exceptions.py`
- [x] `backend/github_mcp/api/crypto.py`
- [x] `backend/github_mcp/api/dependencies.py`

FastAPI baseline:

- [x] Versioned prefix `/api/v1`
- [x] CORS policy configured (`CORS_ORIGINS` env var)
- [x] OpenAPI docs enabled (`/docs`, `/redoc`)
- [x] Request validation + consistent response wrappers

### Block 3: Data Model + Security

Use Postgres with migrations (Alembic).

Tables:

- [x] `users` (`id`, `firebase_uid`, `auth_provider`, timestamps)
- [x] `user_context` (`user_id`, `selected_owner`, `selected_repo`, `selected_project_number`)
- [x] `oauth_connections` (`user_id`, `provider`, `access_token_encrypted`, `scopes`, `expires_at`)
- [x] `audit_logs` (mutation trail)

Rules:

- [x] Never store raw GitHub token in JWT
- [x] Encrypt token before DB persistence (`TOKEN_ENCRYPTION_KEY` via Fernet)
- [x] Redact credentials in logs/errors

Day 1 exit:

- [x] FastAPI boots, health endpoints pass, models/migrations created

---

## Day 2

### Block 4: Auth Endpoints

Implemented:

- [x] `POST /api/v1/auth/firebase-login`
  - input: Firebase ID token
  - verify via Firebase Admin SDK
  - upsert user by `firebase_uid`
  - return backend JWT/session token
- [x] `POST /api/v1/auth/connect-github`
  - OAuth code exchange
  - require scopes: `repo`, `read:org`, `project`
  - encrypt and save access token
- [x] `GET /api/v1/auth/context`
- [x] `POST /api/v1/auth/context`

### Block 5: Tool Routes + Permission Checks

Wrapped:

- [x] list files (`POST /api/v1/tools/list-files`)
- [x] list tasks (`POST /api/v1/tools/list-tasks`)
- [x] create task (`POST /api/v1/tools/create-task`)
- [x] ask codebase (`POST /api/v1/tools/ask-codebase`)
- [x] create branch (`POST /api/v1/tools/create-branch`)
- [x] create file (`POST /api/v1/tools/create-file`)
- [x] create pull request (`POST /api/v1/tools/create-pull-request`)
- [x] assign task (`POST /api/v1/tools/assign-task`)
- [x] update task status (`POST /api/v1/tools/update-task-status`)

Security gates:

- [x] `repo:read` gate for read endpoints
- [x] `repo` (write) gate for mutating repo operations
- [x] `project` gate for project updates
- [x] clear `401/403` errors when GitHub not connected/scopes missing

### Block 6: Reliability + CI

- [x] Rate limiting via `slowapi` (200 req/min default)
- [x] Smoke tests: `tests/test_core.py`, `tests/test_health.py`, `tests/test_auth.py`, `tests/test_tools.py` (34 tests, all passing)
- [x] GitHub Actions workflow `.github/workflows/backend-ci.yml`

Day 2 exit:

- [x] End-to-end flow works with Firebase identity + GitHub connect

---

## Required Environment Variables

```bash
API_HOST=0.0.0.0
API_PORT=8091
JWT_SECRET=change-me
JWT_ALGORITHM=HS256
JWT_EXPIRATION=3600
POSTGRES_URL=postgresql://user:pass@host:5432/db
TOKEN_ENCRYPTION_KEY=base64-32-byte-key   # generate: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_SERVICE_ACCOUNT_PATH=backend/firebase-service-account.json

GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret
GITHUB_OAUTH_REDIRECT_URI=https://your-api-domain.com/api/v1/auth/github/callback

CORS_ORIGINS=http://localhost:3000,http://localhost:5173

# Existing backend integration values
GROQ_API_KEY=...
RAG_VECTOR_DB=pgvector
```

### Alembic migrations

```bash
cd backend
uv run alembic upgrade head
```

### Start servers

```bash
# MCP server on port 8090
uv run python server.py --port 8090

# FastAPI BFF on port 8091
uv run python api_server.py --port 8091
```

---

## API Contract for Frontend

- [x] `POST /api/v1/auth/firebase-login` returns backend JWT
- [x] `POST /api/v1/auth/connect-github` links GitHub and returns scopes status
- [x] `GET /api/v1/auth/context` returns selected owner/repo/project
- [x] `POST /api/v1/auth/context` persists selection
- [x] protected routes require backend JWT (Bearer token in `Authorization` header)

---

## Done Checklist

- [x] Firebase auth verification implemented server-side
- [x] GitHub OAuth connect implemented with scope validation
- [x] Encrypted GitHub token storage implemented (Fernet)
- [x] No secret leakage in logs/JWT payloads
- [x] Branch default fallback fixed (`get_default_branch()` in `github_api.py`)
- [x] Context persistence implemented
- [x] Core route coverage implemented (9 tool routes)
- [x] Smoke tests passing (34/34)
- [x] GitHub Actions CI configured
