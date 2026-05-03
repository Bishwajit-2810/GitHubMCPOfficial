import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/rag/ask_codebase_screen.dart';

import '../helpers/fakes.dart';

Widget _wrap({
  AuthState auth = const AuthState(backendToken: 'tok'),
  ContextState ctx = const ContextState(),
  RagState rag = const RagState(),
}) =>
    wrap(
      const AskCodebaseScreen(),
      auth: FakeAuth(auth),
      ctx: FakeContext(ctx),
      rag: FakeRag(rag),
    );

void main() {
  group('AskCodebaseScreen', () {
    testWidgets('shows welcome state on first open', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.text('Ask anything about the codebase'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('AppBar title is "Ask Codebase"', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.widgetWithText(AppBar, 'Ask Codebase'), findsOneWidget);
    });

    testWidgets('shows loading animation while waiting for answer', (tester) async {
      await tester.pumpWidget(_wrap(rag: const RagState(isLoading: true)));
      expect(find.text('Thinking…'), findsOneWidget);
    });

    testWidgets('send button is disabled while loading', (tester) async {
      await tester.pumpWidget(_wrap(rag: const RagState(isLoading: true)));
      final btn =
          tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send_rounded));
      expect(btn.onPressed, isNull);
    });

    testWidgets('shows answer text when RAG returns result', (tester) async {
      await tester.pumpWidget(_wrap(
        rag: const RagState(
          answer: 'Auth uses Firebase Admin SDK.',
          sources: ['auth.dart'],
        ),
      ));
      expect(find.text('Auth uses Firebase Admin SDK.'), findsOneWidget);
    });

    testWidgets('shows source chips when sources are present', (tester) async {
      await tester.pumpWidget(_wrap(
        rag: const RagState(
          answer: 'Some answer',
          sources: ['main.dart', 'api.dart'],
        ),
      ));
      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('api.dart'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(2));
    });

    testWidgets('shows clear button when answer is present', (tester) async {
      await tester.pumpWidget(_wrap(rag: const RagState(answer: 'Something')));
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('no clear button on initial state', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('shows error icon and message on failure', (tester) async {
      await tester.pumpWidget(_wrap(
        rag: const RagState(error: 'GROQ_API_KEY not configured'),
      ));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('GROQ_API_KEY not configured'), findsOneWidget);
    });

    testWidgets('input field accepts text', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.enterText(find.byType(TextField), 'How does auth work?');
      expect(find.text('How does auth work?'), findsOneWidget);
    });
  });
}
