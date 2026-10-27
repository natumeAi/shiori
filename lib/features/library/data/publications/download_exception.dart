/// Safe feature failures; never retains file paths, payloads or OS messages.
final class DownloadException implements Exception {
  const DownloadException(this.failure);
  final DownloadFailure failure;
}

enum DownloadFailure { storage, stagingBusy, invalidValidators }
