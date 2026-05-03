import 'package:flutter/foundation.dart';
import '../models/api_error.dart';
import '../services/api_service.dart';

class RagState {
  final bool isLoading;
  final String? answer;
  final List<String> sources;
  final String? error;

  const RagState({
    this.isLoading = false,
    this.answer,
    this.sources = const [],
    this.error,
  });

  RagState copyWith({
    bool? isLoading,
    String? answer,
    List<String>? sources,
    String? error,
    bool clearError = false,
    bool clearAnswer = false,
  }) =>
      RagState(
        isLoading: isLoading ?? this.isLoading,
        answer: clearAnswer ? null : (answer ?? this.answer),
        sources: sources ?? this.sources,
        error: clearError ? null : (error ?? this.error),
      );
}

class RagNotifier extends ChangeNotifier {
  RagNotifier(this._api, {RagState initialState = const RagState()}) {
    _state = initialState;
  }

  final ApiService _api;

  RagState _state = const RagState(); // set in constructor
  RagState get state => _state;

  void _setState(RagState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> ask(String question, {String? owner, String? repo}) async {
    _setState(_state.copyWith(
      isLoading: true,
      clearError: true,
      clearAnswer: true,
    ));
    try {
      final result = await _api.askCodebase(
        question: question,
        owner: owner,
        repo: repo,
      );
      final rawSources = result['sources'] as List<dynamic>? ?? [];
      _setState(_state.copyWith(
        isLoading: false,
        answer: result['answer'] as String? ?? '',
        sources: rawSources.map((e) => e as String).toList(),
      ));
    } on ApiError catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void reset() {
    _setState(const RagState());
  }
}
