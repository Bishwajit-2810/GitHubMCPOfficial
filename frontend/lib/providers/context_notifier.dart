import 'package:flutter/foundation.dart';
import '../models/api_error.dart';
import '../models/user_context.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class ContextState {
  final bool isLoading;
  final UserContext context;
  final String? error;

  const ContextState({
    this.isLoading = false,
    this.context = const UserContext(),
    this.error,
  });

  ContextState copyWith({
    bool? isLoading,
    UserContext? context,
    String? error,
    bool clearError = false,
  }) =>
      ContextState(
        isLoading: isLoading ?? this.isLoading,
        context: context ?? this.context,
        error: clearError ? null : (error ?? this.error),
      );
}

class ContextNotifier extends ChangeNotifier {
  ContextNotifier(this._api, {ContextState initialState = const ContextState()}) {
    _state = initialState;
  }

  final ApiService _api;

  ContextState _state = const ContextState(); // set in constructor
  ContextState get state => _state;

  void _setState(ContextState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> load() async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final ctx = await _api.getContext();
      await StorageService.saveContextToHive(
        ctx.selectedOwner,
        ctx.selectedRepo,
        ctx.selectedProjectNumber,
      );
      _setState(_state.copyWith(isLoading: false, context: ctx));
    } on ApiError catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<bool> save({
    String? owner,
    String? repo,
    int? projectNumber,
  }) async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final updated = await _api.setContext(UserContext(
        selectedOwner: owner,
        selectedRepo: repo,
        selectedProjectNumber: projectNumber,
      ));
      await StorageService.saveContextToHive(
        updated.selectedOwner,
        updated.selectedRepo,
        updated.selectedProjectNumber,
      );
      _setState(_state.copyWith(isLoading: false, context: updated));
      return true;
    } on ApiError catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.message));
      return false;
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
      return false;
    }
  }
}
