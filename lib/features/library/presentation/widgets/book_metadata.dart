import 'package:flutter/material.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/library/data/models/snapshot_book.dart';
import 'package:shiori/features/library/presentation/widgets/book_cover.dart';
import 'package:shiori/features/library/presentation/widgets/book_preparation.dart';
import 'package:shiori/l10n/l10n.dart';

class BookMetadata extends StatelessWidget {
  const BookMetadata({required this.session, required this.book, super.key});
  final ServerSession session;
  final SnapshotBook book;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        Center(
          child: BookCover(session: session, book: book, width: 120),
        ),
        Text(book.title, style: Theme.of(context).textTheme.headlineSmall),
        Text(book.author ?? context.l10n.libraryUnknownAuthor),
        BookPreparation(
          session: session,
          bookKey: BookKey(session.serverKey, book.id),
        ),
      ],
    ),
  );
}
