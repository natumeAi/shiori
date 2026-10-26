import 'package:shiori/core/config/validated_snapshot.dart';
import 'package:shiori/core/network/session_transport.dart';

/// Phase C must GET api/library/snapshot unconditionally through this candidate
/// transport, with no validators and only HTTP 200 accepted. Validate the whole
/// schema/joins before returning, or throw SnapshotValidationException.
abstract interface class CandidateSnapshotValidator {
  Future<ValidatedSnapshot> validate(SessionTransport transport);
}
