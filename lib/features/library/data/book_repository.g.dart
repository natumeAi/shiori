// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookRepository)
final bookRepositoryProvider = BookRepositoryFamily._();

final class BookRepositoryProvider
    extends $FunctionalProvider<BookRepository, BookRepository, BookRepository>
    with $Provider<BookRepository> {
  BookRepositoryProvider._({
    required BookRepositoryFamily super.from,
    required ServerSession super.argument,
  }) : super(
         retry: null,
         name: r'bookRepositoryProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookRepositoryHash();

  @override
  String toString() {
    return r'bookRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<BookRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookRepository create(Ref ref) {
    final argument = this.argument as ServerSession;
    return bookRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BookRepositoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookRepositoryHash() => r'af6b03f6061a539e3ec4e97bba9b368a262a6e99';

final class BookRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<BookRepository, ServerSession> {
  BookRepositoryFamily._()
    : super(
        retry: null,
        name: r'bookRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  BookRepositoryProvider call(ServerSession session) =>
      BookRepositoryProvider._(argument: session, from: this);

  @override
  String toString() => r'bookRepositoryProvider';
}

/// UI-facing detail read: a retired/disposed view completes without AsyncError.

@ProviderFor(bookDetail)
final bookDetailProvider = BookDetailFamily._();

/// UI-facing detail read: a retired/disposed view completes without AsyncError.

final class BookDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookDetailResult?>,
          BookDetailResult?,
          FutureOr<BookDetailResult?>
        >
    with
        $FutureModifier<BookDetailResult?>,
        $FutureProvider<BookDetailResult?> {
  /// UI-facing detail read: a retired/disposed view completes without AsyncError.
  BookDetailProvider._({
    required BookDetailFamily super.from,
    required (ServerSession, BookKey) super.argument,
  }) : super(
         retry: null,
         name: r'bookDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookDetailHash();

  @override
  String toString() {
    return r'bookDetailProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<BookDetailResult?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookDetailResult?> create(Ref ref) {
    final argument = this.argument as (ServerSession, BookKey);
    return bookDetail(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is BookDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookDetailHash() => r'bff6488cf1939f098ead894c628cb3c4bf97ba30';

/// UI-facing detail read: a retired/disposed view completes without AsyncError.

final class BookDetailFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<BookDetailResult?>,
          (ServerSession, BookKey)
        > {
  BookDetailFamily._()
    : super(
        retry: null,
        name: r'bookDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// UI-facing detail read: a retired/disposed view completes without AsyncError.

  BookDetailProvider call(ServerSession session, BookKey key) =>
      BookDetailProvider._(argument: (session, key), from: this);

  @override
  String toString() => r'bookDetailProvider';
}
