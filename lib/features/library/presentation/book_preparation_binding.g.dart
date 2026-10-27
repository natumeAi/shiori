// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_preparation_binding.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Retain preparation and its ready owner across navigation, until retirement.
/// The route never cancels work or releases a book on behalf of the controller.

@ProviderFor(bookPreparationBinding)
final bookPreparationBindingProvider = BookPreparationBindingFamily._();

/// Retain preparation and its ready owner across navigation, until retirement.
/// The route never cancels work or releases a book on behalf of the controller.

final class BookPreparationBindingProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Retain preparation and its ready owner across navigation, until retirement.
  /// The route never cancels work or releases a book on behalf of the controller.
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
    r'5ade4bcf4fad6e450ca6721f2893a56478074267';

/// Retain preparation and its ready owner across navigation, until retirement.
/// The route never cancels work or releases a book on behalf of the controller.

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

  /// Retain preparation and its ready owner across navigation, until retirement.
  /// The route never cancels work or releases a book on behalf of the controller.

  BookPreparationBindingProvider call(ServerSession session, BookKey key) =>
      BookPreparationBindingProvider._(argument: (session, key), from: this);

  @override
  String toString() => r'bookPreparationBindingProvider';
}
