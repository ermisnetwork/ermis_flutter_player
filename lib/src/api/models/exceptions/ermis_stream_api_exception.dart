class ErmisStreamApiException implements Exception {
  ErmisStreamApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
  });

  final String message;
  final int? statusCode;
  final int? errorCode;

  @override
  String toString() =>
      'ErmisStreamApiException(statusCode: $statusCode, errorCode: $errorCode, message: $message)';
}
