import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';

sealed class PreparationState {
  const PreparationState();
  const factory PreparationState.idle() = PreparationIdle;
  const factory PreparationState.preparing({
    int? receivedBytes,
    int? totalBytes,
  }) = PreparationPreparing;
  const factory PreparationState.ready(PreparedBook book) = PreparationReady;
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

final class PreparationFailed extends PreparationState {
  const PreparationFailed(this.error);
  final PrepareBookException error;
}
