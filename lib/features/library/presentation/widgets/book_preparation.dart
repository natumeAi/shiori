import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/library/data/publications/preparation_controller.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/library/presentation/book_preparation_binding.dart';
import 'package:shiori/features/library/presentation/widgets/preparation_failure_message.dart';
import 'package:shiori/l10n/l10n.dart';

class BookPreparation extends ConsumerWidget {
  const BookPreparation({
    required this.session,
    required this.bookKey,
    super.key,
  });

  final ServerSession session;
  final BookKey bookKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bookPreparationBindingProvider(session, bookKey));
    final controller = preparationControllerProvider(session, bookKey);
    final state = ref.watch(controller);
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(
              l10n.libraryPreparationTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            switch (state) {
              PreparationIdle() ||
              PreparationDetached() => Text(l10n.libraryPreparationHelp),
              PreparationPreparing() => _PreparationProgress(state: state),
              PreparationReady() => Semantics(
                liveRegion: true,
                child: Text(l10n.libraryPreparationReady),
              ),
              PreparationFailed(:final error) => Semantics(
                liveRegion: true,
                child: Text(preparationFailureMessage(context, error.failure)),
              ),
            },
            if (state is PreparationReady)
              Text(l10n.libraryPreparationRefreshHelp),
            switch (state) {
              PreparationPreparing() => OutlinedButton(
                onPressed: () => ref.read(controller.notifier).cancel(),
                child: Text(l10n.commonCancel),
              ),
              PreparationReady() => OutlinedButton(
                onPressed: () =>
                    ref.read(controller.notifier).prepare(refresh: true),
                child: Text(l10n.libraryPreparationRefresh),
              ),
              _ => FilledButton(
                onPressed: () => ref.read(controller.notifier).prepare(),
                child: Text(
                  state is PreparationFailed
                      ? l10n.commonRetry
                      : l10n.libraryPreparationStart,
                ),
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _PreparationProgress extends StatelessWidget {
  const _PreparationProgress({required this.state});
  final PreparationPreparing state;

  @override
  Widget build(BuildContext context) {
    final received = state.receivedBytes;
    final total = state.totalBytes;
    final progress = received != null && total != null && total > 0
        ? (received / total).clamp(0.0, 1.0)
        : null;
    final l10n = context.l10n;
    final label = progress == null
        ? l10n.libraryPreparationWorking
        : l10n.libraryPreparationProgress((progress * 100).floor());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(label),
        LinearProgressIndicator(value: progress, semanticsLabel: label),
        Text(l10n.libraryPreparationCheckingHelp),
      ],
    );
  }
}
