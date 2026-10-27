import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/library/data/models/shelf_ref.dart';
import 'package:shiori/features/library/presentation/library_snapshot_controller.dart';
import 'package:shiori/features/library/presentation/widgets/book_cover.dart';
import 'package:shiori/features/library/presentation/widgets/book_metadata.dart';
import 'package:shiori/features/library/presentation/widgets/library_entry.dart';
import 'package:shiori/features/library/presentation/widgets/library_feedback.dart';
import 'package:shiori/l10n/l10n.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({
    required this.session,
    required this.onChangeServer,
    required this.onFolder,
    required this.onBook,
    this.folderId,
    this.bookId,
    super.key,
  });
  final ServerSession session;
  final int? folderId;
  final int? bookId;
  final VoidCallback onChangeServer;
  final ValueChanged<int> onFolder;
  final ValueChanged<int> onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = librarySnapshotControllerProvider(session);
    final state = ref.watch(provider);
    final index = state.snapshot?.index;
    final folder = index?.folders[folderId];
    final book = index?.books[bookId];
    final entries = folderId == null
        ? index?.shelf ?? const <ShelfRef>[]
        : [
            for (final id in folder?.bookIds ?? <int>[])
              ShelfRef.book(id: id, sortOrder: index!.books[id]!.sortOrder),
          ];
    final l10n = context.l10n;
    Future<void> refresh() => ref.read(provider.notifier).refresh();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          bookId != null
              ? l10n.libraryBookTitle
              : folder?.name ?? l10n.libraryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: state.refreshing ? null : refresh,
            tooltip: l10n.libraryRefresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: onChangeServer,
            tooltip: l10n.serverChangeTitle,
            icon: const Icon(Icons.dns_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.serverCurrent(session.endpoint.normalizedText),
                  ),
                ),
              ),
              if (state.refreshing)
                SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    semanticsLabel: l10n.libraryRefreshing,
                  ),
                ),
              if (state.stale && index != null)
                SliverToBoxAdapter(
                  child: LibraryFeedback(message: l10n.libraryStale),
                ),
              if (state.error case final error?)
                SliverToBoxAdapter(
                  child: LibraryFeedback(
                    message: libraryErrorMessage(context, error),
                    onRetry: refresh,
                  ),
                ),
              if (index == null && state.error == null)
                SliverToBoxAdapter(
                  child: LibraryFeedback(message: l10n.libraryLoading),
                ),
              if (index != null && bookId != null)
                SliverToBoxAdapter(
                  child: book == null
                      ? LibraryFeedback(message: l10n.libraryBookMissing)
                      : BookMetadata(session: session, book: book),
                )
              else if (index != null && folderId != null && folder == null)
                SliverToBoxAdapter(
                  child: LibraryFeedback(message: l10n.libraryFolderMissing),
                )
              else if (index != null && entries.isEmpty)
                SliverToBoxAdapter(
                  child: LibraryFeedback(
                    message: folderId == null
                        ? l10n.libraryEmpty
                        : l10n.libraryFolderEmpty,
                  ),
                )
              else
                SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, position) {
                    final entry = entries[position];
                    if (entry is ShelfFolderRef) {
                      final item = index!.folders[entry.id]!;
                      return LibraryEntry(
                        title: item.name,
                        subtitle: l10n.libraryBookCount(item.bookCount),
                        leading: const SizedBox(
                          width: 48,
                          child: Icon(Icons.folder_outlined),
                        ),
                        onTap: () => onFolder(item.id),
                      );
                    }
                    final item = index!.books[entry.id]!;
                    return LibraryEntry(
                      title: item.title,
                      subtitle: item.author ?? l10n.libraryUnknownAuthor,
                      leading: BookCover(session: session, book: item),
                      onTap: () => onBook(item.id),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
