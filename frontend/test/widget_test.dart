import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/auth/login_screen.dart';
import 'package:frontend/screens/dashboard/dashboard_screen.dart';
import 'package:frontend/screens/tasks/task_list_screen.dart';

import 'helpers/fakes.dart';

void main() {
  // ── LoginScreen ─────────────────────────────────────────────────────────────

  group('LoginScreen', () {
    testWidgets('renders title and all sign-in buttons', (tester) async {
      await tester.pumpWidget(wrap(
        const LoginScreen(),
        auth: FakeAuth(const AuthState()),
      ));
      expect(find.text('GitHub MCP'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Email'), findsOneWidget);
    });

    testWidgets('tapping Email shows email form', (tester) async {
      await tester.pumpWidget(wrap(
        const LoginScreen(),
        auth: FakeAuth(const AuthState()),
      ));
      await tester.tap(find.text('Continue with Email'));
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('shows error banner when auth has error', (tester) async {
      await tester.pumpWidget(wrap(
        const LoginScreen(),
        auth: FakeAuth(const AuthState(error: 'Wrong password')),
      ));
      expect(find.text('Wrong password'), findsOneWidget);
    });

    testWidgets('shows spinner when loading', (tester) async {
      await tester.pumpWidget(wrap(
        const LoginScreen(),
        auth: FakeAuth(const AuthState(isLoading: true)),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ── DashboardScreen ──────────────────────────────────────────────────────────

  group('DashboardScreen', () {
    testWidgets('shows repo context banner when set', (tester) async {
      await tester.pumpWidget(wrap(
        const DashboardScreen(),
        auth: FakeAuth(const AuthState(backendToken: 'tok', githubConnected: true)),
        ctx: FakeContext(ContextState(
          context: const UserContext(
            selectedOwner: 'my-org',
            selectedRepo: 'my-repo',
            selectedProjectNumber: 3,
          ),
        )),
      ));
      expect(find.textContaining('my-org/my-repo'), findsOneWidget);
      expect(find.textContaining('Project #3'), findsOneWidget);
    });

    testWidgets('shows Connect GitHub card when not connected', (tester) async {
      await tester.pumpWidget(wrap(
        const DashboardScreen(),
        auth: FakeAuth(const AuthState(backendToken: 'tok', githubConnected: false)),
        ctx: FakeContext(const ContextState()),
      ));
      expect(find.text('GitHub not connected'), findsOneWidget);
      expect(find.text('Connect GitHub'), findsOneWidget);
    });

    testWidgets('hides connect card when GitHub is connected', (tester) async {
      await tester.pumpWidget(wrap(
        const DashboardScreen(),
        auth: FakeAuth(const AuthState(backendToken: 'tok', githubConnected: true)),
        ctx: FakeContext(const ContextState()),
      ));
      expect(find.text('GitHub not connected'), findsNothing);
    });
  });

  // ── TaskListScreen ───────────────────────────────────────────────────────────

  group('TaskListScreen', () {
    testWidgets('shows loading spinner', (tester) async {
      await tester.pumpWidget(wrap(
        const TaskListScreen(),
        auth: FakeAuth(const AuthState(backendToken: 'tok')),
        ctx: FakeContext(const ContextState()),
        tasks: FakeTasks(const TasksState(isLoading: true)),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message and Retry button', (tester) async {
      await tester.pumpWidget(wrap(
        const TaskListScreen(),
        auth: FakeAuth(const AuthState(backendToken: 'tok')),
        ctx: FakeContext(const ContextState()),
        tasks: FakeTasks(const TasksState(error: 'Failed to load tasks')),
      ));
      expect(find.text('Failed to load tasks'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows empty state when list is empty', (tester) async {
      await tester.pumpWidget(wrap(
        const TaskListScreen(),
        auth: FakeAuth(const AuthState(backendToken: 'tok')),
        ctx: FakeContext(const ContextState()),
        tasks: FakeTasks(const TasksState(tasks: [])),
      ));
      expect(find.text('No tasks yet'), findsOneWidget);
    });

    testWidgets('renders task titles in list', (tester) async {
      final tasks = [
        Task(itemId: 'PVTI_1', type: 'ISSUE', title: 'Fix login bug'),
        Task(itemId: 'PVTI_2', type: 'ISSUE', title: 'Add dark mode'),
      ];
      await tester.pumpWidget(wrap(
        const TaskListScreen(),
        auth: FakeAuth(const AuthState(backendToken: 'tok')),
        ctx: FakeContext(const ContextState()),
        tasks: FakeTasks(TasksState(tasks: tasks)),
      ));
      expect(find.text('Fix login bug'), findsOneWidget);
      expect(find.text('Add dark mode'), findsOneWidget);
    });
  });
}
