/// App-wide constants — edit before running.
/// See config.md in the project root for setup instructions.
class Constants {
  Constants._();

  // ── Backend BFF ──────────────────────────────────────────────────────────
  static const String apiBaseUrl = 'http://10.0.2.2:8091/api/v1';
  // 10.0.2.2 is the Android emulator loopback to host machine.
  // For physical device / iOS simulator, use your machine's LAN IP, e.g.:
  // static const String apiBaseUrl = 'http://192.168.1.x:8091/api/v1';

  // ── GitHub OAuth App (backend scopes: repo, read:org, project) ───────────
  static const String githubOAuthClientId = 'YOUR_GITHUB_OAUTH_CLIENT_ID';
  static const String githubOAuthRedirectScheme = 'githubmcp';
  static const String githubOAuthRedirectUri = 'githubmcp://oauth/callback';

  // ── GitHub OAuth scopes (must match backend _REQUIRED_SCOPES) ────────────
  static const String githubOAuthScope = 'repo,read:org,project';

  // ── Secure storage keys ───────────────────────────────────────────────────
  static const String kBackendToken = 'backend_jwt';
  static const String kGithubConnected = 'github_connected';
}
