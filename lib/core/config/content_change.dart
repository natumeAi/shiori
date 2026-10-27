import 'package:shiori/core/config/content_identity.dart';

/// Publication notification only. Saved positions/activity have another owner.
final class ContentChange {
  ContentChange({this.previous, required this.next}) {
    if (previous != null && previous!.bookKey != next.bookKey) {
      throw ArgumentError('Content changes must belong to one book');
    }
  }

  final ContentIdentity? previous;
  final ContentIdentity next;

  @override
  bool operator ==(Object other) =>
      other is ContentChange &&
      previous == other.previous &&
      next == other.next;

  @override
  int get hashCode => Object.hash(previous, next);
}
