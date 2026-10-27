import 'dart:io';

/// Optional host-test seams; production uses real rename and no boundary hook.
final class PublicationCacheHooks {
  const PublicationCacheHooks({this.rename, this.delete, this.atBoundary});
  final Future<void> Function(File source, String destination)? rename;
  final Future<void> Function(File file)? delete;
  final Future<void> Function(PublicationCacheBoundary)? atBoundary;
}

enum PublicationCacheBoundary { afterRename, beforeCommit, afterCommit }
