import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/selection_storage_exception.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/server_selection_store.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/servers/data/health_repository.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';
import 'package:shiori/features/servers/data/server_activation_failure.dart';
import 'package:shiori/features/servers/data/server_activation_state.dart';

part 'server_activation_controller.g.dart';

@Riverpod(keepAlive: true)
class ServerActivationController extends _$ServerActivationController {
  late ServerSelectionStore _store;
  late SessionPublicationGuard _guard;
  late ServerActivationSerializer _serializer;
  late Future<ServerActivationState> _restoration;
  int _requestSerial = 0;
  Object _lifetime = Object();
  _CandidateAttempt? _attempt;
  Completer<void>? _commitDone;
  SessionTransport? _activeTransport;

  @override
  Future<ServerActivationState> build() {
    _store = ref.watch(serverSelectionStoreProvider);
    _guard = ref.watch(sessionPublicationGuardProvider);
    _serializer = ref.watch(serverActivationSerializerProvider);
    final activeTransport = ref.watch(activeSessionTransportFactoryProvider);
    final lifetime = _lifetime = Object();
    ref.onDispose(() {
      _requestSerial++;
      _attempt?.cancel();
      _activeTransport?.dispose();
      _guard.retire();
    });
    return _restoration = _restore(lifetime, activeTransport);
  }

  Future<ServerActivationState> _restore(
    Object lifetime,
    CandidateTransportFactory activeTransport,
  ) async {
    await _serializer.waitForIdle();
    if (!ref.mounted || lifetime != _lifetime) {
      return const ServerActivationState();
    }
    final key = await _store.readActiveServer();
    if (!ref.mounted || lifetime != _lifetime) {
      return const ServerActivationState();
    }
    if (key == null) return const ServerActivationState();
    final stored = await _store.readServer(key);
    if (!ref.mounted || lifetime != _lifetime) {
      return const ServerActivationState();
    }
    final endpoint = stored == null
        ? null
        : ServerEndpoint.parse(stored.canonicalEndpoint).endpoint;
    if (endpoint == null ||
        endpoint.canonicalRoot != stored!.canonicalEndpoint ||
        ServerKey(endpoint) != key) {
      throw const SelectionStorageException(
        SelectionStorageIssue.invalidSelection,
      );
    }
    final session = _guard.createSession(endpoint);
    _activeTransport = activeTransport(session);
    _guard.select(session);
    return ServerActivationState(session: session);
  }

  Future<void> activate(String text) async {
    final serial = ++_requestSerial;
    final lifetime = _lifetime;
    // Reentrant .future reads during a state notification can retain old data.
    // Admission must await this build's actual storage restoration instead.
    await _restoration;
    if (!ref.mounted || lifetime != _lifetime) return;
    // Transactions cannot be undone through this port. Admission waits for
    // commit+publication; only the latest waiting request starts validation.
    await _serializer.waitForIdle();
    if (!ref.mounted || lifetime != _lifetime || serial != _requestSerial) {
      return;
    }
    _attempt?.cancel();
    final parsed = ServerEndpoint.parse(text);
    final endpoint = parsed.endpoint;
    if (endpoint == null) {
      _setFeedback(
        ServerActivationFailure(
          ActivationFailureKind.invalidEndpoint,
          endpointIssue: parsed.issue,
        ),
      );
      return;
    }
    final session = _guard.createSession(endpoint);
    final transport = ref.read(candidateTransportFactoryProvider)(session);
    final attempt = _attempt = _CandidateAttempt(serial, lifetime, transport);
    state = AsyncData(
      ServerActivationState(
        session: _guard.current,
        phase: CandidatePhase.validating,
      ),
    );
    await _validateAndCommit(attempt);
  }

  /// Cancel validation or queued admission. A dispatched commit finishes first.
  void cancelCandidate() {
    _requestSerial++;
    if (state.isLoading) return;
    if (_commitDone != null) return;
    _attempt?.cancel();
    _attempt = null;
    _setFeedback(null);
  }

  bool _owns(_CandidateAttempt attempt) =>
      ref.mounted &&
      attempt.lifetime == _lifetime &&
      identical(_attempt, attempt) &&
      !attempt.cancelled;

  Future<void> _validateAndCommit(_CandidateAttempt attempt) async {
    final serializer = _serializer;
    Completer<void>? commitDone;
    try {
      await attempt.wait(HealthRepository(attempt.transport).validate());
      if (!_owns(attempt)) return;
      final validator = ref.read(candidateSnapshotValidatorProvider);
      final snapshot = await attempt.wait(
        validator.validate(attempt.transport),
      );
      if (!_owns(attempt)) return;
      commitDone = _commitDone = serializer.begin();
      state = AsyncData(
        ServerActivationState(
          session: _guard.current,
          phase: CandidatePhase.committing,
        ),
      );
      // A synchronous state listener may retire this owner before dispatch.
      if (!_owns(attempt)) return;
      final endpoint = attempt.transport.session.endpoint;
      await _store.commitActivation(
        endpoint: endpoint,
        key: attempt.transport.session.serverKey,
        snapshot: snapshot,
      );
      if (!_owns(attempt)) return;
      final session = _select(endpoint);
      _guard.publish(session, () {
        state = AsyncData(ServerActivationState(session: session));
      });
    } on RequestCancelled {
      if (_owns(attempt)) _setFeedback(null);
    } catch (error) {
      if (!_owns(attempt)) return;
      final failure = ServerActivationFailure.classify(error);
      if (failure == null) rethrow;
      _setFeedback(failure);
    } finally {
      attempt.transport.dispose();
      if (identical(_attempt, attempt)) _attempt = null;
      if (commitDone != null) {
        _commitDone = null;
        serializer.finish(commitDone);
      }
    }
  }

  ServerSession _select(ServerEndpoint endpoint) {
    final previous = _guard.current;
    _guard.retire();
    _activeTransport?.dispose();
    if (previous != null) ref.invalidate(sessionTransportProvider(previous));
    final session = _guard.createSession(endpoint);
    _activeTransport = ref.read(sessionTransportProvider(session));
    _guard.select(session);
    return session;
  }

  void _setFeedback(ServerActivationFailure? failure) {
    if (!ref.mounted) return;
    state = AsyncData(
      ServerActivationState(session: _guard.current, failure: failure),
    );
  }
}

final class _CandidateAttempt {
  _CandidateAttempt(this.serial, this.lifetime, this.transport);

  final int serial;
  final Object lifetime;
  final SessionTransport transport;
  final Completer<void> _cancellation = Completer<void>();
  bool get cancelled => _cancellation.isCompleted;

  /// Completes the caller even if an injected validator ignores cancellation.
  /// Future.any also consumes any later error from that abandoned operation.
  Future<T> wait<T>(Future<T> operation) => Future.any([
    operation,
    _cancellation.future.then<T>((_) => throw const RequestCancelled()),
  ]);

  void cancel() {
    if (cancelled) return;
    _cancellation.complete();
    transport.dispose();
  }
}
