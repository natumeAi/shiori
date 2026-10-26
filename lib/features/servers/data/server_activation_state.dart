import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/servers/data/server_activation_failure.dart';

enum CandidatePhase { idle, validating, committing }

/// AsyncLoading means restoring. Data with a null session is unconfigured;
/// data with a session is selected, including during a candidate attempt.
final class ServerActivationState {
  const ServerActivationState({
    this.session,
    this.phase = CandidatePhase.idle,
    this.failure,
  });

  final ServerSession? session;
  final CandidatePhase phase;
  final ServerActivationFailure? failure;
}
