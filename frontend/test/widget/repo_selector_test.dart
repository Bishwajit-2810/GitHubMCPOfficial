import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/settings/repo_selector_screen.dart';

import '../helpers/fakes.dart';

Widget _wrap({
  AuthState auth = const AuthState(backendToken: 'tok'),
  ContextState ctx = const ContextState(),
}) =>
    wrap(
      const RepoSelectorScreen(),
      auth: FakeAuth(auth),
      ctx: FakeContext(ctx),
    );

void main() {
  group('RepoSelectorScreen', () {
    testWidgets('renders all form fields', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.widgetWithText(TextFormField, 'Owner *'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Repository *'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Project number (optional)'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('AppBar title is "Repo & Project"', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.widgetWithText(AppBar, 'Repo & Project'), findsOneWidget);
    });

    testWidgets('pre-fills fields from existing context', (tester) async {
      await tester.pumpWidget(_wrap(
        ctx: ContextState(
          context: const UserContext(
            selectedOwner: 'my-org',
            selectedRepo: 'my-repo',
            selectedProjectNumber: 4,
          ),
        ),
      ));
      final editables =
          tester.widgetList<EditableText>(find.byType(EditableText)).toList();
      expect(editables.any((e) => e.controller.text == 'my-org'), isTrue);
      expect(editables.any((e) => e.controller.text == 'my-repo'), isTrue);
      expect(editables.any((e) => e.controller.text == '4'), isTrue);
    });

    testWidgets('shows validation error for empty owner', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Owner is required'), findsOneWidget);
    });

    testWidgets('shows validation error for empty repo', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.enterText(find.widgetWithText(TextFormField, 'Owner *'), 'some-org');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Repository is required'), findsOneWidget);
    });

    testWidgets('shows validation error for non-numeric project number', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.enterText(find.widgetWithText(TextFormField, 'Owner *'), 'org');
      await tester.enterText(find.widgetWithText(TextFormField, 'Repository *'), 'repo');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Project number (optional)'), 'abc');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Must be a number'), findsOneWidget);
    });

    testWidgets('shows spinner while saving', (tester) async {
      await tester.pumpWidget(_wrap(ctx: const ContextState(isLoading: true)));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error banner when context has error', (tester) async {
      await tester.pumpWidget(_wrap(
        ctx: const ContextState(error: 'Failed to save context'),
      ));
      expect(find.text('Failed to save context'), findsOneWidget);
    });

    testWidgets('accepts typed owner and repo values', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.enterText(find.widgetWithText(TextFormField, 'Owner *'), 'bishwajit');
      await tester.enterText(find.widgetWithText(TextFormField, 'Repository *'), 'cool-repo');
      await tester.pump();
      expect(find.text('bishwajit'), findsOneWidget);
      expect(find.text('cool-repo'), findsOneWidget);
    });
  });
}
