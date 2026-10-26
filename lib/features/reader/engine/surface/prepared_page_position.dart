import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';

/// Creates a position only from a visible anchor proved by Phase C's engine.
TurnPosition? preparedPagePosition(
  PreparedSection section,
  int pageIndex, {
  required bool atStart,
  required bool atEnd,
  AnchorProofHook? proofHook,
}) {
  final anchor = PageAnchors(
    section,
    proofHook: proofHook,
  ).exportVisible(pageIndex);
  if (anchor == null) return null;
  return TurnPosition(
    cfi: anchor.cfi,
    layoutKey: section.identity.key,
    layoutGeneration: section.identity.generation,
    sectionIndex: section.sectionIndex,
    pageIndex: pageIndex,
    pageCount: section.pageCount,
    pageIdentity: section.pages[pageIndex].map.identity,
    atStart: atStart,
    atEnd: atEnd,
  );
}

bool provePreparedPosition(
  PreparedSection section,
  TurnPosition position, {
  String? anchor,
  AnchorProofHook? proofHook,
}) {
  if (position.sectionIndex != section.sectionIndex ||
      position.layoutKey != section.identity.key ||
      position.layoutGeneration != section.identity.generation ||
      position.pageCount != section.pageCount ||
      position.pageIndex < 0 ||
      position.pageIndex >= section.pageCount ||
      position.pageIdentity != section.pages[position.pageIndex].map.identity) {
    return false;
  }
  final proof = PageAnchors(
    section,
    proofHook: proofHook,
  ).prove(anchor ?? position.cfi, expectedIdentity: section.identity);
  return proof.ok && proof.pageIndex == position.pageIndex;
}
