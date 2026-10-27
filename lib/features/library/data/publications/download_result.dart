import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/features/library/data/publications/local_publication.dart';
import 'package:shiori/features/library/data/publications/publication_staging.dart';

sealed class DownloadResult {
  const DownloadResult();
}

/// Transfer-verified only. Container/package validation and publication are D2/D3.
final class StagedDownload extends DownloadResult {
  const StagedDownload({
    required this.key,
    required this.file,
    required this.byteLength,
    required this.digest,
    required this.etag,
    required this.lastModified,
  });

  final BookKey key;
  final StagingFile file;
  String get path => file.path;
  final int byteLength;
  final String digest;
  final String? etag;
  final String? lastModified;
}

final class DownloadNotModified extends DownloadResult {
  const DownloadNotModified(this.local);
  final LocalPublication local;
}
