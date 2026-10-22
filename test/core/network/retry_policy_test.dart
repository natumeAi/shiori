import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/retry_policy.dart';

import '../../helpers/provider_exception.dart';

void main() {
  test('retries NetworkException with exponential backoff', () {
    const error = NetworkException();

    expect(retryNetworkErrors(0, error), const Duration(milliseconds: 200));
    expect(retryNetworkErrors(1, error), const Duration(milliseconds: 400));
    expect(retryNetworkErrors(2, error), const Duration(milliseconds: 800));
  });

  test('stops retrying NetworkException after 3 attempts', () {
    expect(retryNetworkErrors(3, const NetworkException()), isNull);
    expect(retryNetworkErrors(4, const NetworkException()), isNull);
  });

  test('does not retry other AppExceptions', () {
    expect(retryNetworkErrors(0, const UnauthorizedException()), isNull);
    expect(retryNetworkErrors(0, const ServerException(500)), isNull);
    expect(retryNetworkErrors(0, const ParseException()), isNull);
  });

  test('does not retry errors outside AppException', () {
    expect(retryNetworkErrors(0, StateError('bug')), isNull);
    expect(retryNetworkErrors(0, Exception('unknown')), isNull);
  });

  test('does not retry a ProviderException from a failed dependency', () {
    final error = providerException(const NetworkException());

    expect(retryNetworkErrors(0, error), isNull);
  });
}
