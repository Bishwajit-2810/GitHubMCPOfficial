import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'config/constants.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'providers/providers.dart';
import 'router.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await StorageService.initHive();

  final dio = Dio(
    BaseOptions(
      baseUrl: Constants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  final apiService = ApiService(dio);

  final authNotifier = AuthNotifier(apiService, dio);

  // Auto-logout when the backend JWT expires — any 401 triggers sign-out.
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          authNotifier.onUnauthorized();
        }
        handler.next(error);
      },
    ),
  );
  final contextNotifier = ContextNotifier(apiService);
  final tasksNotifier = TasksNotifier(apiService);
  final ragNotifier = RagNotifier(apiService);

  final router = buildRouter(authNotifier);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: apiService),
        ChangeNotifierProvider.value(value: authNotifier),
        ChangeNotifierProvider.value(value: contextNotifier),
        ChangeNotifierProvider.value(value: tasksNotifier),
        ChangeNotifierProvider.value(value: ragNotifier),
      ],
      child: App(router: router),
    ),
  );
}

class App extends StatelessWidget {
  final GoRouter router;
  const App({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GitHub MCP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
