# Backend Configuration Guide

Step-by-step setup for the FastAPI BFF (port 8091) and MCP server (port 8090).

---

## 1. Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Python | 3.12+ | [python.org](https://python.org) |
| uv | latest | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| Docker | any | [docker.com](https://docker.com) — for PostgreSQL |

---

## 2. Install Python Dependencies

```bash
cd backend
uv venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
uv pip install -e .
```

---

## 3. Firebase Service Account

The BFF uses Firebase Admin SDK to verify ID tokens from the Flutter app.

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Open your project → **Project settings** → **Service accounts**
3. Click **Generate new private key** → confirm → download the JSON file
4. Place it somewhere safe on your machine (e.g. `backend/serviceAccount.json`)
5. Set in `.env`:

```env
FIREBASE_SERVICE_ACCOUNT_PATH=/absolute/path/to/serviceAccount.json
```

> **Alternative — Application Default Credentials:**  
> If you're on GCP or have `gcloud auth application-default login` set up, skip the file and set:
> ```env
> FIREBASE_PROJECT_ID=your-firebase-project-id
> ```

---

## 4. GitHub Personal Access Token (MCP tools)

The MCP server and BFF tools use a PAT to call the GitHub REST and GraphQL APIs.

1. Go to [github.com/settings/tokens](https://github.com/settings/tokens)
2. Click **Generate new token (classic)**
3. Select these scopes:

| Scope | Why |
|-------|-----|
| `repo` | Read/write files, branches, PRs, issues |
| `project` | GitHub Projects v2 board access |
| `read:org` | Org-owned projects |

4. Copy the token and set in `.env`:

```env
GITHUB_TOKEN=ghp_your_token_here
GITHUB_OWNER=your-github-username-or-org
GITHUB_REPO=your-default-repo
PROJECT_ID=1                    # GitHub Projects board number (from the board URL)
```

---

## 5. GitHub OAuth App (post-login "Connect GitHub")

This is a **separate** OAuth App used by the Flutter app's "Connect GitHub" button. It is **not** used for login — users log in via Google or email/password (Firebase). This OAuth app grants `repo`, `read:org`, and `project` scopes so the BFF can call GitHub on behalf of the user.

1. Go to [github.com/settings/developers](https://github.com/settings/developers) → **OAuth Apps** → **New OAuth App**
2. Fill in:

| Field | Value |
|-------|-------|
| Application name | `GitHub MCP` |
| Homepage URL | `http://localhost:8091` |
| Authorization callback URL | `githubmcp://oauth/callback` |

3. Click **Register application**
4. On the next screen, click **Generate a new client secret**
5. Copy both values and set in `.env`:

```env
GITHUB_CLIENT_ID=Ov23liXXXXXXXXXX
GITHUB_CLIENT_SECRET=your_secret_here
GITHUB_OAUTH_REDIRECT_URI=githubmcp://oauth/callback
```

> The same `GITHUB_CLIENT_ID` also goes into `frontend/lib/config/constants.dart` → `githubOAuthClientId`.  
> See [frontend/config.md](../frontend/config.md) for that step.

---

## 6. PostgreSQL Database

### Option A — Docker (recommended)

```bash
docker run -d \
  --name githubmcp-pg \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=githubmcp \
  -p 5434:5432 \
  pgvector/pgvector:pg16
```

> Uses port **5434** on the host to avoid conflicts with any local PostgreSQL.

Set in `.env`:

```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5434/githubmcp
POSTGRES_URL=postgresql://postgres:postgres@localhost:5434/githubmcp
```

Verify the container is running:

```bash
docker ps | grep githubmcp-pg
```

### Option B — Local PostgreSQL + pgvector

If you have PostgreSQL installed locally:

1. Enable the pgvector extension:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE DATABASE githubmcp;
```

2. Set in `.env`:

```env
DATABASE_URL=postgresql://postgres:yourpassword@localhost:5432/githubmcp
POSTGRES_URL=postgresql://postgres:yourpassword@localhost:5432/githubmcp
```

### Option C — SQLite (local dev only, no Docker)

No setup needed. Set in `.env`:

```env
DATABASE_URL=sqlite:///./dev.db
```

> SQLite does not support pgvector — RAG will fall back to ChromaDB (`RAG_VECTOR_DB=chroma`).

---

## 7. Generate Secrets

### JWT secret

Any long random string:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

Set in `.env`:

```env
JWT_SECRET=paste_output_here
JWT_ALGORITHM=HS256
JWT_EXPIRATION=3600             # seconds — 3600 = 1 hour
```

### Fernet encryption key (for stored GitHub tokens)

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Set in `.env`:

```env
TOKEN_ENCRYPTION_KEY=paste_output_here
```

---

## 8. Groq API Key (RAG / AI)

The `ask-codebase` tool uses Groq to answer questions about the indexed repo.

1. Sign up at [console.groq.com](https://console.groq.com)
2. Create an API key
3. Set in `.env`:

```env
GROQ_API_KEY=gsk_your_key_here
RAG_VECTOR_DB=pgvector          # chroma | pgvector | both
```

---

## 9. Complete `.env` File

Create `backend/.env` (copy from `.env.example` and fill in):

```env
# ── GitHub (MCP server + BFF tools) ──────────────────────────────────────────
GITHUB_TOKEN=ghp_your_personal_access_token
GITHUB_OWNER=your-github-username
GITHUB_REPO=your-repo-name
PROJECT_ID=1

# ── Firebase ──────────────────────────────────────────────────────────────────
FIREBASE_SERVICE_ACCOUNT_PATH=/absolute/path/to/serviceAccount.json

# ── JWT ───────────────────────────────────────────────────────────────────────
JWT_SECRET=your-generated-secret
JWT_ALGORITHM=HS256
JWT_EXPIRATION=3600

# ── Fernet ────────────────────────────────────────────────────────────────────
TOKEN_ENCRYPTION_KEY=your-generated-fernet-key

# ── GitHub OAuth App ──────────────────────────────────────────────────────────
GITHUB_CLIENT_ID=Ov23liXXXXXXXXXX
GITHUB_CLIENT_SECRET=your-client-secret
GITHUB_OAUTH_REDIRECT_URI=githubmcp://oauth/callback

# ── Database ──────────────────────────────────────────────────────────────────
DATABASE_URL=postgresql://postgres:postgres@localhost:5434/githubmcp
POSTGRES_URL=postgresql://postgres:postgres@localhost:5434/githubmcp

# ── RAG / AI ──────────────────────────────────────────────────────────────────
GROQ_API_KEY=gsk_your_key_here
RAG_VECTOR_DB=pgvector
RAG_CHROMA_DIR=./chroma_store
RAG_SKIP_LOCAL_DOCS=true

# ── Server ────────────────────────────────────────────────────────────────────
API_PORT=8091
API_HOST=0.0.0.0
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
LOG_LEVEL=INFO
```

---

## 10. Run Database Migrations

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
```

This creates four tables:

| Table | Purpose |
|-------|---------|
| `users` | Firebase UID + email → internal user ID |
| `user_context` | Per-user default owner / repo / project |
| `oauth_connections` | Encrypted GitHub access tokens |
| `audit_logs` | Login and action history |

---

## 11. Index the Codebase for RAG (run once)

```bash
uv run python ingest.py
```

Re-index after major repo changes:

```bash
uv run python ingest.py --reingest
```

Test the RAG chain:

```bash
uv run python rag_query.py "How does auth work?"
```

---

## 12. Start the Servers

Open two terminals:

**Terminal 1 — MCP server (port 8090)**

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

Interactive API docs: [http://localhost:8091/docs](http://localhost:8091/docs)  
Health check: [http://localhost:8091/health](http://localhost:8091/health)

---

## 13. Verify Setup

```bash
# Health
curl http://localhost:8091/health
# → {"status":"ok"}

# Readiness (checks DB)
curl http://localhost:8091/ready
# → {"status":"ready"}
```

Run the test suite (no external services needed):

```bash
cd backend
.venv/bin/pytest tests/ -v
```

---

## 14. Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Firebase not configured` | `FIREBASE_SERVICE_ACCOUNT_PATH` wrong or missing | Check file path is absolute and the file exists |
| `JWT_SECRET` default warning in logs | `JWT_SECRET` not set | Generate and set in `.env` (step 7) |
| `TOKEN_ENCRYPTION_KEY` error | Key not set or malformed | Regenerate with the Fernet command (step 7) |
| `could not connect to server` | PostgreSQL not running | Start Docker container (step 6A) |
| `relation "users" does not exist` | Migrations not run | Run `alembic upgrade head` (step 10) |
| `GROQ_API_KEY not configured` | Key missing | Add to `.env` (step 8) |
| `GitHub OAuth not configured on server` | `GITHUB_CLIENT_ID` or `GITHUB_CLIENT_SECRET` missing | Fill in from the OAuth App (step 5) |
| `Missing scopes` warning | OAuth App missing required scopes | Re-authorise — ensure scope is `repo,read:org,project` |
| `alembic: command not found` | venv not activated | Run `source .venv/bin/activate` first |
