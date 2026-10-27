import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/library/data/publications/preparation_controller.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'book_preparation_binding.g.dart';

/// Retain preparation and its ready owner across navigation, until retirement.
/// The route never cancels work or releases a book on behalf of the controller.
@riverpod
void bookPreparationBinding(Ref ref, ServerSession session, BookKey key) {
  final guard = ref.watch(sessionPublicationGuardProvider);
  if (!guard.isCurrent(session)) return;
  var retention = ref.keepAlive();
  var retained = true;
  void retain(PreparationState state) {
    if (!guard.isCurrent(session)) return;
    if (state is PreparationPreparing || state is PreparationReady) {
      if (!retained) retention = ref.keepAlive();
      retained = true;
    } else {
      retention.close();
      retained = false;
    }
  }

  // Listening preserves ownership without invalidating this binding on progress.
  // An unobserved watch would dispose its state before rebuilding off screen.
  final subscription = ref.listen(
    preparationControllerProvider(session, key),
    (_, next) => retain(next),
  );
  retain(subscription.read());
  final unregister = guard.onRetire(session, () => retention.close());
  ref.onDispose(unregister);
}
