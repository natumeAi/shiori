/// Caller-owned opaque session/content identity, independent of request IDs.
final class PublicationTag {
  const PublicationTag(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is PublicationTag && value == other.value;

  @override
  int get hashCode => value.hashCode;
}
