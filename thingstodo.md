# GitHubMCP 2-Day Execution Plan

Created: April 17, 2026
Goal: Deliver a usable, controlled Flutter-ready system in 2 days using your coding speed + coding agents.

## Ground Truth (Code-Verified)

- Backend exists and works as a FastMCP SSE server with 12 tools.
- No frontend exists yet.
- No REST BFF layer exists yet.
- No test suite exists yet.
- No CI workflow exists yet.
- Current tool defaults assume `main` for branch-related operations, while this repo default branch is `master`.
- Current auth model is a single env PAT, not per-user auth/permission.

## Non-Negotiable Scope for 2 Days

Do only what creates end-to-end usable value quickly.

- Must have:
  - REST API wrapper for core flows
  - branch-default safety fix (`main`/`master` handling)
  - basic auth boundary for frontend consumption
  - Flutter vertical slice (auth, task list, ask codebase)
  - smoke tests + CI baseline
- Defer (post 2-day sprint):
  - full real-time collaboration
  - full App Store/Play Store release hardening
  - advanced analytics and enterprise compliance depth

## Execution Model

Run parallel tracks aggressively.

- Track A: Core backend hardening
- Track B: REST BFF layer
- Track C: Flutter vertical slice
- Track D: QA + CI + release readiness

Use coding agents continuously for boilerplate, route scaffolding, model generation, and test templates. Keep your manual effort focused on architecture decisions and critical bug fixes.

## Day 1 Plan (Build + Integrate)

### Block 1 (0-3h): Core hardening first

- [ ] Add startup config fail-fast checks in server startup.
- [ ] Add branch fallback logic:
  - detect repo default branch from GitHub API
  - fallback when caller omits branch/base/source_branch
- [ ] Standardize backend error envelope shape to support UI clients.
- [ ] Add health/readiness endpoint or equivalent probe path.

Exit check:

- [ ] Server starts only with valid config.
- [ ] Branch operations work without hardcoded `main`.

### Block 2 (3-8h): REST BFF skeleton + core endpoints

- [ ] Create BFF app scaffold (FastAPI).
- [ ] Add versioned routes (`/api/v1`).
- [ ] Wire these first endpoints:
  - [ ] list files
  - [ ] list tasks
  - [ ] create task
  - [ ] ask codebase
- [ ] Add request validation and consistent response wrappers.
- [ ] Add auth middleware stub (token parsing + identity context).

Exit check:

- [ ] OpenAPI docs generated.
- [ ] 4 endpoints callable from HTTP client.

### Block 3 (8-12h): Flutter vertical slice bootstrap

- [ ] Create Flutter app shell (routing + state setup).
- [ ] Implement login/session storage flow (minimal viable).
- [ ] Implement task list screen connected to BFF.
- [ ] Implement ask-codebase screen connected to BFF.
- [ ] Add loading/error/empty states on both screens.

Exit check:

- [ ] Android/iOS simulator shows authenticated flow and data rendering.

## Day 2 Plan (Complete + Stabilize)

### Block 4 (0-4h): Complete endpoint coverage for high-value ops

- [ ] Add remaining high-priority write/read routes:
  - [ ] create branch
  - [ ] create file
  - [ ] create pull request
  - [ ] assign task
  - [ ] update task status
  - [ ] set task fields
  - [ ] explore codebase
- [ ] Add rate limiting for mutating endpoints.
- [ ] Add idempotency key support for create operations where practical.

Exit check:

- [ ] Core user journeys are fully API-driven from BFF.

### Block 5 (4-8h): Security and user control baseline

- [ ] Introduce role/scope checks at API layer:
  - [ ] repo read
  - [ ] repo write
  - [ ] project write
  - [ ] rag read
- [ ] Add Firebase Auth integration for identity providers:
  - [ ] Google login
  - [ ] GitHub login (identity only)
  - [ ] email/password login
- [ ] Verify Firebase ID token on every protected API route in FastAPI using Firebase Admin SDK.
- [ ] Add dedicated GitHub account-link flow (`connect_github`) to obtain required GitHub scopes (`repo`, `read:org`, `project`).
- [ ] Add user preference model (default owner/repo/project).
- [ ] Add audit logging for mutating actions.

Exit check:

- [ ] Unauthorized calls are denied with explicit error codes.

### Block 6 (8-12h): Testing, CI, and demo readiness

- [ ] Add smoke tests for critical API routes.
- [ ] Add one integration test path for end-to-end task flow.
- [ ] Add CI workflow:
  - [ ] lint
  - [ ] tests
  - [ ] fail on errors
