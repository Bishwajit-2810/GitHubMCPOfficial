class ApiError implements Exception {
  final String code;
  final String message;
  final dynamic details;

  const ApiError({required this.code, required this.message, this.details});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    final err = json['error'] as Map<String, dynamic>? ?? json;
    return ApiError(
      code: err['code'] as String? ?? 'UNKNOWN',
      message: err['message'] as String? ?? 'An unexpected error occurred.',
      details: err['details'],
    );
  }

  factory ApiError.network(String msg) =>
      ApiError(code: 'NETWORK_ERROR', message: msg);

  factory ApiError.unknown() =>
      const ApiError(code: 'UNKNOWN', message: 'An unexpected error occurred.');

  @override
  String toString() => '[$code] $message';
}
