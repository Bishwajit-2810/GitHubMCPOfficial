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
  Future<List<String>> connectGithub(String code, {String? redirectUri}) async {
    final resp = await _call(
      () => _dio.post(
        '/auth/connect-github',
        data: {
          'code': code,
          if (redirectUri != null) 'redirect_uri': redirectUri,
        },
      ),
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
      () => _dio.post(
        '/tools/list-tasks',
        data: {
          if (owner != null) 'owner': owner,
          if (projectNumber != null) 'project_number': projectNumber,
          'offset': offset,
          'limit': limit,
        },
      ),
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
      () => _dio.post(
        '/tools/create-task',
        data: {
          'title': title,
          'body': body,
          if (status != null) 'status': status,
          if (owner != null) 'owner': owner,
          if (repo != null) 'repo': repo,
          if (projectNumber != null) 'project_number': projectNumber,
          if (assignee != null) 'assignee': assignee,
          if (label != null) 'label': label,
        },
      ),
    );
  }

  /// POST /tools/list-files
  Future<Map<String, dynamic>> listFiles({
    String path = '',
    String? owner,
    String? repo,
    String? ref,
  }) async {
    return _call(
      () => _dio.post('/tools/list-files', data: {
        'path': path,
        if (owner != null) 'owner': owner,
        if (repo != null) 'repo': repo,
        if (ref != null) 'ref': ref,
      }),
    );
  }

  /// POST /tools/create-branch
  Future<Map<String, dynamic>> createBranch({
    required String branch,
    String? sourceBranch,
    String? owner,
    String? repo,
  }) async {
    return _call(
      () => _dio.post('/tools/create-branch', data: {
        'branch': branch,
        if (sourceBranch != null) 'source_branch': sourceBranch,
        if (owner != null) 'owner': owner,
        if (repo != null) 'repo': repo,
      }),
    );
  }

  /// POST /tools/create-pull-request
  Future<Map<String, dynamic>> createPullRequest({
    required String title,
    required String head,
    String body = '',
    String? base,
    bool draft = false,
    String? owner,
    String? repo,
  }) async {
    return _call(
      () => _dio.post('/tools/create-pull-request', data: {
        'title': title,
        'head': head,
        'body': body,
        if (base != null) 'base': base,
        'draft': draft,
        if (owner != null) 'owner': owner,
        if (repo != null) 'repo': repo,
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
      () => _dio.post(
        '/tools/ask-codebase',
        data: {
          'question': question,
          if (owner != null) 'owner': owner,
          if (repo != null) 'repo': repo,
        },
      ),
    );
  }

  /// POST /tools/create-file
  Future<Map<String, dynamic>> createFile({
    required String path,
    required String content,
    required String message,
    String? branch,
    String? owner,
    String? repo,
  }) async {
    return _call(
      () => _dio.post('/tools/create-file', data: {
        'path': path,
        'content': content,
        'message': message,
        if (branch != null) 'branch': branch,
        if (owner != null) 'owner': owner,
        if (repo != null) 'repo': repo,
      }),
    );
  }

  /// POST /tools/assign-task
  Future<Map<String, dynamic>> assignTask({
    required int issueNumber,
    required List<String> assignees,
    List<String>? labels,
    String? owner,
    String? repo,
  }) async {
    return _call(
      () => _dio.post('/tools/assign-task', data: {
        'issue_number': issueNumber,
        'assignees': assignees,
        if (labels != null) 'labels': labels,
        if (owner != null) 'owner': owner,
        if (repo != null) 'repo': repo,
      }),
    );
  }

  /// POST /tools/update-task-status
  Future<Map<String, dynamic>> updateTaskStatus({
    required String itemId,
    required String status,
    int? projectNumber,
    String? owner,
  }) async {
    return _call(
      () => _dio.post('/tools/update-task-status', data: {
        'item_id': itemId,
        'status': status,
        if (projectNumber != null) 'project_number': projectNumber,
        if (owner != null) 'owner': owner,
      }),
    );
  }

  /// POST /tools/explore-codebase
  Future<Map<String, dynamic>> exploreCodebase({required String query}) async {
    return _call(
      () => _dio.post('/tools/explore-codebase', data: {'query': query}),
    );
  }

  /// POST /tools/create-project-field
  Future<Map<String, dynamic>> createProjectField({
    required String fieldName,
    required String fieldType,
    int? projectNumber,
    String? owner,
  }) async {
    return _call(
      () => _dio.post('/tools/create-project-field', data: {
        'field_name': fieldName,
        'field_type': fieldType,
        if (projectNumber != null) 'project_number': projectNumber,
        if (owner != null) 'owner': owner,
      }),
    );
  }

  /// POST /tools/set-task-fields
  Future<Map<String, dynamic>> setTaskFields({
    required String itemId,
    required Map<String, dynamic> fields,
    int? projectNumber,
    String? owner,
  }) async {
    return _call(
      () => _dio.post('/tools/set-task-fields', data: {
        'item_id': itemId,
        'fields': fields,
        if (projectNumber != null) 'project_number': projectNumber,
        if (owner != null) 'owner': owner,
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
