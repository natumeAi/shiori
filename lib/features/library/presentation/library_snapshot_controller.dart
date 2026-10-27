import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/library/data/library_snapshot_repository.dart';
import 'package:shiori/features/library/data/library_snapshot_state.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'library_snapshot_controller.g.dart';

@riverpod
class LibrarySnapshotController extends _$LibrarySnapshotController {
  late LibrarySnapshotRepository _repository;

  @override
  LibrarySnapshotState build(ServerSession session) {
    final repository = _repository = ref.watch(
      librarySnapshotRepositoryProvider(session),
    );
    final guard = ref.watch(sessionPublicationGuardProvider);
    final subscription = repository.changes.listen((next) {
      if (ref.mounted) guard.publish(session, () => state = next);
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    unawaited(repository.load());
    return repository.state;
  }

  Future<void> refresh() => _repository.refresh();
}
