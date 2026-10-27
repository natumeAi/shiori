import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';

/// Keep open from before detail/download/worker preparation through publication.
/// The captured previous head remains pinned even when a refresh supersedes us.
final class PublicationAttempt {
  PublicationAttempt(
    this._check,
    this._onClose, {
    required this.session,
    required this.key,
    required this.generation,
    required this.previousHead,
  });

  final ServerSession session;
  final BookKey key;
  final int generation;
  final PublicationLease? previousHead;
  final void Function() _check;
  final void Function() _onClose;
  bool _closed = false;

  void checkCurrent() => _check();
  bool get isClosed => _closed;
  void close() {
    if (_closed) return;
    _closed = true;
    previousHead?.release();
    _onClose();
  }
}
