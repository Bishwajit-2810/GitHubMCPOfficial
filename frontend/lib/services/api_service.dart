import 'package:dio/dio.dart';
import '../models/api_error.dart';
import '../models/task.dart';
import '../models/user_context.dart';

/// All calls to the FastAPI BFF at /api/v1/*.
class ApiService {
  ApiService(this._dio);

  final Dio _dio;

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// Exchange Firebase ID token for backend JWT. Returns the access_token.
  Future<String> firebaseLogin(String idToken) async {
    final resp = await _call(
      () => _dio.post('/auth/firebase-login', data: {'id_token': idToken}),
    );
    return resp['access_token'] as String;
  }

  /// Exchange GitHub OAuth code for stored access token. Returns granted scopes.
  Future<List<String>> connectGithub(String code) async {
    final resp = await _call(
      () => _dio.post('/auth/connect-github', data: {'code': code}),
    );
    return (resp['scopes'] as List<dynamic>).map((e) => e as String).toList();
  }

  /// GET /auth/context
  Future<UserContext> getContext() async {
    final resp = await _call(() => _dio.get('/auth/context'));
    return UserContext.fromJson(resp);
  }

  /// POST /auth/context
  Future<UserContext> setContext(UserContext ctx) async {
    final resp = await _call(
      () => _dio.post('/auth/context', data: ctx.toJson()),
    );
    return UserContext.fromJson(resp);
  }

  // ── Tools ──────────────────────────────────────────────────────────────────

  /// POST /tools/list-tasks
  Future<List<Task>> listTasks({
    String? owner,
    int? projectNumber,
    int offset = 0,
    int limit = 50,
  }) async {
    final resp = await _call(
      () => _dio.post('/tools/list-tasks', data: {
        if (owner != null) 'owner': owner,
        if (projectNumber != null) 'project_number': projectNumber,
        'offset': offset,
        'limit': limit,
      }),
    );
    final items = resp['items'] as List<dynamic>? ?? [];
    return items.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /tools/create-task
  Future<Map<String, dynamic>> createTask({
    required String title,
    String body = '',
    String? status,
    String? owner,
    String? repo,
    int? projectNumber,
    String? assignee,
    String? label,
  }) async {
    return _call(
      () => _dio.post('/tools/create-task', data: {
        'title': title,
        'body': body,
        if (status != null) 'status': status,
        if (owner != null) 'owner': owner,
        if (repo != null) 'repo': repo,
        if (projectNumber != null) 'project_number': projectNumber,
        if (assignee != null) 'assignee': assignee,
        if (label != null) 'label': label,
      }),
    );
  }

  /// POST /tools/ask-codebase
  Future<Map<String, dynamic>> askCodebase({
    required String question,
    String? owner,
    String? repo,
  }) async {
    return _call(
      () => _dio.post('/tools/ask-codebase', data: {
        'question': question,
        if (owner != null) 'owner': owner,
        if (repo != null) 'repo': repo,
      }),
    );
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _call(
    Future<Response<dynamic>> Function() fn,
  ) async {
    try {
      final resp = await fn();
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) throw ApiError.fromJson(data);
      throw ApiError.network(e.message ?? 'Network error');
    } catch (e) {
      throw ApiError.unknown();
    }
  }
}
