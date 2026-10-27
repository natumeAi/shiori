import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/library/data/publications/preparation_controller.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'book_preparation_binding.g.dart';

/// Retain in-flight work and detached summaries across navigation, not leases.
@riverpod
void bookPreparationBinding(Ref ref, ServerSession session, BookKey key) {
  final guard = ref.watch(sessionPublicationGuardProvider);
  if (!guard.isCurrent(session)) return;
  var retention = ref.keepAlive();
  var retained = true;
  var visible = true;
  final provider = preparationControllerProvider(session, key);
  void updateRoute(bool attached) {
    visible = attached;
    // Navigation may remove listeners during widget build. Notify afterwards.
    scheduleMicrotask(() {
      if (!ref.mounted || visible != attached || !guard.isCurrent(session)) {
        return;
      }
      final controller = ref.read(provider.notifier);
      if (attached) {
        unawaited(controller.attachRoute());
      } else {
        controller.detachRoute();
      }
    });
  }

  ref.onCancel(() => updateRoute(false));
  ref.onResume(() => updateRoute(true));
  void retain(PreparationState state) {
    if (!guard.isCurrent(session)) return;
    if (state is PreparationPreparing ||
        state is PreparationReady ||
        state is PreparationDetached) {
      if (!retained) retention = ref.keepAlive();
      retained = true;
      if (!visible && state is PreparationReady) updateRoute(false);
    } else {
      retention.close();
      retained = false;
    }
  }

  // Listening preserves ownership without invalidating this binding on progress.
  // An unobserved watch would dispose its state before rebuilding off screen.
  final subscription = ref.listen(provider, (_, next) => retain(next));
  retain(subscription.read());
  final unregister = guard.onRetire(session, () => retention.close());
  ref.onDispose(unregister);
}
