/// UTF-16 position in character data, or child offset in an element.
final class SourcePosition {
  const SourcePosition({required this.nodeIndex, required this.offset});

  final int nodeIndex;
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is SourcePosition &&
      other.nodeIndex == nodeIndex &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(nodeIndex, offset);
}
