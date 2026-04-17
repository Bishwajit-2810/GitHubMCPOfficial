# Frontend Upgrade Plan - Flutter App

Target: Build a Flutter app that uses FastAPI REST only (`/api/v1/*`) and supports Firebase authentication (Google and email/password), plus GitHub account connection for repo/project access scopes.

Duration: 2 days in parallel with backend.

## Success Criteria

- [x] App runs on Android and iOS simulators
- [x] Login works via Firebase (Google and email/password)
- [x] Firebase ID token is exchanged for backend JWT
- [x] GitHub account connect flow works (repo/project scopes)
- [x] Task list and ask-codebase screens work end-to-end
- [x] Repo/project selector persists and drives all API requests
- [x] Loading/error/empty states handled consistently
- [x] No direct MCP/SSE dependency

---

## Day 1

### Block 1: App Skeleton

- [x] App lives in `frontend/` (existing Flutter project, fully replaced)
- [x] Use `provider` + `go_router`
- [x] Create structure:
  - `lib/config` (constants, theme)
  - `lib/models` (task, api_error, user_context)
  - `lib/providers` (auth, context, tasks, rag)
  - `lib/screens` (auth, dashboard, tasks, rag, settings)
  - `lib/services` (storage_service, api_service)

### Block 2: Dependencies

- [x] Add core deps:
  - `dio`
  - `provider`
  - `go_router`
  - `flutter_secure_storage`
  - `shared_preferences` (github_connected flag)
  - `hive_flutter` (tasks cache, context cache)
  - `lottie` (loading animations)
- [x] Add Firebase/auth deps:
  - `firebase_core`
  - `firebase_auth`
  - `google_sign_in`
  - `flutter_web_auth_2`

### Block 3: API Client

- [x] Build Dio wrapper (`providers.dart` dioProvider) with:
  - backend base URL from `Constants.apiBaseUrl`
  - auth header injected by `AuthNotifier` on login/restore
  - 401 handling via `onUnauthorized()` → `signOut()`
- [x] Add endpoint wrappers in `ApiService`:
  - `POST /auth/firebase-login`
  - `POST /auth/connect-github`
  - `GET /auth/context`
  - `POST /auth/context`
  - `POST /tools/list-tasks`
  - `POST /tools/create-task`
  - `POST /tools/ask-codebase`

### Block 4: Auth UX

- [x] Login screen with two actions:
  - Continue with Google
  - Continue with Email/Password
- [x] Both sign-in methods use Firebase → get Firebase ID token → call `POST /auth/firebase-login`
- [x] Backend JWT persisted in `flutter_secure_storage`
- [x] Session restore on app startup (`_restoreSession` in `AuthNotifier`)
- [x] Logout and token cleanup (`signOut` clears storage + Dio headers)

Day 1 exit:

- [x] User can sign in and land on dashboard with backend JWT

---

## Day 2

### Block 5: GitHub Connect + Context

- [x] `Connect GitHub` card on dashboard when not connected
- [x] Backend OAuth via `flutter_web_auth_2` → `githubmcp://oauth/callback`
- [x] `githubConnected` persisted in secure storage
- [x] Tasks / RAG tiles locked when GitHub not connected
- [x] Repo/project selector screen (`RepoSelectorScreen`)
- [x] Context persisted via `POST /api/v1/auth/context`

### Block 6: Core Screens

- [x] Dashboard screen with context banner + feature tiles
- [x] Task list screen with pull-to-refresh, status dots, empty/error states
- [x] Create task screen (title, body, status, assignee, label)
- [x] Ask-codebase screen with answer + sources display
- [x] Reusable `AppLoading`, `AppErrorWidget`, `EmptyState` widgets

### Block 7: Quality

- [x] Widget tests:
  - login rendering (title, buttons, error banner, loading)
  - dashboard context rendering (banner, connect card, locked tiles)
  - task list success/error/empty states + task titles
- [x] Demo path: login → connect GitHub → select repo/project → list tasks → ask codebase → logout

Day 2 exit:

- [x] Full vertical slice works without hardcoded repo/project or PAT input

---

## API Contracts Frontend Depends On

- [x] `POST /api/v1/auth/firebase-login` accepts Firebase ID token and returns backend JWT
- [x] `POST /api/v1/auth/connect-github` links GitHub with `repo`, `read:org`, `project` scopes
- [x] `GET /api/v1/auth/context` returns selected owner/repo/project
- [x] `POST /api/v1/auth/context` updates selected owner/repo/project
- [x] All protected routes accept backend JWT

---

## Environment Constants

Edit `lib/config/constants.dart`:

```dart
static const String apiBaseUrl = 'http://10.0.2.2:8091/api/v1'; // Android emulator
static const String githubOAuthClientId = 'your-github-oauth-client-id';
static const String githubOAuthRedirectUri = 'githubmcp://oauth/callback';
```

See `config.md` for full Firebase and GitHub OAuth setup instructions.

---

## Done Checklist

- [x] Login works with Google and email/password (both via Firebase)
- [x] Backend JWT exchange implemented
- [x] GitHub connect flow implemented and enforced
- [x] Repo/project selection persisted and used everywhere
- [x] Task and RAG screens fully functional
- [x] Error/loading/empty states complete
- [x] Widget tests written (11 tests across 3 screen groups)
- [x] Demo flow passes end-to-end
