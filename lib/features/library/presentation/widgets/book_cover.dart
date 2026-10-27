import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/library/data/models/snapshot_book.dart';
import 'package:shiori/features/library/presentation/covers/cover_loader.dart';
import 'package:shiori/features/library/presentation/covers/session_cover_image.dart';
import 'package:shiori/l10n/l10n.dart';

class BookCover extends ConsumerWidget {
  const BookCover({
    required this.session,
    required this.book,
    this.width = 48,
    super.key,
  });
  final ServerSession session;
  final SnapshotBook book;
  final double width;

  /// lan-reader renders every cover as 384 px and 768 px wide WebP thumbnails.
  static const smallThumbnailWidth = 384;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pixelWidth = (width * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Semantics(
      image: true,
      label: context.l10n.libraryCoverLabel(book.title),
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: width * 1.4,
          child: Image(
            key: ValueKey((session, book.id)),
            image: SessionCoverImage(
              ref.watch(coverLoaderProvider(session)),
              (pixelWidth <= smallThumbnailWidth
                      ? book.coverThumbnailUrl
                      : null) ??
                  book.coverThumbnail2xUrl ??
                  book.coverThumbnailUrl ??
                  book.coverUrl,
              maxWidth: pixelWidth,
            ),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const _CoverPlaceholder(),
            frameBuilder: (context, child, frame, synchronous) =>
                frame == null ? const _CoverPlaceholder() : child,
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: Icon(Icons.menu_book_outlined)),
  );
}
