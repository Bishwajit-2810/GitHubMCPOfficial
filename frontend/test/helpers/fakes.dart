/// Shared test helpers: stub ApiService and fake Provider notifiers.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/task.dart';
import 'package:frontend/models/user_context.dart';
import 'package:frontend/providers/auth_notifier.dart';
import 'package:frontend/providers/context_notifier.dart';
import 'package:frontend/providers/rag_notifier.dart';
import 'package:frontend/providers/tasks_notifier.dart';
import 'package:frontend/services/api_service.dart';
import 'package:provider/provider.dart';

export 'package:frontend/providers/auth_notifier.dart';
export 'package:frontend/providers/context_notifier.dart';
export 'package:frontend/providers/rag_notifier.dart';
export 'package:frontend/providers/tasks_notifier.dart';
export 'package:frontend/models/api_error.dart';
export 'package:frontend/models/task.dart';
export 'package:frontend/models/user_context.dart';

// ── Stub ApiService ───────────────────────────────────────────────────────────

class StubApiService extends Fake implements ApiService {
  UserContext returnContext = const UserContext();
  List<Task> returnTasks = [];
  Map<String, dynamic> returnCreateTask = {'item_id': 'PVTI_1', 'title': 'T'};
  Map<String, dynamic> returnRag = {
    'answer': 'The answer is 42.',
    'sources': ['main.dart', 'api.dart'],
  };
  Exception? errorToThrow;

  void reset() => errorToThrow = null;

  @override
  Future<UserContext> getContext() async {
    if (errorToThrow != null) throw errorToThrow!;
    return returnContext;
  }

  @override
  Future<UserContext> setContext(UserContext ctx) async {
    if (errorToThrow != null) throw errorToThrow!;
    return ctx;
  }

  @override
  Future<List<Task>> listTasks({
    String? owner,
    int? projectNumber,
    int offset = 0,
    int limit = 50,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return returnTasks;
  }

  @override
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
    if (errorToThrow != null) throw errorToThrow!;
    return returnCreateTask;
  }

  @override
  Future<Map<String, dynamic>> askCodebase({
    required String question,
    String? owner,
    String? repo,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return returnRag;
  }

  @override
  Future<String> firebaseLogin(String idToken) async {
    if (errorToThrow != null) throw errorToThrow!;
    return 'fake-jwt';
  }

  @override
  Future<List<String>> connectGithub(String code, {String? redirectUri}) async {
    if (errorToThrow != null) throw errorToThrow!;
    return ['repo', 'read:org', 'project'];
  }
}

// ── Fake Notifiers ────────────────────────────────────────────────────────────

class FakeAuth extends AuthNotifier {
  FakeAuth(AuthState initial)
    : super(
        StubApiService(),
        Dio(),
        restoreOnInit: false,
        initialState: initial,
      );

  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithEmail(String e, String p) async {}
  @override
  Future<void> createEmailAccount(String e, String p) async {}
  @override
  Future<void> connectGithub(String code, {String? redirectUri}) async {}
  @override
  Future<void> signOut() async {}
  @override
  void onUnauthorized() {}
}

class FakeContext extends ContextNotifier {
  FakeContext(ContextState initial)
    : super(StubApiService(), initialState: initial);

  @override
  Future<void> load() async {}
  @override
  Future<bool> save({String? owner, String? repo, int? projectNumber}) async =>
      true;
}

class FakeTasks extends TasksNotifier {
  FakeTasks(TasksState initial)
    : super(StubApiService(), initialState: initial);

  @override
  Future<void> load({String? owner, int? projectNumber}) async {}
  @override
  Future<bool> create({
    required String title,
    String body = '',
    String? status,
    String? owner,
    String? repo,
    int? projectNumber,
    String? assignee,
    String? label,
  }) async => true;
}

class FakeRag extends RagNotifier {
  FakeRag(RagState initial) : super(StubApiService(), initialState: initial);

  @override
  Future<void> ask(String q, {String? owner, String? repo}) async {}
  @override
  void reset() {}
}

// ── Widget wrapper ────────────────────────────────────────────────────────────

Widget wrap(
  Widget child, {
  AuthNotifier? auth,
  ContextNotifier? ctx,
  TasksNotifier? tasks,
  RagNotifier? rag,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthNotifier>.value(
      value: auth ?? FakeAuth(const AuthState()),
    ),
    ChangeNotifierProvider<ContextNotifier>.value(
      value: ctx ?? FakeContext(const ContextState()),
    ),
    ChangeNotifierProvider<TasksNotifier>.value(
      value: tasks ?? FakeTasks(const TasksState()),
    ),
    ChangeNotifierProvider<RagNotifier>.value(
      value: rag ?? FakeRag(const RagState()),
    ),
  ],
  child: MaterialApp(home: child),
);
