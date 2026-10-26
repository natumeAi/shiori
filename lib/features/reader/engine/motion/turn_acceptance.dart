import 'package:shiori/features/reader/engine/motion/turn_session.dart';

/// Structural checks surround the session's existing CFI/visibility proof.
abstract final class TurnAcceptance {
  static String? previewConflict(TurnPosition origin, PreparedTurn preview) {
    if (preview.released || !preview.origin.sameOrigin(origin)) return 'origin';
    if (preview.target.layoutGeneration != origin.layoutGeneration) {
      return 'layout';
    }
    return null;
  }

  static Future<String?> verify(
    TurnSession session,
    TurnPosition origin,
    TurnPosition destination,
    PreparedTurn? preview,
  ) async {
    if (preview != null) {
      final conflict = previewConflict(origin, preview);
      if (conflict != null) return conflict;
      final target = preview.target;
      if (target.layoutKey != destination.layoutKey ||
          target.layoutGeneration != destination.layoutGeneration) {
        return 'layout';
      }
      if (target.sectionIndex != destination.sectionIndex) return 'section';
      if (target.pageIndex != destination.pageIndex ||
          target.pageCount != destination.pageCount ||
          target.pageIdentity != destination.pageIdentity) {
        return 'page';
      }
    }
    return await session.prove(destination, preview: preview) ? null : 'anchor';
  }
}
