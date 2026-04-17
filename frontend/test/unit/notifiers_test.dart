import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    hiveDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(hiveDir.path);
    await Hive.openBox<String>('tasks_cache');
    await Hive.openBox<String>('context_cache');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  // ── ContextNotifier ───────────────────────────────────────────────────────

  group('ContextNotifier', () {
    late StubApiService api;
    late ContextNotifier notifier;

    setUp(() {
      api = StubApiService();
      notifier = ContextNotifier(api);
    });

    test('initial state is empty with no loading or error', () {
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.context.selectedOwner, isNull);
    });

    test('load() success updates context and clears loading', () async {
      api.returnContext = const UserContext(
        selectedOwner: 'org',
        selectedRepo: 'repo',
        selectedProjectNumber: 2,
      );
      await notifier.load();
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.context.selectedOwner, 'org');
      expect(notifier.state.context.selectedRepo, 'repo');
      expect(notifier.state.context.selectedProjectNumber, 2);
    });

    test('load() ApiError stores error message', () async {
      api.errorToThrow = ApiError(code: 'AUTH_ERROR', message: 'Unauthorized');
      await notifier.load();
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, 'Unauthorized');
    });

    test('load() generic exception stores toString', () async {
      api.errorToThrow = Exception('Network down');
      await notifier.load();
      expect(notifier.state.error, contains('Network down'));
    });

    test('save() success returns true and updates state', () async {
      final ok = await notifier.save(
        owner: 'new-org',
        repo: 'new-repo',
        projectNumber: 7,
      );
      expect(ok, isTrue);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.context.selectedOwner, 'new-org');
      expect(notifier.state.context.selectedProjectNumber, 7);
    });

    test('save() ApiError returns false and stores error', () async {
      api.errorToThrow = ApiError(code: 'X', message: 'Save failed');
      final ok = await notifier.save(owner: 'o', repo: 'r');
      expect(ok, isFalse);
      expect(notifier.state.error, 'Save failed');
    });

    test('second load() clears previous error', () async {
      api.errorToThrow = ApiError(code: 'X', message: 'err');
      await notifier.load();
      expect(notifier.state.error, isNotNull);

      api.reset();
      await notifier.load();
      expect(notifier.state.error, isNull);
    });
  });

  // ── TasksNotifier ─────────────────────────────────────────────────────────

  group('TasksNotifier', () {
    late StubApiService api;
    late TasksNotifier notifier;

    setUp(() {
      api = StubApiService();
      notifier = TasksNotifier(api);
    });

    test('initial state is empty tasks, no loading or error', () {
      expect(notifier.state.tasks, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('load() success populates tasks', () async {
      api.returnTasks = [
        Task(itemId: 'PVTI_1', type: 'ISSUE', title: 'Task A'),
        Task(itemId: 'PVTI_2', type: 'ISSUE', title: 'Task B'),
      ];
      await notifier.load();
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.tasks.length, 2);
      expect(notifier.state.tasks.first.title, 'Task A');
    });

    test('load() ApiError falls back to empty cache and stores error', () async {
      api.errorToThrow = ApiError(code: 'E', message: 'Load failed');
      await notifier.load();
      expect(notifier.state.tasks, isEmpty);
      expect(notifier.state.error, 'Load failed');
    });

    test('load() clears previous error on next successful call', () async {
      api.errorToThrow = ApiError(code: 'E', message: 'err');
      await notifier.load();
      api.reset();
      api.returnTasks = [Task(itemId: 'PVTI_1', type: 'ISSUE', title: 'T')];
      await notifier.load();
      expect(notifier.state.error, isNull);
      expect(notifier.state.tasks.length, 1);
    });

    test('create() success returns true and clears isCreating', () async {
      final ok = await notifier.create(title: 'New task');
      expect(ok, isTrue);
      expect(notifier.state.isCreating, isFalse);
      expect(notifier.state.createError, isNull);
    });

    test('create() ApiError returns false and sets createError', () async {
      api.errorToThrow = ApiError(code: 'E', message: 'Create failed');
      final ok = await notifier.create(title: 'Boom');
      expect(ok, isFalse);
      expect(notifier.state.createError, 'Create failed');
      expect(notifier.state.isCreating, isFalse);
    });

    test('create() forwards all optional params to api', () async {
      final ok = await notifier.create(
        title: 'Full task',
        body: 'desc',
        status: 'Todo',
        owner: 'org',
        repo: 'repo',
        projectNumber: 1,
        assignee: 'alice',
        label: 'bug',
      );
      expect(ok, isTrue);
    });
  });

  // ── RagNotifier ───────────────────────────────────────────────────────────

  group('RagNotifier', () {
    late StubApiService api;
    late RagNotifier notifier;

    setUp(() {
      api = StubApiService();
      notifier = RagNotifier(api);
    });

    test('initial state has no answer, sources or error', () {
      expect(notifier.state.answer, isNull);
      expect(notifier.state.sources, isEmpty);
      expect(notifier.state.error, isNull);
      expect(notifier.state.isLoading, isFalse);
    });

    test('ask() success sets answer and sources', () async {
      api.returnRag = {
        'answer': 'Auth uses Firebase.',
        'sources': ['auth.dart', 'main.dart'],
      };
      await notifier.ask('How does auth work?');
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.answer, 'Auth uses Firebase.');
      expect(notifier.state.sources, ['auth.dart', 'main.dart']);
      expect(notifier.state.error, isNull);
    });

    test('ask() ApiError stores error and clears answer', () async {
      api.errorToThrow = ApiError(code: 'E', message: 'RAG unavailable');
      await notifier.ask('?');
      expect(notifier.state.answer, isNull);
      expect(notifier.state.error, 'RAG unavailable');
      expect(notifier.state.isLoading, isFalse);
    });

    test('ask() generic exception stores toString error', () async {
      api.errorToThrow = Exception('timeout');
      await notifier.ask('?');
      expect(notifier.state.error, contains('timeout'));
    });

    test('ask() clears previous answer before new request', () async {
      api.returnRag = {'answer': 'First answer', 'sources': []};
      await notifier.ask('Q1');
      expect(notifier.state.answer, 'First answer');

      api.returnRag = {'answer': 'Second answer', 'sources': []};
      await notifier.ask('Q2');
      expect(notifier.state.answer, 'Second answer');
    });

    test('reset() clears answer, sources and error', () async {
      api.returnRag = {'answer': 'Something', 'sources': ['a.dart']};
      await notifier.ask('Q');
      expect(notifier.state.answer, isNotNull);

      notifier.reset();
      expect(notifier.state.answer, isNull);
      expect(notifier.state.sources, isEmpty);
      expect(notifier.state.error, isNull);
    });

    test('ask() with missing sources field defaults to empty list', () async {
      api.returnRag = {'answer': 'Answer without sources'};
      await notifier.ask('Q');
      expect(notifier.state.sources, isEmpty);
    });
  });
}
