/// A professional Result wrapper mimicking advanced engineering patterns
/// Found in high-end SDKs and complex engines.
sealed class Result<S, E extends Exception> {
  const Result();

  bool get isSuccess => this is Success<S, E>;
  bool get isFailure => this is Failure<S, E>;

  S? get successOrNull => this is Success<S, E> ? (this as Success<S, E>).value : null;
  E? get failureOrNull => this is Failure<S, E> ? (this as Failure<S, E>).error : null;

  void when({
    required void Function(S value) onSuccess,
    required void Function(E error) onFailure,
  }) {
    if (this is Success<S, E>) {
      onSuccess((this as Success<S, E>).value);
    } else if (this is Failure<S, E>) {
      onFailure((this as Failure<S, E>).error);
    }
  }

  T map<T>({
    required T Function(S value) onSuccess,
    required T Function(E error) onFailure,
  }) {
    if (this is Success<S, E>) {
      return onSuccess((this as Success<S, E>).value);
    } else {
      return onFailure((this as Failure<S, E>).error);
    }
  }
}

class Success<S, E extends Exception> extends Result<S, E> {
  final S value;
  const Success(this.value);
}

class Failure<S, E extends Exception> extends Result<S, E> {
  final E error;
  const Failure(this.error);
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  ApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
