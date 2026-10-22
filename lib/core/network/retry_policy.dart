import 'package:shiori/core/errors/app_exception.dart';

/// Retry policy for the root `ProviderScope`.
///
/// Only [NetworkException] is retried: up to 3 times, after 200, 400, and
/// 800 ms. Everything else fails immediately, including Riverpod's
/// `ProviderException` (a dependency failed): the failing dependency runs
/// this policy itself, and dependents rebuild once it recovers.
Duration? retryNetworkErrors(int retryCount, Object error) {
  if (retryCount >= 3 || error is! NetworkException) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}
