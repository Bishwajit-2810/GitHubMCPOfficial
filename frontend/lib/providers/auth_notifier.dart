import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthState {
  final bool isLoading;
  final User? firebaseUser;
  final String? backendToken;
  final bool githubConnected;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.firebaseUser,
    this.backendToken,
    this.githubConnected = false,
    this.error,
  });

  bool get isAuthenticated => backendToken != null;

  AuthState copyWith({
    bool? isLoading,
    User? firebaseUser,
    String? backendToken,
    bool? githubConnected,
    String? error,
    bool clearError = false,
    bool clearToken = false,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        firebaseUser: firebaseUser ?? this.firebaseUser,
        backendToken: clearToken ? null : (backendToken ?? this.backendToken),
        githubConnected: githubConnected ?? this.githubConnected,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._api, this._dio,
      {bool restoreOnInit = true, AuthState initialState = const AuthState()}) {
    _state = initialState;
    if (restoreOnInit) _restoreSession();
  }

  final ApiService _api;
  final Dio _dio;

  AuthState _state = const AuthState(); // set in constructor
  AuthState get state => _state;

  void _setState(AuthState s) {
    _state = s;
    notifyListeners();
  }

  // ── Session restore ────────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    final token = await StorageService.readToken();
    final ghConnected = await StorageService.isGithubConnected();
    if (token != null) {
      _setDioToken(token);
      _setState(_state.copyWith(
        backendToken: token,
        githubConnected: ghConnected,
        firebaseUser: FirebaseAuth.instance.currentUser,
      ));
    }
  }

  // ── Sign-in methods ────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _setState(_state.copyWith(isLoading: false));
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      await _exchangeFirebaseToken(result.user!);
    } on ApiError catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> signInWithGithub() async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final provider = GithubAuthProvider();
      final result =
          await FirebaseAuth.instance.signInWithProvider(provider);
      await _exchangeFirebaseToken(result.user!);
    } on FirebaseAuthException catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.message));
    } on ApiError catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _exchangeFirebaseToken(result.user!);
    } on FirebaseAuthException catch (e) {
      _setState(_state.copyWith(isLoading: false, error: _fbMessage(e)));
    } on ApiError catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> createEmailAccount(String email, String password) async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final result =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _exchangeFirebaseToken(result.user!);
    } on FirebaseAuthException catch (e) {
      _setState(_state.copyWith(isLoading: false, error: _fbMessage(e)));
    } on ApiError catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  // ── Backend token exchange ─────────────────────────────────────────────────

  Future<void> _exchangeFirebaseToken(User user) async {
    final idToken = await user.getIdToken();
    final backendToken = await _api.firebaseLogin(idToken!);
    _setDioToken(backendToken);
    await StorageService.saveToken(backendToken);
    final ghConnected = await StorageService.isGithubConnected();
    _setState(_state.copyWith(
      isLoading: false,
      firebaseUser: user,
      backendToken: backendToken,
      githubConnected: ghConnected,
    ));
  }

  // ── GitHub backend OAuth (repo/project scopes) ────────────────────────────

  Future<void> connectGithub(String code) async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      await _api.connectGithub(code);
      await StorageService.setGithubConnected(true);
      _setState(_state.copyWith(isLoading: false, githubConnected: true));
    } on ApiError catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void onUnauthorized() => signOut();

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    await StorageService.clearAll();
    _clearDioToken();
    _setState(const AuthState());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setDioToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void _clearDioToken() {
    _dio.options.headers.remove('Authorization');
  }

  String _fbMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
