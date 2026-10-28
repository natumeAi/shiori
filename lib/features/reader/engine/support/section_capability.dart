import 'package:shiori/features/reader/engine/support/unsupported_layout.dart';

enum CapabilityConstructKind {
  fixedMetadata,
  layout,
  dimensions,
  css,
  svg,
  font,
  resource,
  render,
}

final class OffendingConstruct {
  OffendingConstruct({
    required this.kind,
    required this.identifier,
    this.nodeIndex,
  }) {
    if (identifier.trim().isEmpty || (nodeIndex ?? 0) < 0) {
      throw ArgumentError('Invalid offending construct');
    }
  }
  final CapabilityConstructKind kind;

  /// Content-free construct/property identifier, never source prose.
  final String identifier;
  final int? nodeIndex;
  @override
  bool operator ==(Object other) =>
      other is OffendingConstruct &&
      kind == other.kind &&
      identifier == other.identifier &&
      nodeIndex == other.nodeIndex;
  @override
  int get hashCode => Object.hash(kind, identifier, nodeIndex);
}

/// Rich renderer verdict alongside existing SectionLayoutSupport detection.
/// No detection is performed here and fixed metadata alone is not a refusal.
sealed class SectionCapability {
  SectionCapability._(
    this.sectionIndex,
    this.reason,
    List<OffendingConstruct> constructs, {
    this.layoutReason,
    bool complete = false,
  }) : constructs = List.unmodifiable(constructs) {
    if (sectionIndex < 0 ||
        reason.trim().isEmpty ||
        (!complete && constructs.isEmpty) ||
        layoutReason == UnsupportedLayoutReason.fixedLayout) {
      throw ArgumentError('Invalid capability verdict');
    }
  }
  final int sectionIndex;
  final String reason;
  final List<OffendingConstruct> constructs;
  final UnsupportedLayoutReason? layoutReason;
  bool get isComplete => this is CompleteSectionCapability;
  @override
  bool operator ==(Object other) =>
      other is SectionCapability &&
      runtimeType == other.runtimeType &&
      sectionIndex == other.sectionIndex &&
      reason == other.reason &&
      layoutReason == other.layoutReason &&
      constructs.length == other.constructs.length &&
      Iterable<int>.generate(constructs.length)
          .every((i) => constructs[i] == other.constructs[i]);
  @override
  int get hashCode => Object.hash(
    runtimeType,
    sectionIndex,
    reason,
    layoutReason,
    Object.hashAll(constructs),
  );
}

final class CompleteSectionCapability extends SectionCapability {
  CompleteSectionCapability({required int sectionIndex, required String reason})
    : super._(sectionIndex, reason, const [], complete: true);
}

final class MalformedSectionCapability extends SectionCapability {
  MalformedSectionCapability({
    required int sectionIndex,
    required String reason,
    required List<OffendingConstruct> constructs,
  }) : super._(sectionIndex, reason, constructs);
}

final class UnsupportedSectionCapability extends SectionCapability {
  UnsupportedSectionCapability({
    required int sectionIndex,
    required String reason,
    required List<OffendingConstruct> constructs,
    UnsupportedLayoutReason? layoutReason,
  }) : super._(sectionIndex, reason, constructs, layoutReason: layoutReason) {
    if (constructs.every(
      (c) => c.kind == CapabilityConstructKind.fixedMetadata,
    )) {
      throw ArgumentError('Fixed metadata alone is never unsupported');
    }
  }
}

final class ResourceSectionCapability extends SectionCapability {
  ResourceSectionCapability({
    required int sectionIndex,
    required String reason,
    required List<OffendingConstruct> constructs,
  }) : super._(sectionIndex, reason, constructs);
}

final class RenderSectionCapability extends SectionCapability {
  RenderSectionCapability({
    required int sectionIndex,
    required String reason,
    required List<OffendingConstruct> constructs,
  }) : super._(sectionIndex, reason, constructs);
}
