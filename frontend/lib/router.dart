import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_notifier.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/tasks/task_list_screen.dart';
import 'screens/tasks/create_task_screen.dart';
import 'screens/tasks/assign_task_screen.dart';
import 'screens/tasks/update_task_status_screen.dart';
import 'screens/rag/ask_codebase_screen.dart';
import 'screens/rag/explore_codebase_screen.dart';
import 'screens/repo/files_screen.dart';
import 'screens/repo/create_branch_screen.dart';
import 'screens/repo/create_pr_screen.dart';
import 'screens/repo/create_file_screen.dart';
import 'screens/project/create_project_field_screen.dart';
import 'screens/project/set_task_fields_screen.dart';
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
        path: '/files',
        builder: (context, _) => const FilesScreen(),
      ),
      GoRoute(
        path: '/branch/create',
        builder: (context, _) => const CreateBranchScreen(),
      ),
      GoRoute(
        path: '/pr/create',
        builder: (context, _) => const CreatePRScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, _) => const RepoSelectorScreen(),
      ),
      GoRoute(
        path: '/files/create',
        builder: (context, _) => const CreateFileScreen(),
      ),
      GoRoute(
        path: '/tasks/assign',
        builder: (context, _) => const AssignTaskScreen(),
      ),
      GoRoute(
        path: '/tasks/status',
        builder: (context, _) => const UpdateTaskStatusScreen(),
      ),
      GoRoute(
        path: '/explore',
        builder: (context, _) => const ExploreCodebaseScreen(),
      ),
      GoRoute(
        path: '/project/field/create',
        builder: (context, _) => const CreateProjectFieldScreen(),
      ),
      GoRoute(
        path: '/project/fields/set',
        builder: (context, _) => const SetTaskFieldsScreen(),
      ),
    ],
  );
}
