import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/tasks/create_task_screen.dart';

import '../helpers/fakes.dart';

Widget _wrap({
  AuthState auth = const AuthState(backendToken: 'tok'),
  ContextState ctx = const ContextState(),
  TasksState tasks = const TasksState(),
}) =>
    wrap(
      const CreateTaskScreen(),
      auth: FakeAuth(auth),
      ctx: FakeContext(ctx),
      tasks: FakeTasks(tasks),
    );

void main() {
  group('CreateTaskScreen', () {
    testWidgets('renders all form fields', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.widgetWithText(TextFormField, 'Title *'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Description (optional)'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Assignee (optional)'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Label (optional)'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.text('Create Task'), findsOneWidget);
    });

    testWidgets('shows validation error when title is empty', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.tap(find.text('Create Task'));
      await tester.pump();
      expect(find.text('Title is required'), findsOneWidget);
    });

    testWidgets('shows create error banner when creation fails', (tester) async {
      await tester.pumpWidget(_wrap(
        tasks: const TasksState(createError: 'Server error'),
      ));
      expect(find.text('Server error'), findsOneWidget);
    });

    testWidgets('shows spinner in button while creating', (tester) async {
      await tester.pumpWidget(_wrap(
        tasks: const TasksState(isCreating: true),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('status dropdown contains expected options', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Todo'), findsWidgets);
      expect(find.text('In Progress'), findsWidgets);
      expect(find.text('Done'), findsWidgets);
    });

    testWidgets('AppBar title is "New Task"', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.widgetWithText(AppBar, 'New Task'), findsOneWidget);
    });

    testWidgets('typing in title field works', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Title *'), 'My new task');
      expect(find.text('My new task'), findsOneWidget);
    });
  });
}
