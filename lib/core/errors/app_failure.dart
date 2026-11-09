enum AppFailureKind {
  cancelled,
  timeout,
  connection,
  unauthorized,
  forbidden,
  notFound,
  rateLimited,
  server,
  invalidResponse,
  storageRead,
  storageWrite,
  invalidValue,
  unknown,
}

final class AppFailure {
  const AppFailure(this.kind, {this.safeCode});

  final AppFailureKind kind;
  final String? safeCode;
}

class AppException implements Exception {
  const AppException(this.failure, {this.cause, this.stackTrace});

  final AppFailure failure;
  final Object? cause;
  final StackTrace? stackTrace;
}
