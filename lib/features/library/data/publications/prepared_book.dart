import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/reader/data/worker/prepared_publication.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';

/// Detached import summary plus a pin on verified immutable cache bytes.
/// Shared/coalesced callers share ownership; S4 acquires its own cache lease
/// before the preparation controller releases this one.
final class PreparedBook {
  PreparedBook(this.publication, this.lease, this._onRelease);
  final PreparedPublication publication;
  final PublicationLease lease;
  final void Function() _onRelease;
  bool _released = false;

  ContentIdentity get identity => publication.identity;
  PublicationLayoutFacts get layoutFacts => publication.layoutFacts;
  bool get isReleased => _released;

  void release() {
    if (_released) return;
    _released = true;
    lease.release();
    _onRelease();
  }
}
