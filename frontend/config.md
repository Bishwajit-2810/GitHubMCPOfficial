# Configuration Guide

Everything needed to run the Flutter frontend against the FastAPI BFF.

---

## 1. Firebase Project

### 1.1 Create a Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → give it a name → create
3. Note the **Project ID** (e.g. `githubmcp-12345`)

### 1.2 Enable Authentication providers

In Firebase console → **Authentication** → **Sign-in method**:

| Provider           | Required steps                        |
|--------------------|---------------------------------------|
| **Google**         | Enable → set support email → Save     |
| **Email/Password** | Enable → Save                         |

> GitHub is **not** used as a Firebase sign-in provider. GitHub OAuth is only used after login to grant the backend `repo`, `read:org`, and `project` scopes for API access.

### 1.3 Register the Android app

1. Firebase console → Project settings → **Add app** → Android
2. **Package name**: `com.example.frontend` (or your custom ID from `build.gradle.kts`)
3. Download `google-services.json`
4. Place it at: `frontend/android/app/google-services.json`

### 1.4 Register the iOS app

1. Firebase console → Project settings → **Add app** → iOS
2. **Bundle ID**: `com.example.frontend` (or your custom ID from Xcode)
3. Download `GoogleService-Info.plist`
4. Add it to Xcode: open `frontend/ios/Runner.xcworkspace` → drag the plist into the Runner target

### 1.5 Add the google-services plugin (Android)

`android/build.gradle` — add to `dependencies`:
```groovy
classpath 'com.google.gms:google-services:4.4.2'
```

`android/app/build.gradle.kts` — add at the bottom:
```kotlin
apply(plugin = "com.google.gms.google-services")
```

---

## 2. GitHub OAuth App (API scopes)

You need **one** GitHub OAuth App for backend API access (repo, read:org, project scopes). GitHub is not used as a Firebase sign-in provider.

| Field                      | Value                          |
|----------------------------|--------------------------------|
| Application name           | `GitHub MCP — Backend`         |
| Homepage URL               | `http://localhost:8091`        |
| Authorization callback URL | `githubmcp://oauth/callback`   |

After creating:
- Copy **Client ID** into `frontend/lib/config/constants.dart` → `githubOAuthClientId`
- Copy **Client ID** + **Client secret** into `backend/.env` → `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET`
- Set `backend/.env` → `GITHUB_OAUTH_REDIRECT_URI=githubmcp://oauth/callback`

---

## 3. Flutter App Constants

Edit `frontend/lib/config/constants.dart`:

```dart
// BFF base URL
// Android emulator: 10.0.2.2 maps to host machine localhost
static const String apiBaseUrl = 'http://10.0.2.2:8091/api/v1';

// iOS simulator or physical device on same LAN:
// static const String apiBaseUrl = 'http://192.168.1.x:8091/api/v1';

// Client ID from the backend GitHub OAuth App (2.2 above)
static const String githubOAuthClientId = 'Ov23liXXXXXXXXXX';
```

---

## 4. Backend `.env` (relevant frontend keys)

```env
# Backend GitHub OAuth App (must match constants.dart redirect URI)
GITHUB_CLIENT_ID=Ov23liXXXXXXXXXX
GITHUB_CLIENT_SECRET=your_secret_here
GITHUB_OAUTH_REDIRECT_URI=githubmcp://oauth/callback

# CORS — allow the emulator / simulator origin if needed
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
```

---

## 5. Install dependencies and run

```bash
cd frontend
flutter pub get

# Android emulator
flutter run -d android

# iOS simulator
flutter run -d ios

# Check for issues
flutter analyze
```

---

## 6. Full login flow

Both Google and email/password sign-in produce a Firebase ID token — the backend handles them identically.

```text
1. Launch app → redirected to /login (no JWT in storage)
2. Tap "Continue with Google" or enter email + password
   → Firebase signs in the user and returns an ID token
3. App calls POST /api/v1/auth/firebase-login { id_token }
   → Backend verifies with Firebase Admin SDK, returns JWT
4. JWT stored in flutter_secure_storage → app redirected to /dashboard
5. Tap "Connect GitHub"
   → flutter_web_auth_2 opens browser to:
     https://github.com/login/oauth/authorize?client_id=...&scope=repo,read:org,project&redirect_uri=githubmcp://oauth/callback
   → User authorises on GitHub
   → GitHub redirects to githubmcp://oauth/callback?code=xxx
   → App extracts code → POST /api/v1/auth/connect-github { code }
   → Backend exchanges code for GitHub access token, stores encrypted
6. Tasks and Ask Codebase features unlocked
7. Tap Settings → set owner/repo/project number
   → POST /api/v1/auth/context persists on backend
```

---

## 7. Troubleshooting

| Issue | Fix |
|-------|-----|
| `google-services.json` not found | Re-download from Firebase → place at `android/app/google-services.json` |
| `GoogleService-Info.plist` not found | Add via Xcode drag-and-drop into Runner target |
| `Connection refused` on emulator | Use `10.0.2.2` not `localhost` for Android emulator |
| `Connection refused` on physical device | Use your machine's LAN IP (e.g. `192.168.1.x`) |
| GitHub OAuth callback not received | Verify `githubmcp` scheme is in `AndroidManifest.xml` and `Info.plist` |
| `TOKEN_ENCRYPTION_KEY` error | Generate: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` |
| Firebase `CONFIGURATION_NOT_FOUND` | `google-services.json` or `GoogleService-Info.plist` missing / wrong package name |
| `Missing scopes` warning in backend logs | Re-connect GitHub — the OAuth App must request `repo,read:org,project` |
