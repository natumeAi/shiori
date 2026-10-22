/// An original qualified attribute; namespace identity is not flattened away.
final class SourceAttribute {
  const SourceAttribute({
    required this.qualifiedName,
    required this.localName,
    required this.value,
    this.namespaceUri,
  });

  final String qualifiedName;
  final String localName;
  final String value;
  final String? namespaceUri;
}