- [ ] Run final manual verification on Flutter vertical slice.
- [ ] Prepare demo script for full flow.

Exit check:

- [ ] CI green.
- [ ] Demo flow runs end-to-end without manual backend patching.

## Exact Deliverables by End of Day 2

- [ ] Hardened backend that no longer depends on `main` assumptions.
- [ ] FastAPI BFF with production-style request/response contracts for core routes.
- [ ] Flutter app vertical slice using BFF (not direct MCP/SSE).
- [ ] Basic user control layer (auth context + scope checks + preferences).
- [ ] Smoke tests + CI workflow.
- [ ] One short runbook documenting startup and test commands.

## Free Hosting Plan

Host everything with zero cost first, then upgrade only when limits hurt.

### Recommended Free Stack (Primary)

- API/BFF + MCP backend: `Render` free web service
- PostgreSQL: `Neon` free Postgres
- Redis (optional): `Upstash` free Redis
- CI/CD: `GitHub Actions` free tier
- Logs/error tracking (optional): `Sentry` free tier
- Flutter distribution for testing:
  - Android: direct APK sharing or Firebase App Distribution free tier
  - iOS: TestFlight (Apple Developer account required)

### Alternative Free Stack (Fallback)

- API/BFF: `Railway` free trial credits or `Fly.io` free allowance
- Postgres: `Supabase` free tier
- Cache: skip Redis initially and use in-memory cache

### Free-Tier Constraints You Must Design Around

- Cold starts on free compute (first request delay)
- Limited monthly runtime/requests
- Sleep/inactivity shutdown behavior
- Postgres storage/connection limits
- Rate limits on third-party APIs (GitHub, Groq)

### Deployment Architecture (Free Mode)

- One deployable backend service containing:
  - FastAPI BFF routes (`/api/v1`)
  - Internal access to MCP tool layer
- Managed Postgres for user preferences, sessions, and minimal audit logs
- Optional Redis only if rate-limit/cache requires it

### Environment Variables for Free Hosting

- [ ] `GITHUB_TOKEN`
- [ ] `GITHUB_OWNER`
- [ ] `GITHUB_REPO`
- [ ] `PROJECT_ID`
- [ ] `GROQ_API_KEY`
- [ ] `POSTGRES_URL` (from Neon/Supabase)
- [ ] `RAG_VECTOR_DB=pgvector`
- [ ] `RAG_SKIP_LOCAL_DOCS=true`
- [ ] `JWT_SECRET`
- [ ] `API_HOST=0.0.0.0`
- [ ] `API_PORT` (provider-assigned or default)

### 2-Day Hosting Execution Checklist

- [ ] Day 1: create Neon DB and verify PG connection from local.
- [ ] Day 1: deploy backend service to Render with env vars set.
- [ ] Day 1: confirm `/health` and one read endpoint from public URL.
- [ ] Day 2: run ingestion once against hosted DB/vector setup.
- [ ] Day 2: point Flutter app base URL to hosted API.
- [ ] Day 2: validate auth, task list, ask-codebase from mobile client.
- [ ] Day 2: enable GitHub Actions deploy workflow for auto-deploy.

### Cost-Control Rules (Stay Free Longer)

- Keep one backend service only during sprint.
- Disable nonessential background jobs.
- Cache read-heavy endpoints in memory before adding Redis.
- Keep logs minimal and rotate aggressively.
- Add request throttling to prevent accidental quota burn.

## Dashboard Context Plan

The Flutter dashboard must choose repo and project from user selection, not from hardcoded env defaults.

### Context Rule

- [ ] Treat `GITHUB_OWNER`, `GITHUB_REPO`, and `PROJECT_ID` as bootstrap defaults only.
- [ ] Persist the user-selected owner/repo/project in backend storage per account.
- [ ] Send selected context on every dashboard request from Flutter.
- [ ] Never assume one global repo or one global project for the whole app.

### Dashboard Data Flow

- [ ] Flutter logs in and loads available orgs/repos/projects.
- [ ] User selects a repo and a project from the dashboard.
- [ ] Backend stores the selected context for that user/session.
- [ ] Every task, PR, file, and RAG action uses the selected context.
- [ ] App shows the active repo/project in the top-level dashboard UI.

### MCP Tools Still Needed for a Real Dashboard

