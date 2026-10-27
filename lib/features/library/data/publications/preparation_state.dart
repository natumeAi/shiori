import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';
import 'package:shiori/features/reader/data/worker/prepared_publication.dart';

sealed class PreparationState {
  const PreparationState();
  const factory PreparationState.idle() = PreparationIdle;
  const factory PreparationState.preparing({
    int? receivedBytes,
    int? totalBytes,
  }) = PreparationPreparing;
  const factory PreparationState.ready(PreparedBook book) = PreparationReady;
  const factory PreparationState.detached(PreparedPublication publication) =
      PreparationDetached;
  const factory PreparationState.failed(PrepareBookException error) =
      PreparationFailed;
}

final class PreparationIdle extends PreparationState {
  const PreparationIdle();
}

final class PreparationPreparing extends PreparationState {
  const PreparationPreparing({this.receivedBytes, this.totalBytes});
  final int? receivedBytes;
  final int? totalBytes;
}

final class PreparationReady extends PreparationState {
  const PreparationReady(this.book);
  final PreparedBook book;
}

/// Retained display metadata; readiness requires reacquiring a verified head.
final class PreparationDetached extends PreparationState {
  const PreparationDetached(this.publication);
  final PreparedPublication publication;
}

final class PreparationFailed extends PreparationState {
  const PreparationFailed(this.error);
  final PrepareBookException error;
}
