import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// Returns the [ProviderException] Riverpod throws when a provider in error
/// state is read. Its constructor is internal, so it is obtained through the
/// public `AsyncValue.requireValue` path instead.
ProviderException providerException(Object error) {
  try {
    AsyncValue<void>.error(error, StackTrace.empty).requireValue;
  } on ProviderException catch (e) {
    return e;
  }
  throw StateError('requireValue did not throw a ProviderException');
}
