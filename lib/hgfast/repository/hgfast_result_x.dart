import 'repository.dart';

extension HgfastResultX<T, E> on HgfastResult<T, E> {
  T? get successValue {
    final self = this;
    return self is HgfastResultSuccess<T, E> ? self.value : null;
  }

  E? get failureError {
    final self = this;
    return self is HgfastResultFailure<T, E> ? self.error : null;
  }
}