- [ ] `list_repositories` - list repos the user can access.
- [ ] `get_repository_metadata` - return default branch, visibility, description, and permissions.
- [ ] `list_branches` - populate branch picker in dashboard flows.
- [ ] `get_file_content` - read file contents for code viewer panels.
- [ ] `list_organizations` - list orgs/accounts available to the user token.
- [ ] `list_projects` - list Projects v2 boards for a selected owner/org.
- [ ] `get_project_details` - fetch project name, number, fields, and status columns.
- [ ] `list_project_fields` - return columns/options so the dashboard can render filters and editors.
- [ ] `list_labels` - populate label pickers without manual input.
- [ ] `list_open_pull_requests` - power the dashboard PR overview.
- [ ] `list_open_issues` - power the dashboard issue overview.
- [ ] `get_default_branch` - remove hardcoded `main` assumptions.
- [ ] `trigger_repo_ingestion` - start indexing for the selected repo on demand.
- [ ] `get_ingestion_status` - allow Flutter to poll ingestion progress before enabling RAG.

### Backend Refactor Needed to Support the Dashboard

- [ ] Add a user-context table or equivalent store for selected repo/project state.
- [ ] Move auth headers from global env token to per-request user token context.
- [ ] Refactor GitHub API helper functions to accept injected token/context, not global singleton state.
- [ ] Do not store raw GitHub tokens in JWT payloads.
- [ ] Encrypt GitHub access tokens at rest (DB column encryption/KMS-backed secret strategy).
- [ ] Add context-aware API routes that accept owner/repo/project explicitly.
- [ ] Replace direct dependency on env defaults in dashboard-facing endpoints.
- [ ] In API layer, require explicit owner/repo/project for user-driven actions; do not silently fall back.
- [ ] Add validation that rejects empty or mismatched repo/project selections early.
- [ ] Add cache keys scoped by user + selected repo/project.
- [ ] Add dashboard summary endpoint that returns the current active context and key counts.
- [ ] Add explicit token-scope checks (`repo`, `read:org`, `project`) before enabling dashboard features.
- [ ] Add org/repo permission checks so users only see what their token can access.

### RAG Multi-Repo Requirements (Critical for User-Selected Repo)

- [ ] Remove single hardcoded collection strategy for embeddings.
- [ ] Partition vector data by repo key (owner/repo) and optionally by branch.
- [ ] Store repo metadata on each document chunk for filtered retrieval.
- [ ] Build prompt context from active selected repo, not env default repo.
- [ ] Block ask-codebase until ingestion is complete for selected repo.
- [ ] Add stale-index policy (reindex triggers when branch/head SHA changes).

### Dashboard Acceptance Criteria

- [ ] User can switch repos without editing `.env`.
- [ ] User can switch projects without redeploying backend.
- [ ] Selected repo/project survives app restart.
- [ ] Dashboard cards update from the selected project only.
- [ ] No user-facing flow depends on a single hardcoded repo or project.
- [ ] Dashboard never reads codebase/RAG data from the wrong repo context.
- [ ] API accepts Firebase-authenticated users from Google, GitHub, and email/password login paths.
- [ ] GitHub operations fail with a clear action-required error when GitHub is not connected or scopes are insufficient.

### Final Critical Gaps Checklist (Do Not Skip)

- [ ] Add DB migrations (Alembic) instead of manual table creation.
- [ ] Add token revocation/session invalidation path (logout-all-devices support).
- [ ] Add webhook or scheduled sync strategy for stale project/task state.
- [ ] Add ingestion job locking so two ingest runs for same repo cannot overlap.
- [ ] Add explicit redaction rules so tokens never appear in logs/errors.

## Done Criteria (Strict)

### Backend

- [ ] No hidden runtime env failures.
- [ ] Branch behavior deterministic across `main` and `master` repos.
- [ ] Health/readiness checks available.

### API/BFF

- [ ] Versioned endpoints available and documented.
- [ ] Standard error format used consistently.
- [ ] Auth and permission checks enforce server-side control.

### Flutter

- [ ] Vertical slice works on simulator.
- [ ] All screens handle loading/error/empty cleanly.
- [ ] No direct dependency on MCP transport.

### Quality

- [ ] CI runs automatically on push/PR.
- [ ] Critical smoke tests pass.

## Post-Sprint Backlog (After 2-Day Delivery)

- Full OAuth production hardening (refresh/revoke/device management)
- Push notifications and real-time websocket layer
- Expanded test matrix (unit + integration + E2E)
- Store release hardening and observability expansion
- Advanced workflow automation and integrations

## Agent Assignment Suggestion

Use your coding agents in this split to maximize throughput.

- Agent 1: Backend hardening + branch fallback + health checks
- Agent 2: BFF route scaffolding + schemas + middleware
- Agent 3: Flutter screens + API integration + state handling
- Agent 4: Tests + CI workflow + runbook

You coordinate architecture, merge conflicts, and final acceptance checks.
