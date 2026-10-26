import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/storage/sqlite_server_selection_store.dart';
import 'package:shiori/core/storage/sqlite_store_test_hooks.dart';
import 'package:shiori/features/servers/data/server_activation_state.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';

import '../../../core/storage/store_test_support.dart' as storage;
import '../server_activation_test_support.dart' as fake;
import '../sqlite_activation_test_support.dart';

void main() {
  late storage.StoreFixture directories;
  setUp(() async {
    directories = storage.StoreFixture(
      await Directory.systemTemp.createTemp('shiori-activation-rebuild-'),
    );
    addTearDown(directories.dispose);
  });

  for (final phase in [CandidatePhase.validating, CandidatePhase.committing]) {
    for (final queueNext in [false, true]) {
      test(
        'synchronous rebuild at $phase (queued=$queueNext) preserves SQLite/session agreement',
        () async {
          final h = SqliteActivationHarness(directories);
          addTearDown(h.close);
          await h.restore();
          await h.activate('a');
          final previous = h.state.session!;
          Future<ServerActivationState>? restoring;
          Future<void>? queued;
          final rebuilt = Completer<void>();
          var invalidated = false;
          final sub = h.container.listen(serverActivationControllerProvider, (
            _,
            next,
          ) {
            final value = next.asData?.value;
            if (!rebuilt.isCompleted &&
                value?.phase == CandidatePhase.idle &&
                (value?.session?.generation ?? 0) > previous.generation) {
              rebuilt.complete();
            }
            if (!invalidated && next.asData?.value.phase == phase) {
              invalidated = true;
              h.container.invalidate(serverActivationControllerProvider);
              restoring = h.restore();
              if (queueNext) queued = h.activate('c');
            }
          });
          addTearDown(sub.close);
          await h.activate('b');
          await restoring;
          // Reentrant .future reads may return retained data while rebuilding.
          await rebuilt.future;
          await queued;
          expect(invalidated, isTrue);
          expect(
            h.state.session!.serverKey,
            queueNext ? ServerKey(fake.endpoint('c')) : previous.serverKey,
          );
          expect(h.state.session!.generation, greaterThan(previous.generation));
          expect(await h.store.readActiveServer(), h.state.session!.serverKey);
          expect(
            h.guard.isCurrent(h.state.session!),
            isTrue,
            reason:
                'published=${h.state.session!.generation}, '
                'guard=${h.guard.current?.generation}',
          );
          expect(
            await h.store.readServer(ServerKey(fake.endpoint('b'))),
            isNull,
          );
          expect(
            await h.store.readCurrentSnapshot(ServerKey(fake.endpoint('b'))),
            isNull,
          );
          expect(h.state.failure, isNull);
          expect(h.candidates.last.closed, isTrue);
        },
      );
    }
  }

  for (final fails in [false, true]) {
    test('rebuild awaits dispatched SQLite commit (failure=$fails)', () async {
      final seed = SqliteActivationHarness(directories);
      addTearDown(seed.close);
      await seed.restore();
      await seed.activate('a');
      final previous = seed.state.session!.serverKey;
      final oldSnapshot = (await seed.store.readCurrentSnapshot(previous))!;
      await seed.close();

      final worker = await directories.open(
        hooks: SqliteStoreTestHooks(failActivation: fails),
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      var holdCommit = false;
      // Delay resolution inside the production adapter after the coordinator
      // dispatches commitActivation, without changing the SQLite worker.
      final store = SqliteServerSelectionStore(() async {
        if (holdCommit) {
          holdCommit = false;
          entered.complete();
          await release.future;
        }
        return worker;
      });
      final h = SqliteActivationHarness(
        directories,
        worker: worker,
        selectionStore: store,
      );
      addTearDown(h.close);
      await h.restore();
      holdCommit = true;
      final activation = h.activate('b');
      await entered.future;
      expect(h.state.phase, CandidatePhase.committing);
      h.container.invalidate(serverActivationControllerProvider);
      var restored = false;
      final restoring = h.restore().then((value) {
        restored = true;
        return value;
      });
      await pumpEventQueue(times: 3);
      final restoredBeforeCommit = restored;
      release.complete();
      await activation;
      await restoring;
      expect(restoredBeforeCommit, isFalse);
      final expected = fails ? previous : ServerKey(fake.endpoint('b'));
      expect(await h.store.readActiveServer(), expected);
      expect(h.state.session!.serverKey, expected);
      expect(h.guard.isCurrent(h.state.session!), isTrue);
      expect(h.state.failure, isNull);
      expect(
        (await h.store.readCurrentSnapshot(previous))!.payloadText,
        oldSnapshot.payloadText,
      );
      if (fails) {
        expect(await h.store.readServer(ServerKey(fake.endpoint('b'))), isNull);
      } else {
        expect(await h.store.readCurrentSnapshot(expected), isNotNull);
      }
    });
  }
}
