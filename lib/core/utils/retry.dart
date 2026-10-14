import 'dart:async';
import 'dart:math';

import '../errors/failure.dart';

/// Retries [action] with exponential backoff, but only for transient failures.
/// Permission/validation failures are rethrown immediately.
Future<T> retryTransient<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 500),
  Future<void> Function(Duration)? sleep,
}) async {
  final wait = sleep ?? Future<void>.delayed;
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action();
    } catch (e) {
      final failure = Failure.from(e);
      if (!failure.isTransient || attempt >= maxAttempts) throw failure;
      await wait(baseDelay * pow(2, attempt - 1).toInt());
    }
  }
}
