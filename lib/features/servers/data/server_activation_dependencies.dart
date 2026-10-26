import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/server_selection_store.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/servers/data/candidate_snapshot_validator.dart';

part 'server_activation_dependencies.g.dart';

/// App composition must override this port with the SQLite adapter.
@Riverpod(keepAlive: true)
ServerSelectionStore serverSelectionStore(Ref ref) =>
    throw UnimplementedError('Supply the selection store adapter');

/// App composition must override this port with the Phase C validator.
@Riverpod(keepAlive: true)
CandidateSnapshotValidator candidateSnapshotValidator(Ref ref) =>
    throw UnimplementedError('Supply the snapshot validator');

typedef CandidateTransportFactory = SessionTransport Function(ServerSession);

/// Temporary transports have no active-session provider identity.
@Riverpod(keepAlive: true)
CandidateTransportFactory candidateTransportFactory(Ref ref) =>
    SessionTransport.new;

/// Read dynamically so retiring a family does not rebuild the coordinator that
/// owns that retirement. Other consumers still watch the session family.
@Riverpod(keepAlive: true)
CandidateTransportFactory activeSessionTransportFactory(Ref ref) =>
    (session) => ref.read(sessionTransportProvider(session));

@Riverpod(keepAlive: true)
SessionPublicationGuard sessionPublicationGuard(Ref ref) {
  final guard = SessionPublicationGuard();
  ref.onDispose(guard.retire);
  return guard;
}
