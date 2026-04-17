import 'package:flutter/foundation.dart';
import '../models/api_error.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class TasksState {
  final bool isLoading;
  final List<Task> tasks;
  final String? error;
  final bool isCreating;
  final String? createError;

  const TasksState({
    this.isLoading = false,
    this.tasks = const [],
    this.error,
    this.isCreating = false,
    this.createError,
  });

  TasksState copyWith({
    bool? isLoading,
    List<Task>? tasks,
    String? error,
    bool clearError = false,
    bool? isCreating,
    String? createError,
    bool clearCreateError = false,
  }) =>
      TasksState(
        isLoading: isLoading ?? this.isLoading,
        tasks: tasks ?? this.tasks,
        error: clearError ? null : (error ?? this.error),
        isCreating: isCreating ?? this.isCreating,
        createError:
            clearCreateError ? null : (createError ?? this.createError),
      );
}

class TasksNotifier extends ChangeNotifier {
  TasksNotifier(this._api, {TasksState initialState = const TasksState()}) {
    _state = initialState;
  }

  final ApiService _api;

  TasksState _state = const TasksState(); // set in constructor
  TasksState get state => _state;

  void _setState(TasksState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> load({String? owner, int? projectNumber}) async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final tasks = await _api.listTasks(
        owner: owner,
        projectNumber: projectNumber,
      );
      final cacheKey = '${owner ?? ''}_${projectNumber ?? ''}';
      await StorageService.cacheTaskList(
        cacheKey,
        tasks.map((t) => t.toJson()).toList(),
      );
      _setState(_state.copyWith(isLoading: false, tasks: tasks));
    } on ApiError catch (e) {
      // Fall back to Hive cache on network error
      final cacheKey = '${owner ?? ''}_${projectNumber ?? ''}';
      final cached = StorageService.getCachedTaskList(cacheKey);
      final cachedTasks = cached.map(Task.fromJson).toList();
      _setState(_state.copyWith(
        isLoading: false,
        tasks: cachedTasks,
        error: cachedTasks.isEmpty ? e.message : null,
      ));
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<bool> create({
    required String title,
    String body = '',
    String? status,
    String? owner,
    String? repo,
    int? projectNumber,
    String? assignee,
    String? label,
  }) async {
    _setState(_state.copyWith(isCreating: true, clearCreateError: true));
    try {
      await _api.createTask(
        title: title,
        body: body,
        status: status,
        owner: owner,
        repo: repo,
        projectNumber: projectNumber,
        assignee: assignee,
        label: label,
      );
      _setState(_state.copyWith(isCreating: false));
      return true;
    } on ApiError catch (e) {
      _setState(_state.copyWith(isCreating: false, createError: e.message));
      return false;
    } catch (e) {
      _setState(_state.copyWith(isCreating: false, createError: e.toString()));
      return false;
    }
  }
}
