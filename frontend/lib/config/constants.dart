import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// App-wide constants — edit before running.
/// See config.md in the project root for setup instructions.
class Constants {
  Constants._();

  // ── Backend BFF ──────────────────────────────────────────────────────────
  // Override with: flutter run --dart-define=API_BASE_URL=http://<host>:8091/api/v1
  static const String _apiBaseFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_apiBaseFromEnv.isNotEmpty) return _apiBaseFromEnv;
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'http://localhost:8091/api/v1';
    }
    return 'http://10.0.2.2:8091/api/v1';
  }

  // ── GitHub OAuth App (backend scopes: repo, read:org, project) ───────────
  static const String githubOAuthClientId = 'Ov23liMrvxV66ihCQHCE';
  static const String _githubRedirectFromEnv = String.fromEnvironment(
    'GITHUB_REDIRECT_URI',
    defaultValue: '',
  );

  // Both platforms use the backend relay as the single registered GitHub callback URL.
  // Register exactly this URL in GitHub OAuth App settings (one per line):
  //   http://localhost:8091/api/v1/auth/github/callback
  // Android emulator: run `adb reverse tcp:8091 tcp:8091` so the emulator browser
  // can reach the host machine's backend at localhost:8091.
  static String get githubOAuthRedirectUri {
    if (_githubRedirectFromEnv.isNotEmpty) return _githubRedirectFromEnv;
    return 'http://localhost:8091/api/v1/auth/github/callback';
  }

  // Scheme that flutter_web_auth_2 listens for when OAuth completes.
  // Web:     backend returns postMessage with an http:// URL  → listen for 'http'
  // Android: backend 302-redirects to githubmcp://            → listen for 'githubmcp'
  static String get githubOAuthCallbackScheme => kIsWeb ? 'http' : 'githubmcp';

  // ── GitHub OAuth scopes (must match backend _REQUIRED_SCOPES) ────────────
  static const String githubOAuthScope = 'repo,read:org,project';

  // ── Secure storage keys ───────────────────────────────────────────────────
  static const String kBackendToken = 'backend_jwt';
  static const String kGithubConnected = 'github_connected';
}
