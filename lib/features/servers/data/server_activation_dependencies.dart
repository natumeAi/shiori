import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/server_selection_store.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/config/validated_snapshot.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/core/storage/sqlite_server_selection_store.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/features/servers/data/candidate_snapshot_validator.dart';
import 'package:shiori/features/servers/data/snapshot_validation_exception.dart';

part 'server_activation_dependencies.g.dart';

/// Production uses the container-owned SQLite worker; tests may override the port.
@Riverpod(keepAlive: true)
ServerSelectionStore serverSelectionStore(Ref ref) =>
    SqliteServerSelectionStore(() => ref.read(sqliteStoreProvider.future));

/// Phase C supplies validation. Until configured, activation fails recoverably
/// as an incompatible snapshot without dispatching a commit.
@Riverpod(keepAlive: true)
CandidateSnapshotValidator candidateSnapshotValidator(Ref ref) =>
    const _UnconfiguredSnapshotValidator();

final class _UnconfiguredSnapshotValidator
    implements CandidateSnapshotValidator {
  const _UnconfiguredSnapshotValidator();

  @override
  Future<ValidatedSnapshot> validate(SessionTransport transport) async =>
      throw const SnapshotValidationException(
        SnapshotValidationIssue.incompatible,
      );
}

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

/// Outlives controller rebuilds so restoration cannot read ahead of a commit.
final class ServerActivationSerializer {
  Completer<void>? _pending;

  Future<void> waitForIdle() async {
    while (_pending != null) {
      await _pending!.future;
    }
  }

  Completer<void> begin() {
    if (_pending != null) throw StateError('Activation already committing');
    return _pending = Completer<void>();
  }

  void finish(Completer<void> pending) {
    if (!identical(_pending, pending)) return;
    _pending = null;
    pending.complete();
  }
}

@Riverpod(keepAlive: true)
ServerActivationSerializer serverActivationSerializer(Ref ref) =>
    ServerActivationSerializer();
