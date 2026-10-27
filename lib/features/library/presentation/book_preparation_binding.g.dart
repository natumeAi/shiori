// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_preparation_binding.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Retain in-flight work and detached summaries across navigation, not leases.

@ProviderFor(bookPreparationBinding)
final bookPreparationBindingProvider = BookPreparationBindingFamily._();

/// Retain in-flight work and detached summaries across navigation, not leases.

final class BookPreparationBindingProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Retain in-flight work and detached summaries across navigation, not leases.
  BookPreparationBindingProvider._({
    required BookPreparationBindingFamily super.from,
    required (ServerSession, BookKey) super.argument,
  }) : super(
         retry: null,
         name: r'bookPreparationBindingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookPreparationBindingHash();

  @override
  String toString() {
    return r'bookPreparationBindingProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    final argument = this.argument as (ServerSession, BookKey);
    return bookPreparationBinding(ref, argument.$1, argument.$2);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BookPreparationBindingProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookPreparationBindingHash() =>
    r'd839c61b51b5076996c9bcb5b36db4abbb728028';

/// Retain in-flight work and detached summaries across navigation, not leases.

final class BookPreparationBindingFamily extends $Family
    with $FunctionalFamilyOverride<void, (ServerSession, BookKey)> {
  BookPreparationBindingFamily._()
    : super(
        retry: null,
        name: r'bookPreparationBindingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Retain in-flight work and detached summaries across navigation, not leases.

  BookPreparationBindingProvider call(ServerSession session, BookKey key) =>
      BookPreparationBindingProvider._(argument: (session, key), from: this);

  @override
  String toString() => r'bookPreparationBindingProvider';
}
