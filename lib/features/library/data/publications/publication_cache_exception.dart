/// Safe local failures; never retain paths, titles or native filesystem causes.
final class PublicationCacheException implements Exception {
  const PublicationCacheException(this.failure);
  final PublicationCacheFailure failure;
  @override
  String toString() => 'PublicationCacheException(${failure.name})';
}

enum PublicationCacheFailure { storage, cacheBusy, tooLarge, invalidGeneration }
