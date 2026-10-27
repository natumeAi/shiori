import 'package:shiori/core/storage/stored_publication.dart';
import 'package:shiori/features/library/data/publications/local_publication.dart';

/// In-memory generation pin. Releasing does not delete bytes synchronously.
final class PublicationLease {
  PublicationLease(this.generation, this.local, this._release);
  final StoredPublication generation;
  final LocalPublication local;
  final void Function() _release;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}
