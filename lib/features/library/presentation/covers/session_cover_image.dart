import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shiori/features/library/presentation/covers/cover_failure.dart';
import 'package:shiori/features/library/presentation/covers/cover_image_exception.dart';
import 'package:shiori/features/library/presentation/covers/cover_lease.dart';
import 'package:shiori/features/library/presentation/covers/cover_load_result.dart';
import 'package:shiori/features/library/presentation/covers/cover_loader.dart';

/// Uses the loader's bounded LRU, including pinned live images. It deliberately
/// bypasses Flutter's global ImageCache, whose live images are outside its quota.
final class SessionCoverImage extends ImageProvider<SessionCoverImage> {
  const SessionCoverImage(this.loader, this.serverCoverPath, {this.maxWidth});
  final CoverLoader loader;
  final String? serverCoverPath;

  /// Physical pixels the cover is displayed at; the loader decodes no wider.
  final int? maxWidth;

  @override
  Future<SessionCoverImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    SessionCoverImage key,
    ImageErrorListener handleError,
  ) {
    if (stream.completer != null) return;
    stream.setCompleter(
      _CoverImageStream(key.loader, key.serverCoverPath, key.maxWidth),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SessionCoverImage &&
      other.loader.session == loader.session &&
      other.serverCoverPath == serverCoverPath &&
      other.maxWidth == maxWidth;

  @override
  int get hashCode => Object.hash(loader.session, serverCoverPath, maxWidth);

  @override
  String toString() => 'SessionCoverImage'; // Never expose a private cover path.
}

final class _CoverImageStream extends ImageStreamCompleter {
  _CoverImageStream(CoverLoader loader, String? path, int? maxWidth) {
    loader.load(path, maxWidth: maxWidth).then((result) {
      if (result case CoverLoaded(:final lease)) {
        if (_removed || !loader.isActive) {
          lease.release();
          return;
        }
        _lease = lease;
        setImage(ImageInfo(image: lease.image.clone()));
      } else if (result case CoverPlaceholder(:final reason)) {
        if (_removed || reason == CoverFailure.cancelled || !loader.isActive) {
          return;
        }
        reportError(exception: CoverImageException(reason), silent: true);
      }
    });
  }

  CoverLease? _lease;
  bool _removed = false;

  @override
  void onDisposed() {
    // TickerMode may remove every listener while keeping a completer handle.
    // Those pixels remain pinned until the stream is actually disposed.
    _removed = true;
    _lease?.release();
    _lease = null;
    super.onDisposed();
  }
}
