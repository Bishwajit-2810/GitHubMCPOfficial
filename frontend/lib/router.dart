import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_notifier.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/tasks/task_list_screen.dart';
import 'screens/tasks/create_task_screen.dart';
import 'screens/rag/ask_codebase_screen.dart';
import 'screens/settings/repo_selector_screen.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._auth) {
    _auth.addListener(notifyListeners);
  }

  final AuthNotifier _auth;

  @override
  void dispose() {
    _auth.removeListener(notifyListeners);
    super.dispose();
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _auth.state;
    final loggedIn = auth.isAuthenticated;
    final onLogin = state.uri.path == '/login';

    if (auth.isLoading) return null;
    if (!loggedIn && !onLogin) return '/login';
    if (loggedIn && onLogin) return '/dashboard';
    return null;
  }
}

GoRouter buildRouter(AuthNotifier auth) {
  final notifier = RouterNotifier(auth);
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, _) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/tasks',
        builder: (context, _) => const TaskListScreen(),
      ),
      GoRoute(
        path: '/tasks/create',
        builder: (context, _) => const CreateTaskScreen(),
      ),
      GoRoute(
        path: '/ask',
        builder: (context, _) => const AskCodebaseScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, _) => const RepoSelectorScreen(),
      ),
    ],
  );
}
