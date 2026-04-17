import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/api_error.dart';
import 'package:frontend/models/task.dart';
import 'package:frontend/models/user_context.dart';

void main() {
  // ── ApiError ──────────────────────────────────────────────────────────────

  group('ApiError', () {
    test('fromJson parses standard envelope', () {
      final e = ApiError.fromJson({
        'error': {'code': 'MISSING_CONTEXT', 'message': 'No repo set.'},
      });
      expect(e.code, 'MISSING_CONTEXT');
      expect(e.message, 'No repo set.');
      expect(e.details, isNull);
    });

    test('fromJson falls back to flat map when no "error" key', () {
      final e = ApiError.fromJson({'code': 'AUTH_ERROR', 'message': 'Bad token'});
      expect(e.code, 'AUTH_ERROR');
      expect(e.message, 'Bad token');
    });

    test('fromJson uses defaults for missing fields', () {
      final e = ApiError.fromJson({});
      expect(e.code, 'UNKNOWN');
      expect(e.message, 'An unexpected error occurred.');
    });

    test('fromJson captures details field', () {
      final e = ApiError.fromJson({
        'error': {'code': 'X', 'message': 'Y', 'details': {'field': 'title'}},
      });
      expect(e.details, {'field': 'title'});
    });

    test('network factory sets correct code', () {
      final e = ApiError.network('timeout');
      expect(e.code, 'NETWORK_ERROR');
      expect(e.message, 'timeout');
    });

    test('unknown factory returns generic message', () {
      final e = ApiError.unknown();
      expect(e.code, 'UNKNOWN');
      expect(e.message, contains('unexpected'));
    });

    test('toString includes code and message', () {
      const e = ApiError(code: 'FOO', message: 'bar');
      expect(e.toString(), '[FOO] bar');
    });
  });

  // ── UserContext ───────────────────────────────────────────────────────────

  group('UserContext', () {
    test('fromJson parses all fields', () {
      final ctx = UserContext.fromJson({
        'selected_owner': 'my-org',
        'selected_repo': 'my-repo',
        'selected_project_number': 5,
      });
      expect(ctx.selectedOwner, 'my-org');
      expect(ctx.selectedRepo, 'my-repo');
      expect(ctx.selectedProjectNumber, 5);
    });

    test('fromJson handles null fields', () {
      final ctx = UserContext.fromJson({
        'selected_owner': null,
        'selected_repo': null,
        'selected_project_number': null,
      });
      expect(ctx.selectedOwner, isNull);
      expect(ctx.selectedRepo, isNull);
      expect(ctx.selectedProjectNumber, isNull);
    });

    test('toJson round-trips correctly', () {
      const ctx = UserContext(
        selectedOwner: 'org',
        selectedRepo: 'repo',
        selectedProjectNumber: 2,
      );
      final json = ctx.toJson();
      expect(json['selected_owner'], 'org');
      expect(json['selected_repo'], 'repo');
      expect(json['selected_project_number'], 2);
    });

    test('copyWith overrides only specified fields', () {
      const ctx = UserContext(
        selectedOwner: 'org',
        selectedRepo: 'repo',
        selectedProjectNumber: 1,
      );
      final updated = ctx.copyWith(selectedRepo: 'new-repo');
      expect(updated.selectedOwner, 'org');
      expect(updated.selectedRepo, 'new-repo');
      expect(updated.selectedProjectNumber, 1);
    });

    test('isComplete returns true when all fields set', () {
      const ctx = UserContext(
        selectedOwner: 'o',
        selectedRepo: 'r',
        selectedProjectNumber: 1,
      );
      expect(ctx.isComplete, isTrue);
    });

    test('isComplete returns false when any field is null', () {
      expect(const UserContext(selectedOwner: 'o', selectedRepo: 'r').isComplete, isFalse);
      expect(const UserContext(selectedOwner: 'o', selectedProjectNumber: 1).isComplete, isFalse);
      expect(const UserContext().isComplete, isFalse);
    });

    test('toString formats owner/repo/project', () {
      const ctx = UserContext(
        selectedOwner: 'org',
        selectedRepo: 'repo',
        selectedProjectNumber: 3,
      );
      expect(ctx.toString(), 'org/repo #3');
    });

    test('toString uses dashes for null fields', () {
      expect(const UserContext().toString(), '-/- #-');
    });
  });

  // ── Task ──────────────────────────────────────────────────────────────────

  group('Task', () {
    test('fromJson parses full issue payload', () {
      final task = Task.fromJson({
        'item_id': 'PVTI_abc',
        'type': 'ISSUE',
        'title': 'Fix the bug',
        'status': 'In Progress',
        'number': 42,
        'state': 'open',
        'url': 'https://github.com/org/repo/issues/42',
        'assignees': ['alice', 'bob'],
        'labels': [
          {'name': 'bug', 'color': '#d73a4a'},
        ],
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      });

      expect(task.itemId, 'PVTI_abc');
      expect(task.type, 'ISSUE');
      expect(task.title, 'Fix the bug');
      expect(task.status, 'In Progress');
      expect(task.number, 42);
      expect(task.state, 'open');
      expect(task.url, 'https://github.com/org/repo/issues/42');
      expect(task.assignees, ['alice', 'bob']);
      expect(task.labels.length, 1);
      expect(task.labels.first.name, 'bug');
      expect(task.createdAt, '2026-01-01T00:00:00Z');
    });

    test('fromJson handles missing optional fields gracefully', () {
      final task = Task.fromJson({'item_id': 'PVTI_1', 'type': 'DRAFT', 'title': 'Draft'});
      expect(task.status, isNull);
      expect(task.number, isNull);
      expect(task.assignees, isEmpty);
      expect(task.labels, isEmpty);
    });

    test('fromJson defaults title to (no title) when absent', () {
      final task = Task.fromJson({'item_id': 'x', 'type': 'DRAFT'});
      expect(task.title, '(no title)');
    });
  });

  // ── TaskLabel ─────────────────────────────────────────────────────────────

  group('TaskLabel', () {
    test('fromJson parses name and color', () {
      final lbl = TaskLabel.fromJson({'name': 'enhancement', 'color': '#a2eeef'});
      expect(lbl.name, 'enhancement');
      expect(lbl.color, '#a2eeef');
    });

    test('fromJson defaults to empty string and grey on missing fields', () {
      final lbl = TaskLabel.fromJson({});
      expect(lbl.name, '');
      expect(lbl.color, '#888888');
    });
  });
}
