import 'failure.dart';

sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;

  const factory Result.failure(Failure failure) = ErrorResult<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) {
    return switch (this) {
      Success<T>(:final value) => success(value),
      ErrorResult<T>(failure: final error) => failure(error),
    };
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

class ErrorResult<T> extends Result<T> {
  const ErrorResult(this.failure);

  final Failure failure;
}
