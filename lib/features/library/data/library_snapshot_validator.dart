import 'package:shiori/core/config/validated_snapshot.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/cached_library_snapshot.dart';
import 'package:shiori/features/library/data/library_decode_exception.dart';
import 'package:shiori/features/servers/data/candidate_snapshot_validator.dart';
import 'package:shiori/features/servers/data/snapshot_validation_exception.dart';

/// Candidate-only validation, with no conditional request or cache fallback.
final class LibrarySnapshotValidator implements CandidateSnapshotValidator {
  const LibrarySnapshotValidator({this.now});
  final DateTime Function()? now;

  @override
  Future<ValidatedSnapshot> validate(SessionTransport transport) async {
    try {
      final response = await transport.getJson(['api', 'library', 'snapshot']);
      final stored = CachedLibrarySnapshot.fromResponse(
        response,
        now?.call() ?? DateTime.now(),
      ).stored;
      return ValidatedSnapshot(
        payloadText: stored.payload,
        schemaVersion: stored.schemaVersion,
        revision: stored.revision,
        etag: stored.etag,
        fetchedAt: stored.fetchedAt,
      );
    } on LibraryDecodeException catch (error) {
      throw SnapshotValidationException(
        error.incompatible
            ? SnapshotValidationIssue.incompatible
            : SnapshotValidationIssue.malformed,
      );
    } on ParseException {
      throw const SnapshotValidationException(
        SnapshotValidationIssue.malformed,
      );
    }
  }
}
